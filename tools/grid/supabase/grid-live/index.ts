// grid-live · Supabase Edge Function behind Grid (https://nicholaskouns-create.github.io/Identity/grid/).
//
// Reads two public sources that browsers cannot read directly, and serves them with CORS:
//   ?src=ercot    ERCOT Real-Time System Conditions: frequency, time error, inertia, demand, wind, solar, DC ties
//   ?src=outages  ODIN (Outage Data Initiative Nationwide, DOE / ORNL): active outages by county, aggregated
//
// The upstream URLs are fixed: no request parameter ever becomes a URL, so this is not an open proxy.
// Each warm instance caches ERCOT for 8 s and ODIN for 60 s, so the publishers see at most one read per
// interval per instance however many people have Grid open. Written as plain JavaScript inside a .ts file
// so the same parsers run under Node for testing (tools/grid/test_grid_live.mjs).

const ERCOT_URL = 'https://www.ercot.com/content/cdr/html/real_time_system_conditions.html';
const ODIN_URL = 'https://odin.ornl.gov/odi';
const ODIN_STATUS_URL = 'https://odin.ornl.gov/odi/status';
const UA = 'Grid/1.0 (+https://nicholaskouns-create.github.io/Identity/grid/)';
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Max-Age': '86400',
};
const cache = new Map();

async function getText(url, ms) {
  const ctl = new AbortController();
  const h = setTimeout(() => ctl.abort(), ms);
  try {
    const r = await fetch(url, { signal: ctl.signal, headers: { 'user-agent': UA, accept: 'text/html,application/json;q=0.9,*/*;q=0.8' } });
    if (!r.ok) throw new Error(`HTTP ${r.status} from ${new URL(url).host}`);
    return await r.text();
  } finally {
    clearTimeout(h);
  }
}

async function cached(key, ttlMs, fn) {
  const hit = cache.get(key), now = Date.now();
  if (hit && now - hit.t < ttlMs) return hit.v;
  try {
    const v = await fn();
    cache.set(key, { t: now, v });
    return v;
  } catch (e) {
    const msg = String((e && e.message) || e);
    if (hit) return { ...hit.v, stale: true, staleReason: msg };
    return { error: msg, fetched: new Date(now).toISOString() };
  }
}

// ------------------------------------------------------------------ ERCOT
// Table cells in document order, tags stripped. Label and value sit in adjacent cells on the ERCOT page.
export function htmlCells(html) {
  return String(html)
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<\/(td|th|div|p|span|h\d)>/gi, '\u0001')
    .replace(/<br\s*\/?>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ').replace(/&amp;/gi, '&').replace(/&#0?39;/g, "'").replace(/&quot;/gi, '"')
    .split('\u0001')
    .map((s) => s.replace(/\s+/g, ' ').trim())
    .filter(Boolean);
}

const num = (s) => {
  const m = String(s).replace(/,/g, '').trim().match(/^[-+]?\d+(\.\d+)?$/);
  return m ? Number(m[0]) : null;
};

const ERCOT_FIELDS = [
  ['frequency', /^current frequency$/i],
  ['timeError', /^instantaneous time error$/i],
  ['baalMinutes', /^consecutive baal/i],
  ['demand', /^actual system demand$/i],
  ['netLoad', /^average net load$/i],
  ['capacity', /^total system capacity/i],
  ['wind', /^total wind output$/i],
  ['solar', /^total pvgr output$/i],
  ['inertia', /^current system inertia$/i],
];
const MON = { Jan: 0, Feb: 1, Mar: 2, Apr: 3, May: 4, Jun: 5, Jul: 6, Aug: 7, Sep: 8, Oct: 9, Nov: 10, Dec: 11 };

function tzOffsetMin(tz, t) {
  const p = Object.fromEntries(new Intl.DateTimeFormat('en-US', { timeZone: tz, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' })
    .formatToParts(new Date(t)).map((x) => [x.type, x.value]));
  return Math.round((Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute, +p.second) - t) / 60000);
}
export function centralToIso(s) {
  const m = String(s).match(/^([A-Za-z]{3})\s+(\d{1,2}),\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?/);
  if (!m || MON[m[1]] === undefined) return null;
  const wall = Date.UTC(+m[3], MON[m[1]], +m[2], +m[4], +m[5], +(m[6] || 0));
  return new Date(wall - tzOffsetMin('America/Chicago', wall) * 60000).toISOString();
}

export function parseErcot(html) {
  const cells = htmlCells(html);
  const out = { source: 'ERCOT Real-Time System Conditions', url: ERCOT_URL };
  const ties = {};
  for (let i = 0; i < cells.length - 1; i++) {
    const label = cells[i], val = num(cells[i + 1]);
    if (val === null) continue;
    for (const [k, re] of ERCOT_FIELDS) if (out[k] === undefined && re.test(label)) out[k] = val;
    const t = label.match(/^DC_([A-Z])\s*\(([^)]+)\)$/i);
    if (t) ties[t[2].trim()] = val;
  }
  if (Object.keys(ties).length) out.dcTies = ties;
  const lu = cells.join(' ').match(/Last\s+Updated:?\s*([A-Za-z]{3}\s+\d{1,2},\s+\d{4}\s+\d{1,2}:\d{2}(?::\d{2})?)/i);
  if (lu) { out.updatedCentral = lu[1]; out.updated = centralToIso(lu[1]); }
  if (typeof out.frequency !== 'number') throw new Error('frequency not found on the ERCOT page');
  if (out.frequency < 55 || out.frequency > 65) throw new Error(`implausible frequency ${out.frequency}`);
  return out;
}

// ------------------------------------------------------------------ ODIN
export function aggregateOdin(j, status) {
  const list = Array.isArray(j) ? j : j && Array.isArray(j.outage) ? j.outage : [];
  const counties = new Map(), utils = new Map();
  let customers = 0, events = 0;
  for (const o of list) {
    const fips = String(o.communityDescriptor ?? '').trim();
    if (!/^\d{4,5}$/.test(fips)) continue;
    const f = fips.padStart(5, '0');
    const m = Math.max(0, Number(o.metersAffected) || 0);
    const names = Array.isArray(o.names) ? o.names : [];
    const util = (names.find((n) => /utilityname/i.test(n.nameType || '')) || {}).name || 'Unknown utility';
    const uid = (names.find((n) => /utilityid/i.test(n.nameType || '')) || {}).name || util;
    const start = o.reportedStartTime || (o.outageArea && o.outageArea.earliestReportedTime) || null;
    const ert = (o.estimatedRestorationTime && o.estimatedRestorationTime.ert) || null;
    const cause = o.cause || (o.incident && o.incident.cause) || null;
    customers += m; events++;
    let c = counties.get(f);
    if (!c) counties.set(f, (c = { m: 0, n: 0, u: new Map(), s: null, e: null, cz: new Map() }));
    c.m += m; c.n++;
    c.u.set(util, (c.u.get(util) || 0) + m);
    if (start && (!c.s || start < c.s)) c.s = start;
    if (ert && (!c.e || ert > c.e)) c.e = ert;
    if (cause) c.cz.set(cause, (c.cz.get(cause) || 0) + 1);
    let u = utils.get(uid);
    if (!u) utils.set(uid, (u = { id: uid, name: util, m: 0, n: 0, c: new Set() }));
    u.m += m; u.n++; u.c.add(f);
  }
  const top = (map) => [...map.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;
  const countyRows = [...counties.entries()].map(([f, c]) => [f, c.m, c.n, top(c.u), c.u.size, c.s, c.e, top(c.cz)]).sort((a, b) => b[1] - a[1] || b[2] - a[2]);
  const utilRows = [...utils.values()].map((u) => [u.id, u.name, u.m, u.n, u.c.size, [...u.c].slice(0, 80).join(',')]).sort((a, b) => b[2] - a[2] || b[3] - a[3]);
  const st = Array.isArray(status) ? status : [];
  const newest = st.reduce((t, s) => (s && s.receivedDate && s.receivedDate > t ? s.receivedDate : t), '');
  return {
    source: 'ODIN · Outage Data Initiative Nationwide (DOE / ORNL)',
    url: ODIN_URL,
    customers, events,
    nCounties: countyRows.length, nUtilities: utilRows.length,
    feeds: st.length || null, feedErrors: st.filter((s) => s && s.hasError).length, newestFeed: newest || null,
    countyFields: ['fips', 'customers', 'events', 'topUtility', 'utilities', 'since', 'restoreBy', 'cause'],
    counties: countyRows.slice(0, 2500),
    utilityFields: ['eiaId', 'name', 'customers', 'events', 'counties', 'fips'],
    utilities: utilRows.slice(0, 500),
  };
}

// ------------------------------------------------------------------ serve
function json(o, status = 200, maxAge = 0) {
  return new Response(JSON.stringify(o), { status, headers: { ...CORS, 'content-type': 'application/json; charset=utf-8', 'cache-control': `public, max-age=${maxAge}` } });
}

async function handle(req) {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'GET') return json({ error: 'GET only' }, 405);
  const src = new URL(req.url).searchParams.get('src') || 'ercot';
  const t0 = Date.now();
  let body;
  if (src === 'ercot') {
    body = await cached('ercot', 8000, async () => ({ ...parseErcot(await getText(ERCOT_URL, 8000)), fetched: new Date().toISOString() }));
  } else if (src === 'outages') {
    body = await cached('outages', 60000, async () => {
      const [raw, status] = await Promise.all([
        getText(ODIN_URL, 20000).then((t) => JSON.parse(t)),
        cached('odin-status', 300000, async () => JSON.parse(await getText(ODIN_STATUS_URL, 15000))),
      ]);
      return { ...aggregateOdin(raw, Array.isArray(status) ? status : null), fetched: new Date().toISOString() };
    });
  } else {
    return json({ error: 'unknown src: use ercot or outages' }, 400);
  }
  console.log(JSON.stringify({ src, ms: Date.now() - t0, ok: !body.error, stale: !!body.stale, err: body.error || body.staleReason || null, hz: body.frequency ?? null, counties: body.nCounties ?? null, customers: body.customers ?? null }));
  return json({ schema: 'KKP-GRID-LIVE-1.0', src, ...body }, body.error ? 502 : 200, src === 'ercot' ? 4 : 30);
}

if (typeof Deno !== 'undefined') Deno.serve(handle);
