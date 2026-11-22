// What grid-alerts decides, with no I/O, so tools/grid/test_grid_alerts.mjs can run it under Node.
// Plain JavaScript inside .ts files, like grid-live.

export const GRID = 'https://nicholaskouns-create.github.io/Identity/grid/';
// CDC: keep a generator outside, at least 20 feet from doors, windows and vents; never in a garage or carport.
export const CO_LINE = 'Generator: outdoors only, 20+ ft from doors, windows and vents. Never in a garage.';
const MAX_PLACES = 5;
const fmt = (n) => Math.round(n).toLocaleString('en-US');

export function fipsOf(x) {
  const s = String(x ?? '').trim();
  if (!/^\d{4,5}$/.test(s)) return null;
  const f = s.padStart(5, '0'), st = +f.slice(0, 2);
  return st >= 1 && st <= 78 ? f : null;
}

// ODIN reports most utility names in capitals ("NEVADA POWER CO"); Grid shows them in title case.
export const utilName = (s) => (/[a-z]/.test(s) ? s : String(s || '').toLowerCase().replace(/\b([a-z])/g, (m) => m.toUpperCase()).replace(/(?!^)\b(Of|And|The|De)\b/g, (m) => m.toLowerCase()).replace(/\bCo\b/g, 'Co.').replace(/\bInc\b/g, 'Inc.').replace(/\bAssn\b/g, 'Assn.').replace(/\bLlc\b/g, 'LLC'));
const plain = (s, n) => String(s ?? '').replace(/<[^>]*>/g, '').replace(/[<>\u0000-\u001f\u007f]/g, '').replace(/\s+/g, ' ').trim().slice(0, n);

// ------------------------------------------------------------------ outages
// ODIN → Map(fips → { customers, events, util, ert })
export function countyTotals(j) {
  const list = Array.isArray(j) ? j : j && Array.isArray(j.outage) ? j.outage : [];
  const m = new Map();
  for (const o of list) {
    const f = fipsOf(o.communityDescriptor);
    const n = Math.max(0, Number(o.metersAffected) || 0);
    if (!f || !n) continue;
    let c = m.get(f);
    if (!c) m.set(f, (c = { customers: 0, events: 0, ert: 0, byUtil: new Map() }));
    c.customers += n; c.events++;
    const names = Array.isArray(o.names) ? o.names : [];
    const u = utilName(plain((names.find((x) => /utilityname/i.test(x.nameType || '')) || {}).name, 60));
    if (u) c.byUtil.set(u, (c.byUtil.get(u) || 0) + n);
    const e = Date.parse((o.estimatedRestorationTime && o.estimatedRestorationTime.ert) || '');
    if (e > c.ert) c.ert = e;
  }
  for (const c of m.values()) {
    c.util = [...c.byUtil.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] || '';
    delete c.byUtil;
  }
  return m;
}

function humanIn(ms) {
  if (!(ms > 0)) return '';
  const min = ms / 60000;
  if (min < 55) return `about ${Math.max(5, Math.round(min / 5) * 5)} min`;
  const h = min / 60;
  return h < 36 ? `about ${Math.round(h)} h` : `about ${Math.round(h / 24)} days`;
}

// One county, one sweep. An alert when the count reaches minOut; then silence while it stays out; a restore
// notice once it has been under half the threshold for two sweeps in a row. totals === null means ODIN
// could not be read: nothing changes, so a feed failure is never mistaken for the power coming back.
export function outageStep(state, place, totals, minOut, restore, now) {
  if (!totals) return { state, notes: [] };
  const f = place.fips, cur = totals.get(f), n = cur ? cur.customers : 0;
  const out = { ...(state.out || {}) }, s = out[f], notes = [];
  const clearBelow = Math.max(1, Math.floor(minOut / 2));
  if (!s) {
    if (n < minOut) return { state, notes };
    const eta = cur.ert ? humanIn(cur.ert - now) : '';
    notes.push({
      kind: 'outage', fips: f, urgency: 'high', tag: `out-${f}`, url: `${GRID}?county=${f}`,
      title: `Power outage · ${place.label}`,
      body: [`${fmt(n)} customer${n === 1 ? '' : 's'} out`, cur.util, eta && `utility estimate: back in ${eta}`].filter(Boolean).join(' · ') + `\n${CO_LINE}`,
    });
    out[f] = { n, at: now, low: 0, util: cur.util || '' };
  } else if (n < clearBelow) {
    const low = (s.low || 0) + 1;
    if (low < 2) out[f] = { ...s, low };
    else {
      delete out[f];
      if (restore) notes.push({
        kind: 'restore', fips: f, urgency: 'normal', tag: `out-${f}`, url: `${GRID}?county=${f}`,
        title: `Power restored · ${place.label}`,
        body: `Reported outages here have cleared. If your power is still out, report it to ${s.util || 'your utility'}.`,
      });
    }
  } else {
    if (!s.low && n <= s.n) return { state, notes };
    out[f] = { ...s, low: 0, n: Math.max(s.n, n) };
  }
  return { state: { ...state, out }, notes };
}

// ------------------------------------------------------------------ weather
// NWS active alerts → Map(fips → [alert]). Real, severe or extreme warnings only; watches, advisories and
// statements stay in the app. SAME codes are 0SSCCC (a leading 1–9 marks part of a county): fips = last five.
export function weatherIndex(j) {
  const m = new Map();
  for (const ft of (j && Array.isArray(j.features) ? j.features : [])) {
    const p = ft.properties || {};
    if (!/^actual$/i.test(p.status || '') || !/^(alert|update)$/i.test(p.messageType || '')) continue;
    if (!/^(extreme|severe)$/i.test(p.severity || '')) continue;
    if (/watch|advisory|statement|outlook|test/i.test(p.event || '')) continue;
    const a = { id: String(ft.id || p.id || ''), event: plain(p.event, 60), headline: plain(p.headline || p.event, 200), expires: Math.max(Date.parse(p.ends || '') || 0, Date.parse(p.expires || '') || 0), severity: p.severity };
    if (!a.id) continue;
    for (const code of ((p.geocode && p.geocode.SAME) || [])) {
      const f = /^\d{6}$/.test(code) ? fipsOf(code.slice(1)) : null;
      if (!f) continue;
      if (!m.has(f)) m.set(f, []);
      if (!m.get(f).some((x) => x.id === a.id)) m.get(f).push(a);
    }
  }
  return m;
}

// Deduped by event and county, not by message id: NWS re-issues a warning under a new id each time it is
// continued or extended, and one "Tornado Warning · your county" is the message that matters. A later
// expiry is carried forward silently; the same event for the same county alerts again only once the
// earlier one has ended.
export function weatherStep(state, place, wx, now) {
  const seen = { ...(state.wx || {}) }, notes = [];
  for (const [k, exp] of Object.entries(seen)) if (!(exp > now - 3600e3)) delete seen[k];
  for (const a of (wx && wx.get(place.fips)) || []) {
    const key = `${a.event}|${place.fips}`, until = a.expires || now + 6 * 3600e3;
    if (seen[key] > now) { seen[key] = Math.max(seen[key], until); continue; }
    seen[key] = until;
    notes.push({ kind: 'weather', fips: place.fips, urgency: 'high', ttl: Math.max(600, Math.min(86400, Math.round((until - now) / 1000))), tag: `wx-${a.event.replace(/\W+/g, '-').toLowerCase()}-${place.fips}`, url: `${GRID}?county=${place.fips}`, title: `${a.event} · ${place.label}`, body: a.headline });
  }
  return { state: { ...state, wx: seen }, notes };
}

// One subscriber, one sweep: every place, every notice due, state only rewritten when it changed.
export function planSub(sub, totals, wx, now) {
  let state = sub.state || {}, notes = [];
  for (const place of (sub.places || []).slice(0, MAX_PLACES)) {
    const o = outageStep(state, place, totals, sub.min_out || 10, sub.restore !== false, now);
    state = o.state; notes.push(...o.notes);
    if (sub.weather !== false && wx) { const w = weatherStep(state, place, wx, now); state = w.state; notes.push(...w.notes); }
  }
  return { state, notes, changed: JSON.stringify(state) !== JSON.stringify(sub.state || {}) };
}

// ------------------------------------------------------------------ subscriptions
// The only places a push is ever sent: the browsers' own push services. Anything else (another host, a port,
// userinfo, plain http) is refused, so a stored "subscription" can never point the sweep at an arbitrary URL.
const PUSH_HOSTS = new Set(['fcm.googleapis.com', 'android.googleapis.com', 'updates.push.services.mozilla.com', 'web.push.apple.com']);
const PUSH_SUFFIXES = ['.push.services.mozilla.com', '.push.apple.com', '.notify.windows.com'];
export function allowedEndpoint(u) {
  let x;
  try { x = new URL(u); } catch { return false; }
  if (x.protocol !== 'https:' || x.username || x.password || x.port || String(u).length > 2048) return false;
  const h = x.hostname.toLowerCase();
  return PUSH_HOSTS.has(h) || PUSH_SUFFIXES.some((s) => h.endsWith(s) && h.length > s.length);
}

const b64uLen = (s) => {
  if (typeof s !== 'string' || !/^[A-Za-z0-9_-]+={0,2}$/.test(s)) return -1;
  const t = s.replace(/=+$/, '');
  return Math.floor((t.length * 3) / 4);
};

export function cleanSubscribe(body) {
  const sub = body && body.subscription, keys = (sub && sub.keys) || {};
  if (!sub || !allowedEndpoint(sub.endpoint)) return { ok: false, error: 'subscription endpoint is not a known push service' };
  if (b64uLen(keys.p256dh) !== 65 || b64uLen(keys.auth) < 16) return { ok: false, error: 'subscription keys are malformed' };
  const places = [], seen = new Set();
  for (const p of (Array.isArray(body.places) ? body.places : [])) {
    const f = fipsOf(p && p.fips);
    if (!f || seen.has(f)) continue;
    seen.add(f);
    places.push({ fips: f, label: plain(p.label, 60) || `County ${f}` });
    if (places.length === MAX_PLACES) break;
  }
  if (!places.length) return { ok: false, error: 'choose at least one county' };
  const m = Number(body.minOut);
  return {
    ok: true,
    row: {
      endpoint: sub.endpoint, p256dh: keys.p256dh, auth: keys.auth, places,
      min_out: Number.isFinite(m) ? Math.min(1e6, Math.max(1, Math.round(m))) : 10,
      weather: body.weather !== false, restore: body.restore !== false,
    },
  };
}
