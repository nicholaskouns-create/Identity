// What grid-alerts decides, with no I/O, so tools/grid/test_grid_alerts.mjs can run it under Node.
// Plain JavaScript inside .ts files, like grid-live.
//
// Each step returns { state, notes }. `state` holds only the changes that need no delivery (counters, carried
// expiries). Each note carries the one change its delivery makes (`set`), applied by the sweep only once the
// push service has accepted that note, so a notice that fails to send is planned again on the next sweep.

export const GRID = 'https://nicholaskouns-create.github.io/Identity/grid/';
// CDC: keep a generator outside, at least 20 feet from doors, windows and vents; never in a garage or carport.
export const CO_LINE = 'Generator: outdoors only, 20+ ft from doors, windows and vents. Never in a garage.';
const MAX_PLACES = 5;
const MISS_SWEEPS = 3; // sweeps (5 min apart) without trustworthy data before an alerted county gets "unavailable"
const fmt = (n) => Math.round(n).toLocaleString('en-US');
const people = (n) => `${fmt(n)} customer${n === 1 ? '' : 's'}`;

export function fipsOf(x) {
  const s = String(x ?? '').trim();
  if (!/^\d{4,5}$/.test(s)) return null;
  const f = s.padStart(5, '0'), st = +f.slice(0, 2);
  return st >= 1 && st <= 78 ? f : null;
}

// ODIN reports most utility names in capitals ("NEVADA POWER CO"); Grid shows them in title case.
export const utilName = (s) => (/[a-z]/.test(s) ? s : String(s || '').toLowerCase().replace(/\b([a-z])/g, (m) => m.toUpperCase()).replace(/(?!^)\b(Of|And|The|De)\b/g, (m) => m.toLowerCase()).replace(/\bCo\b/g, 'Co.').replace(/\bInc\b/g, 'Inc.').replace(/\bAssn\b/g, 'Assn.').replace(/\bLlc\b/g, 'LLC'));
const plain = (s, n) => String(s ?? '').replace(/<[^>]*>/g, '').replace(/[<>\u0000-\u001f\u007f]/g, '').replace(/\s+/g, ' ').trim().slice(0, n);

const setIn = (state, sec, key, val) => {
  const m = { ...(state[sec] || {}) };
  if (val === undefined) delete m[key]; else m[key] = val;
  return { ...state, [sec]: m };
};
// The change a delivered note makes.
export const applyNote = (state, n) => (n && n.set ? setIn(state, n.set[0], n.set[1], n.set[2]) : state);
export const commit = (state, notes) => notes.reduce(applyNote, state);

// ------------------------------------------------------------------ outages
// ODIN's outage feed → Map(fips → { customers, events, util, utils: Set(EIA id), ert }), or null when the response
// is not ODIN's documented shape ({ outage: [...] }), is empty nationwide, or is mostly unreadable. Null means
// "cannot be trusted", never "no outages".
export function countyTotals(j) {
  if (!j || typeof j !== 'object' || Array.isArray(j) || !Array.isArray(j.outage) || !j.outage.length) return null;
  const m = new Map();
  let readable = 0;
  for (const o of j.outage) {
    const f = fipsOf(o && o.communityDescriptor);
    const n = Number(o && o.metersAffected);
    if (!f || !Number.isFinite(n) || n < 0) continue;
    readable++;
    if (!n) continue;
    let c = m.get(f);
    if (!c) m.set(f, (c = { customers: 0, events: 0, ert: 0, utils: new Set(), byUtil: new Map() }));
    c.customers += n; c.events++;
    const names = Array.isArray(o.names) ? o.names : [];
    const u = utilName(plain((names.find((x) => /utilityname/i.test(x.nameType || '')) || {}).name, 60));
    if (u) c.byUtil.set(u, (c.byUtil.get(u) || 0) + n);
    const id = plain((names.find((x) => /utilityid/i.test(x.nameType || '')) || {}).name, 20);
    if (id) c.utils.add(id);
    const e = Date.parse((o.estimatedRestorationTime && o.estimatedRestorationTime.ert) || '');
    if (e > c.ert) c.ert = e;
  }
  if (readable < j.outage.length / 2) return null;
  for (const c of m.values()) {
    c.util = [...c.byUtil.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] || '';
    delete c.byUtil;
  }
  return m;
}

// ODIN's feed status (/odi/status) → Map(EIA id → { err, at }) with .newest (latest receivedDate), or null
// when unreadable. It vouches for a utility's report only while it is itself current: liveStatus() drops it
// when no feed has been received for two hours.
export function feedStatus(s) {
  if (!Array.isArray(s) || !s.length) return null;
  const m = new Map();
  let newest = 0;
  for (const x of s) {
    const id = plain(x && x.eiaId, 20);
    if (!id) continue;
    const at = Date.parse(x.receivedDate || '') || 0;
    m.set(id, { err: !!x.hasError, at });
    if (at > newest) newest = at;
  }
  if (!m.size) return null;
  m.newest = newest;
  return m;
}
export const liveStatus = (st, now) => (st && st.newest > now - 2 * 3600e3 ? st : null);

// A national feed that lost more than half its counties since the last sweep is more likely broken than
// restored; it is not trusted for this sweep.
export const feedCollapsed = (totals, previousCounties) => !!totals && previousCounties >= 20 && totals.size < previousCounties / 2;

function humanIn(ms) {
  if (!(ms > 0)) return '';
  const min = ms / 60000;
  if (min < 55) return `about ${Math.max(5, Math.round(min / 5) * 5)} min`;
  const h = min / 60;
  return h < 36 ? `about ${Math.round(h)} h` : `about ${Math.round(h / 24)} days`;
}

// When each utility now reporting outages in the county last reported to ODIN.
const feedsOf = (cur, status) => Object.fromEntries([...((cur && cur.utils) || [])].map((u) => [u, (status && status.get(u) && status.get(u).at) || 0]));

// With current feed status, a smaller count is believed only when every utility that was reporting outages
// here, and no longer does, has sent ODIN a newer report without an error. Otherwise the count may have shrunk
// because a feed stopped.
function fallVerified(s, cur, status) {
  if (!status) return false;
  for (const [u, at] of Object.entries(s.feeds || {})) {
    if (cur && cur.utils.has(u)) continue;
    const st = status.get(u);
    if (!st || st.err || !(st.at > at)) return false;
  }
  return true;
}

const tagOut = (f) => `out-${f}`, urlOut = (f) => `${GRID}?county=${f}`;
function outageNote(place, cur, n, now, rec) {
  const eta = cur.ert ? humanIn(cur.ert - now) : '';
  return {
    kind: 'outage', fips: place.fips, urgency: 'high', ttl: 10800, tag: tagOut(place.fips), url: urlOut(place.fips),
    title: `Power outage · ${place.label}`,
    body: [`${people(n)} out`, cur.util, eta && `utility estimate: back in ${eta}`].filter(Boolean).join(' · ') + `\n${CO_LINE}`,
    set: ['out', place.fips, rec],
  };
}

// One county, one sweep, given odin = { totals, status } (either may be null).
//   idle      → an outage at or above the threshold: "Power outage"
//   alerted   → verified fall below half the threshold: "Reported outages down to N" (once)
//             → verified zero on two sweeps in a row: "No outages reported"; back to idle
//             → no trustworthy reading for three sweeps: "Outage data unavailable" (once, until data returns)
//             → back at or above the threshold after a fall: "Power outage" again
// Nothing is ever announced as restored: utilities' reports can lag, so every follow-up points to the utility.
export function outageStep(state, place, odin, minOut, restore, now) {
  const f = place.fips, s = (state.out || {})[f];
  const totals = odin && odin.totals, status = odin && odin.status;
  if (!s) {
    if (!totals) return { state, notes: [] };
    const cur = totals.get(f), n = cur ? cur.customers : 0;
    if (n < minOut) return { state, notes: [] };
    return { state, notes: [outageNote(place, cur, n, now, { n, at: now, ph: 'out', low: 0, miss: 0, util: cur.util || '', feeds: feedsOf(cur, status) })] };
  }
  const cur = totals ? totals.get(f) : null, n = cur ? cur.customers : 0;
  const util = (cur && cur.util) || s.util || '';
  // Without current feed status, a fall is believed once two valid readings in a row show it.
  if (totals && !status && n < (s.n || 0) && !(s.pend !== undefined && n <= s.pend)) {
    return { state: setIn(state, 'out', f, { ...s, pend: n, miss: 0 }), notes: [] };
  }
  if (!totals || !(n >= (s.n || 0) || !status || fallVerified(s, cur, status))) {
    const next = { ...s, miss: (s.miss || 0) + 1, low: 0 };
    if (next.miss >= MISS_SWEEPS && !s.missNoted) {
      return { state, notes: [{
        kind: 'unavailable', fips: f, urgency: 'normal', ttl: 21600, tag: tagOut(f), url: urlOut(f),
        title: `Outage data unavailable · ${place.label}`,
        body: `Grid can't confirm outages here right now: ${util ? `${util}'s` : "the utility's"} outage feed isn't reporting. Check with ${util || 'your utility'} for service at your address.`,
        set: ['out', f, { ...next, missNoted: true }],
      }] };
    }
    return { state: setIn(state, 'out', f, next), notes: [] };
  }
  const base = { ...s, n, miss: 0, missNoted: false, util, feeds: n > 0 ? feedsOf(cur, status) : (s.feeds || {}) };
  delete base.pend;
  if (n >= minOut) {
    if (s.ph === 'down') return { state, notes: [outageNote(place, cur, n, now, { ...base, ph: 'out', low: 0, at: now })] };
    return { state: setIn(state, 'out', f, { ...base, low: 0 }), notes: [] };
  }
  if (n === 0) {
    const low = (s.low || 0) + 1;
    if (low < 2) return { state: setIn(state, 'out', f, { ...base, low }), notes: [] };
    if (!restore) return { state: setIn(state, 'out', f, undefined), notes: [] };
    return { state, notes: [{
      kind: 'clear', fips: f, urgency: 'normal', ttl: 21600, tag: tagOut(f), url: urlOut(f),
      title: `No outages reported · ${place.label}`,
      body: `${util || 'Utilities here'} ${util ? 'reports' : 'report'} no outages in ${place.label} now. If your power is still out, report it to ${util || 'your utility'}: it may not know about your address.`,
      set: ['out', f, undefined],
    }] };
  }
  if (n < Math.max(1, Math.floor(minOut / 2)) && s.ph !== 'down') {
    const rec = { ...base, ph: 'down', low: 0 };
    if (!restore) return { state: setIn(state, 'out', f, rec), notes: [] };
    return { state, notes: [{
      kind: 'down', fips: f, urgency: 'normal', ttl: 21600, tag: tagOut(f), url: urlOut(f),
      title: `Reported outages down to ${fmt(n)} · ${place.label}`,
      body: `${util || 'Utilities here'} still ${util ? 'reports' : 'report'} ${people(n)} out. Confirm service at your address with ${util || 'your utility'}.`,
      set: ['out', f, rec],
    }] };
  }
  return { state: setIn(state, 'out', f, { ...base, low: 0 }), notes: [] };
}

// ------------------------------------------------------------------ weather
// NWS VTEC: /k.aaa.cccc.pp.s.####.yymmddThhnnZ-yymmddThhnnZ/ — office, phenomenon, significance and event number
// name one warning through all its updates. Ended or upgraded events (CAN, EXP, UPG) are skipped.
export function vtecOf(p) {
  for (const v of (p && p.parameters && p.parameters.VTEC) || []) {
    const m = /^\/[OTEX]\.([A-Z]{3})\.([A-Z]{4})\.([A-Z]{2})\.([A-Z])\.(\d{4})\./.exec(String(v));
    if (m && !/^(CAN|EXP|UPG)$/.test(m[1])) return { action: m[1], key: `${m[2]}.${m[3]}.${m[4]}.${m[5]}` };
  }
  return null;
}

// NWS active alerts → Map(fips → [alert]), or null when the response is not GeoJSON with features. Real,
// severe or extreme warnings only; watches, advisories and statements stay in the app. SAME codes are 0SSCCC
// (a leading 1–9 marks part of a county): fips = last five.
export function weatherIndex(j) {
  if (!j || typeof j !== 'object' || !Array.isArray(j.features)) return null;
  const m = new Map();
  for (const ft of j.features) {
    const p = (ft && ft.properties) || {};
    if (!/^actual$/i.test(p.status || '') || !/^(alert|update)$/i.test(p.messageType || '')) continue;
    if (!/^(extreme|severe)$/i.test(p.severity || '')) continue;
    if (/watch|advisory|statement|outlook|test/i.test(p.event || '')) continue;
    const vtec = vtecOf(p);
    if (((p.parameters && p.parameters.VTEC) || []).length && !vtec) continue; // only cancellations, expirations, upgrades
    const id = plain(p.id || String(ft.id || '').split('/').pop(), 120);
    if (!id) continue;
    const a = {
      id, vtec, refs: (Array.isArray(p.references) ? p.references : []).map((r) => plain(r && r.identifier, 120)).filter(Boolean),
      event: plain(p.event, 60), headline: plain(p.headline || p.event, 200),
      expires: Math.max(Date.parse(p.ends || '') || 0, Date.parse(p.expires || '') || 0),
    };
    for (const code of ((p.geocode && p.geocode.SAME) || [])) {
      const f = /^\d{6}$/.test(code) ? fipsOf(code.slice(1)) : null;
      if (!f) continue;
      if (!m.has(f)) m.set(f, []);
      if (!m.get(f).some((x) => x.id === a.id)) m.get(f).push(a);
    }
  }
  return m;
}

// One notice per warning per county. A warning is known by its VTEC event (office, phenomenon, event number);
// without VTEC, by the earlier messages it references. Continuations and extensions of a known warning only
// carry its expiry forward. A separate warning of the same kind in the same county is a new notice.
export function weatherStep(state, place, wx, now) {
  const kept = {};
  for (const [k, v] of Object.entries(state.wx || {})) {
    const e = typeof v === 'number' ? { until: v, ids: [] } : v; // entries written before VTEC keys were numbers
    if (e && e.until > now - 3600e3) kept[k] = e;
  }
  let next = { ...state, wx: kept };
  const notes = [];
  if (!wx) return { state: next, notes };
  for (const a of wx.get(place.fips) || []) {
    const until = a.expires || now + 6 * 3600e3;
    // The same message again, or an update that references one already seen for this county.
    const byRef = Object.keys(kept).find((k) => k.endsWith(`|${place.fips}`) && (kept[k].ids || []).some((i) => i === a.id || a.refs.includes(i)));
    const key = a.vtec ? `${a.vtec.key}|${place.fips}` : byRef || `${a.id}|${place.fips}`;
    const known = kept[key] || (byRef ? kept[byRef] : null);
    if (known) {
      if (byRef && byRef !== key) next = setIn(next, 'wx', byRef, undefined);
      next = setIn(next, 'wx', key, { until: Math.max(known.until, until), ids: [...new Set([...(known.ids || []), a.id])].slice(-8) });
      continue;
    }
    notes.push({
      kind: 'weather', fips: place.fips, urgency: 'high', ttl: Math.max(600, Math.min(86400, Math.round((until - now) / 1000))),
      tag: `wx-${(a.vtec ? a.vtec.key : a.id).replace(/\W+/g, '-').toLowerCase().slice(-40)}-${place.fips}`, url: urlOut(place.fips),
      title: `${a.event} · ${place.label}`, body: a.headline,
      set: ['wx', key, { until, ids: [a.id] }],
    });
  }
  return { state: next, notes };
}

// One subscriber, one sweep: every place, every notice due. odin = { totals, status } or null.
export function planSub(sub, odin, wx, now) {
  let state = sub.state || {};
  const notes = [];
  for (const place of (sub.places || []).slice(0, MAX_PLACES)) {
    const o = outageStep(state, place, odin, sub.min_out || 10, sub.restore !== false, now);
    state = o.state; notes.push(...o.notes);
    if (sub.weather !== false) { const w = weatherStep(state, place, wx, now); state = w.state; notes.push(...w.notes); }
  }
  return { state, notes };
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
