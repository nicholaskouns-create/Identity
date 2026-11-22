// grid-alerts · Supabase Edge Function: Grid's background alerts.
//
// A phone or browser subscribes with standard Web Push and names up to five counties. Every five minutes
// pg_cron calls ?op=sweep; the sweep reads ODIN (outages by county) and the National Weather Service
// (active severe and extreme warnings), and sends a notification when the power goes out in one of those
// counties, when it comes back, or when a warning is issued there. It works with Grid closed.
//
//   GET  ?op=key           application server public key and the last sweep's summary
//   POST ?op=subscribe     { subscription, places:[{fips,label}], minOut, weather, restore }
//   POST ?op=test          { endpoint }   sends one test notification (once a minute at most)
//   POST ?op=unsubscribe   { endpoint }   deletes the subscription
//   POST ?op=sweep         header x-grid-sweep: the token pg_cron reads from Vault
//
// What is stored per subscription: the push endpoint and its two public keys, the counties, the alert
// threshold, two on/off choices, and what has already been sent. No name, no email, no IP address, no
// precise location, and nothing about health. A subscription the push service reports gone is deleted.
// The VAPID key pair is generated here on first use and kept in a table only the service role can read.

import { send, b64u } from './webpush.ts';
import { GRID, countyTotals, weatherIndex, planSub, cleanSubscribe } from './logic.ts';

const SB = Deno.env.get('SUPABASE_URL');
const SRK = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const ODIN_URL = 'https://odin.ornl.gov/odi';
const NWS_URL = 'https://api.weather.gov/alerts/active?status=actual&message_type=alert,update&severity=Extreme,Severe';
const UA = 'Grid/1.0 (+https://nicholaskouns-create.github.io/Identity/grid/)';
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Max-Age': '86400',
};
const te = new TextEncoder();
const json = (o, status = 200) => new Response(JSON.stringify(o), { status, headers: { ...CORS, 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' } });

async function db(method, path, body, prefer) {
  const r = await fetch(`${SB}/rest/v1/${path}`, {
    method,
    headers: { apikey: SRK, authorization: `Bearer ${SRK}`, 'content-type': 'application/json', ...(prefer ? { prefer } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const t = await r.text();
  if (!r.ok) throw new Error(`db ${method} ${path.split('?')[0]}: HTTP ${r.status} ${t.slice(0, 160)}`);
  return t ? JSON.parse(t) : null;
}

let cfgCache = null;
async function config() {
  if (cfgCache && Date.now() - cfgCache.t < 300e3) return cfgCache.v;
  let [c] = await db('GET', 'grid_alert_config?id=eq.1&select=*');
  if (!c) throw new Error('grid_alert_config row missing');
  if (!c.vapid_public || !c.vapid_private_jwk) {
    const k = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
    const j = await crypto.subtle.exportKey('jwk', k.privateKey);
    const pub = b64u.enc(await crypto.subtle.exportKey('raw', k.publicKey));
    const won = await db('PATCH', 'grid_alert_config?id=eq.1&vapid_public=is.null', { vapid_public: pub, vapid_private_jwk: { kty: j.kty, crv: j.crv, x: j.x, y: j.y, d: j.d } }, 'return=representation');
    c = won && won.length ? won[0] : (await db('GET', 'grid_alert_config?id=eq.1&select=*'))[0];
  }
  cfgCache = { t: Date.now(), v: c };
  return c;
}
const vapidOf = (c) => ({ privateJwk: c.vapid_private_jwk, publicKey: c.vapid_public, subject: GRID });

async function idOf(endpoint) {
  return [...new Uint8Array(await crypto.subtle.digest('SHA-256', te.encode(endpoint)))].map((b) => b.toString(16).padStart(2, '0')).join('');
}
function sameToken(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length || !a) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}
async function getJson(url, ms, accept = 'application/json') {
  const ctl = new AbortController(), h = setTimeout(() => ctl.abort(), ms);
  try {
    const r = await fetch(url, { signal: ctl.signal, headers: { 'user-agent': UA, accept } });
    if (!r.ok) throw new Error(`HTTP ${r.status} from ${new URL(url).host}`);
    return await r.json();
  } finally { clearTimeout(h); }
}
async function readBody(req) {
  const t = await req.text();
  if (t.length > 8192) throw Object.assign(new Error('request too large'), { status: 413 });
  try { return JSON.parse(t || '{}'); } catch { throw Object.assign(new Error('body is not JSON'), { status: 400 }); }
}
const payload = (n) => ({ title: n.title, body: n.body, tag: n.tag, url: n.url || GRID, kind: n.kind, ts: Date.now() });

// ------------------------------------------------------------------ ops
async function opKey() {
  const c = await config();
  return json({ publicKey: c.vapid_public, lastSweep: c.last_sweep || null });
}

async function opSubscribe(req) {
  const v = cleanSubscribe(await readBody(req));
  if (!v.ok) return json({ error: v.error }, 400);
  const id = await idOf(v.row.endpoint);
  const known = await db('GET', `grid_push_subs?id=eq.${id}&select=id`);
  if (!known.length) {
    // A new subscription has to prove itself: one confirmation through its push service, or it isn't stored.
    const where = v.row.places.map((p) => p.label).join(', ');
    const r = await send(v.row, payload({ kind: 'welcome', tag: 'grid-welcome', title: 'Grid alerts are on', body: `Watching ${where}. You'll hear from Grid when the power goes out there${v.row.weather ? ' or a severe weather warning is issued' : ''}, even with Grid closed.` }), vapidOf(await config()), { ttl: 3600, urgency: 'normal' });
    if (!r.ok) return json({ error: `the push service refused the subscription (HTTP ${r.status})` }, 400);
  }
  await db('POST', 'grid_push_subs?on_conflict=id', { id, ...v.row, fails: 0, updated_at: new Date().toISOString() }, 'resolution=merge-duplicates,return=minimal');
  return json({ ok: true, places: v.row.places, minOut: v.row.min_out, weather: v.row.weather, restore: v.row.restore, confirmed: !known.length });
}

async function opTest(req) {
  const b = await readBody(req);
  if (typeof b.endpoint !== 'string') return json({ error: 'endpoint required' }, 400);
  const id = await idOf(b.endpoint);
  const [s] = await db('GET', `grid_push_subs?id=eq.${id}&select=id,endpoint,p256dh,auth,places,last_test_at`);
  if (!s) return json({ error: 'not subscribed' }, 404);
  if (s.last_test_at && Date.now() - Date.parse(s.last_test_at) < 60e3) return json({ error: 'one test a minute' }, 429);
  await db('PATCH', `grid_push_subs?id=eq.${id}`, { last_test_at: new Date().toISOString() }, 'return=minimal');
  const r = await send(s, payload({ kind: 'test', tag: 'grid-test', title: 'Grid test alert', body: `Alerts reach this device. Watching ${(s.places || []).map((p) => p.label).join(', ')}.` }), vapidOf(await config()), { ttl: 600, urgency: 'normal' });
  if (r.gone) await db('DELETE', `grid_push_subs?id=eq.${id}`, undefined, 'return=minimal');
  return json({ ok: r.ok, status: r.status, gone: r.gone }, r.ok ? 200 : 502);
}

async function opUnsubscribe(req) {
  const b = await readBody(req);
  if (typeof b.endpoint !== 'string') return json({ error: 'endpoint required' }, 400);
  await db('DELETE', `grid_push_subs?id=eq.${await idOf(b.endpoint)}`, undefined, 'return=minimal');
  return json({ ok: true });
}

async function opSweep(req) {
  const c = await config();
  if (!sameToken(req.headers.get('x-grid-sweep') || '', c.sweep_token)) return json({ error: 'forbidden' }, 403);
  const t0 = Date.now(), now = Date.now();
  const [odin, nws] = await Promise.allSettled([getJson(ODIN_URL, 25000), getJson(NWS_URL, 25000, 'application/geo+json')]);
  const totals = odin.status === 'fulfilled' ? countyTotals(odin.value) : null;
  const wx = nws.status === 'fulfilled' ? weatherIndex(nws.value) : null;
  const vapid = vapidOf(c);
  const tally = { subs: 0, sent: 0, failed: 0, removed: 0, written: 0 };
  const cols = 'id,endpoint,p256dh,auth,places,min_out,weather,restore,state,fails';
  for (let last = '', guard = 0; guard < 200; guard++) {
    // Keyset pages (id > last), so rows deleted along the way never shift the next page.
    const page = await db('GET', `grid_push_subs?select=${cols}&order=id&limit=500${last ? `&id=gt.${last}` : ''}`);
    if (page.length) last = page[page.length - 1].id;
    tally.subs += page.length;
    let i = 0;
    const worker = async () => {
      while (i < page.length) {
        const s = page[i++];
        const plan = planSub(s, totals, wx, now);
        let gone = false, retry = false, okAny = false, hardFail = false;
        for (const n of plan.notes) {
          const r = await send(s, payload(n), vapid, { ttl: n.ttl || (n.kind === 'restore' ? 21600 : 10800), urgency: n.urgency || 'normal' }).catch((e) => ({ ok: false, status: 0, text: String(e) }));
          if (r.ok) { okAny = true; tally.sent++; continue; }
          tally.failed++;
          if (r.gone) { gone = true; break; }
          if (r.status === 0 || r.status === 429 || r.status >= 500) retry = true; else hardFail = true;
        }
        if (gone || (hardFail && (s.fails || 0) >= 4)) { await db('DELETE', `grid_push_subs?id=eq.${s.id}`, undefined, 'return=minimal'); tally.removed++; continue; }
        if (retry && !okAny) continue; // keep the old state: the same notices go out on the next sweep
        const patch = {};
        if (plan.changed) patch.state = plan.state;
        if (okAny) { patch.last_push_at = new Date().toISOString(); if (s.fails) patch.fails = 0; }
        else if (hardFail) patch.fails = (s.fails || 0) + 1;
        if (Object.keys(patch).length) { await db('PATCH', `grid_push_subs?id=eq.${s.id}`, patch, 'return=minimal'); tally.written++; }
      }
    };
    await Promise.all(Array.from({ length: Math.min(8, page.length) }, worker));
    if (page.length < 500) break;
  }
  const summary = { at: new Date().toISOString(), ...tally, odinCounties: totals ? totals.size : null, nwsCounties: wx ? wx.size : null, odinError: odin.status === 'rejected' ? String(odin.reason).slice(0, 120) : null, nwsError: nws.status === 'rejected' ? String(nws.reason).slice(0, 120) : null, ms: Date.now() - t0 };
  await db('PATCH', 'grid_alert_config?id=eq.1', { last_sweep: summary }, 'return=minimal').catch(() => {});
  cfgCache = null;
  console.log(JSON.stringify({ op: 'sweep', ...summary }));
  return json(summary);
}

async function handle(req) {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  const op = new URL(req.url).searchParams.get('op') || 'key';
  try {
    if (op === 'key' && req.method === 'GET') return await opKey();
    if (req.method !== 'POST') return json({ error: 'use POST' }, 405);
    if (op === 'subscribe') return await opSubscribe(req);
    if (op === 'test') return await opTest(req);
    if (op === 'unsubscribe') return await opUnsubscribe(req);
    if (op === 'sweep') return await opSweep(req);
    return json({ error: 'unknown op' }, 400);
  } catch (e) {
    console.log(JSON.stringify({ op, error: String((e && e.message) || e).slice(0, 300) }));
    return json({ error: (e && e.status) ? e.message : 'server error' }, (e && e.status) || 500);
  }
}

Deno.serve(handle);
