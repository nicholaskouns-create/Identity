// grid-live · Supabase Edge Function behind Grid (https://nicholaskouns-create.github.io/Identity/grid/).
//
// Reads public sources that browsers cannot read directly (or not compactly), and serves them with CORS:
//   ?src=ercot    ERCOT Real-Time System Conditions: frequency, time error, inertia, demand, wind, solar, DC ties
//   ?src=outages  ODIN (Outage Data Initiative Nationwide, DOE / ORNL): active outages by county, aggregated
//   ?src=empower  HHS emPOWER (CMS, HHS): Medicare beneficiaries who rely on electricity-dependent medical
//                 equipment, by county, from the public REST service, refreshed monthly by HHS
//   ?src=rivers   NOAA National Water Prediction Service: river gauges observed at action stage or above
//   ?src=water&fips=NNNNN   EPA ECHO (SDWIS/Fed): the active community water systems serving one county,
//                 with population served, source water and compliance status
//   ?src=drought&fips=NNNNN U.S. Drought Monitor: share of one county in each drought category, latest week
//
// The upstream hosts and paths are fixed. The only request value that reaches an upstream URL is a county
// FIPS code, checked to be exactly five digits, so this is not an open proxy. Each warm instance caches
// ERCOT for 8 s, ODIN for 60 s, rivers for 10 min, a county's water systems for 24 h and its drought for
// 6 h, so the publishers see at most one read per interval per instance however many people have Grid
// open; county lookups that miss the cache are also capped per minute. Written as plain JavaScript inside
// a .ts file so the same parsers run under Node for testing (tools/grid/test_grid_live.mjs).

const ERCOT_URL = 'https://www.ercot.com/content/cdr/html/real_time_system_conditions.html';
const ODIN_URL = 'https://odin.ornl.gov/odi';
const ODIN_STATUS_URL = 'https://odin.ornl.gov/odi/status';
const EMPOWER_LAYER = 'https://services2.arcgis.com/ZQ4jTQn6k7VPXEwO/arcgis/rest/services/HHS_emPOWER_REST_Service_Public/FeatureServer/2';
const EMPOWER_FIELDS = ['FIPS_Code', 'FIPS_Code_recode', 'Medicare_Benes', 'Power_Dependent_Devices_DME', 'Facility_ESRD_Dialysis_Any_DME', 'O2_Services_Any_DME', 'Home_Health_Services_Any_DME', 'AtHome_Hospice_Any_DME'];
const UA = 'Grid/1.0 (+https://nicholaskouns-create.github.io/Identity/grid/)';
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Max-Age': '86400',
};
const cache = new Map();

async function getText(url, ms, accept = 'text/html,application/json;q=0.9,*/*;q=0.8') {
  const ctl = new AbortController();
  const h = setTimeout(() => ctl.abort(), ms);
  try {
    const r = await fetch(url, { signal: ctl.signal, headers: { 'user-agent': UA, accept } });
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
    cache.delete(key); cache.set(key, { t: now, v });
    if (cache.size > 800) for (const k of [...cache.keys()].slice(0, 200)) cache.delete(k); // oldest first
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

// ------------------------------------------------------------------ HHS emPOWER
// Layer 2, "Electricity Dependent DME – ALL – CountyLevel": one row per county (states, DC, territories).
// Counts are Medicare beneficiaries (Fee-for-Service and Medicare Advantage) with claims for
// electricity-dependent equipment; the four service columns count those who also rely on dialysis at a
// facility, oxygen services, home health or at-home hospice. HHS shows ZIP Codes with 1 to 10 people as 11
// and sums ZIP Codes into counties, so small county counts run slightly high.
const cnt = (x) => { if (x === null || x === undefined || x === '') return null; const v = Number(x); return Number.isFinite(v) && v >= 0 ? Math.round(v) : null; };
export function compactEmpower(pages, meta) {
  const rows = [], aliases = {};
  let medicare = 0, dependent = 0;
  for (const p of pages) for (const ft of (p && p.features) || []) {
    const a = ft.attributes || {};
    const f = String(a.FIPS_Code ?? '').trim().padStart(5, '0');
    if (!/^\d{5}$/.test(f)) continue;
    const v = EMPOWER_FIELDS.slice(2).map((k) => cnt(a[k]));
    rows.push([f, ...v]);
    medicare += v[0] || 0; dependent += v[1] || 0;
    const r = String(a.FIPS_Code_recode ?? '').trim().padStart(5, '0');
    if (/^\d{5}$/.test(r) && r !== f) aliases[r] = f;
  }
  rows.sort((x, y) => (x[0] < y[0] ? -1 : 1));
  const ed = meta && meta.editingInfo && (meta.editingInfo.dataLastEditDate || meta.editingInfo.lastEditDate);
  return {
    source: 'HHS emPOWER Program (CMS, HHS)', url: 'https://empowerprogram.hhs.gov/empowermap', service: EMPOWER_LAYER,
    asOf: ed ? new Date(ed).toISOString() : null,
    fields: ['fips', 'medicare', 'electricityDependent', 'dialysis', 'oxygen', 'homeHealth', 'hospice'],
    note: 'Medicare beneficiaries only (Fee-for-Service and Medicare Advantage). HHS shows ZIP Codes with 1 to 10 people as 11 before summing counties, so small counts run slightly high.',
    nCounties: rows.length, medicare, electricityDependent: dependent, aliases, rows,
  };
}
async function readEmpower() {
  const q = (off) => `${EMPOWER_LAYER}/query?where=1%3D1&outFields=${EMPOWER_FIELDS.join(',')}&returnGeometry=false&orderByFields=OBJECTID&resultOffset=${off}&resultRecordCount=2000&f=json`;
  const pages = [];
  for (let off = 0, i = 0; i < 6; i++, off += 2000) {
    const j = JSON.parse(await getText(q(off), 25000));
    if (j.error) throw new Error(`emPOWER: ${j.error.message || j.error.code}`);
    pages.push(j);
    if (!j.exceededTransferLimit || !(j.features || []).length) break;
  }
  const meta = await getText(`${EMPOWER_LAYER}?f=json`, 15000).then((t) => JSON.parse(t)).catch(() => null);
  const out = compactEmpower(pages, meta);
  if (out.nCounties < 1000) throw new Error(`emPOWER returned only ${out.nCounties} counties`);
  return out;
}

// ------------------------------------------------------------------ Water: shared helpers
const clean = (x) => String(x ?? '').replace(/\s+/g, ' ').trim();
const yes = (x) => /^(y|yes|true|1)$/i.test(clean(x));
const int = (x) => { const v = Number(clean(x).replace(/,/g, '')); return clean(x) !== '' && Number.isFinite(v) ? Math.round(v) : null; };

// ------------------------------------------------------------------ Water: rivers (NOAA NWPS)
// Layer 0 of the National Water Prediction Service river-gauge map service: one point per gauge with its
// latest observation and flood status (major, moderate, minor, action, no_flooding, not_defined,
// low_threshold, obs_not_current, out_of_service). NOAA updates it every 30 minutes; most stages come from
// USGS stream gauges. Stage thresholds are strings in the gauge's units; NOAA writes missing values as blank
// or as large negative sentinels.
const RIVERS_LAYER = 'https://mapservices.weather.noaa.gov/eventdriven/rest/services/water/riv_gauges/MapServer/0';
export const RIVER_LEVELS = ['major', 'moderate', 'minor', 'action'];
const RIVER_FIELDS = ['gaugelid', 'status', 'location', 'waterbody', 'state', 'obstime', 'observed', 'units', 'action', 'flood', 'moderate', 'major', 'url', 'latitude', 'longitude'];
const stage = (x) => { const t = clean(x); if (!t) return null; const v = Number(t); return Number.isFinite(v) && v > -900 ? v : null; };
function gaugeUrl(u, lid) {
  const t = clean(u);
  return /^https:\/\/water\.(noaa|weather)\.gov\/[\w./?=&-]*$/i.test(t) ? t : `https://water.noaa.gov/gauges/${lid}`;
}
export function compactRivers(j, stats) {
  if (!j || typeof j !== 'object' || !Array.isArray(j.features)) throw new Error(`rivers: ${(j && j.error && j.error.message) || 'unexpected response'}`);
  const rows = [], counts = { major: 0, moderate: 0, minor: 0, action: 0 };
  for (const ft of j.features) {
    const a = (ft && ft.attributes) || {};
    const s = clean(a.status).toLowerCase(), lid = clean(a.gaugelid).toUpperCase();
    const lat = Number(a.latitude), lon = Number(a.longitude);
    if (!RIVER_LEVELS.includes(s) || !/^[A-Z0-9]{3,6}$/.test(lid)) continue;
    if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180 || (lat === 0 && lon === 0)) continue;
    counts[s] += 1;
    rows.push([lid, s, clean(a.location), clean(a.waterbody), clean(a.state).slice(0, 2).toUpperCase(), clean(a.obstime), stage(a.observed), clean(a.units).slice(0, 6),
      stage(a.action), stage(a.flood), stage(a.moderate), stage(a.major), Math.round(lon * 1e4) / 1e4, Math.round(lat * 1e4) / 1e4, gaugeUrl(a.url, lid)]);
  }
  // Worst first; within a category, furthest above that category's own threshold.
  const thr = (r) => ({ major: r[11], moderate: r[10], minor: r[9], action: r[8] }[r[1]]);
  const over = (r) => (r[6] != null && thr(r) != null ? r[6] - thr(r) : -1e9);
  rows.sort((x, y) => RIVER_LEVELS.indexOf(x[1]) - RIVER_LEVELS.indexOf(y[1]) || over(y) - over(x) || (x[2] < y[2] ? -1 : 1));
  let byStatus = null, reporting = null;
  if (stats && Array.isArray(stats.features) && stats.features.length) {
    byStatus = {};
    for (const f of stats.features) { const a = (f && f.attributes) || {}; const k = clean(a.status).toLowerCase(); const n = int(a.n ?? a.N); if (k && n != null) byStatus[k] = n; }
    reporting = Object.entries(byStatus).filter(([k]) => k !== 'obs_not_current' && k !== 'out_of_service').reduce((t, [, n]) => t + n, 0) || null;
  }
  return {
    source: 'NOAA National Water Prediction Service', url: 'https://water.noaa.gov/', service: RIVERS_LAYER,
    fields: ['lid', 'status', 'location', 'waterbody', 'state', 'observedAt', 'observed', 'units', 'action', 'flood', 'moderate', 'major', 'lon', 'lat', 'url'],
    counts, inFlood: counts.major + counts.moderate + counts.minor, rows: rows.slice(0, 1500), byStatus, reporting,
  };
}
async function readRivers() {
  const where = encodeURIComponent(`status IN (${RIVER_LEVELS.map((s) => `'${s}'`).join(',')})`);
  const q = `${RIVERS_LAYER}/query?where=${where}&outFields=${RIVER_FIELDS.join(',')}&returnGeometry=false&f=json`;
  const sq = `${RIVERS_LAYER}/query?where=1%3D1&groupByFieldsForStatistics=status&outStatistics=${encodeURIComponent(JSON.stringify([{ statisticType: 'count', onStatisticField: 'objectid', outStatisticFieldName: 'n' }]))}&f=json`;
  const [j, stats] = await Promise.all([getText(q, 25000).then((t) => JSON.parse(t)), getText(sq, 20000).then((t) => JSON.parse(t)).catch(() => null)]);
  return compactRivers(j, stats);
}

// ------------------------------------------------------------------ Water: drinking-water systems (EPA ECHO)
// ECHO's Drinking Water System Search over SDWIS/Fed: every active community water system (one that serves
// residents year-round) recorded as serving the county. Values arrive as strings. Compliance fields, as ECHO
// defines them: SNC, the compliance status in the latest official quarter; RulesVio, the count of rules being
// violated as of that quarter; SDWAContaminantsInCurViol, contaminants with a violation in that quarter plus
// new violations reported since; QtrsWithVio, quarters in violation over the past three years (of 12);
// SeriousViolator, unresolved serious, multiple or continuing violations; HealthFlag, health-based violations
// (limits on contaminants or disinfectants, and treatment techniques). States report quarterly and the federal
// copy can lag three to six months.
const ECHO_SDW = 'https://echodata.epa.gov/echo/sdw_rest_services';
export const WATER_FIELDS = ['pwsid', 'name', 'population', 'source', 'status', 'priority', 'healthBased', 'rulesViolated', 'quartersInViolation3y', 'contaminantsNow', 'contaminants3y', 'citiesServed', 'owner', 'report'];
const dfr = (u) => { const t = clean(u).replace(/^http:/i, 'https:'); return /^https:\/\/echo\.epa\.gov\/detailed-facility-report\?[\w=&%.-]+$/i.test(t) ? t : ''; };
export function compactWater(j, fips) {
  const R = j && j.Results;
  if (!R || typeof R !== 'object') throw new Error('ECHO: unexpected response');
  if (R.Error) throw new Error(`ECHO: ${clean(R.Error.ErrorMessage || R.Error.Message || 'error')}`);
  const list = Array.isArray(R.WaterSystems) ? R.WaterSystems : [];
  const queryRows = int(R.QueryRows);
  if (!list.length && queryRows !== 0) throw new Error(`ECHO: ${clean(R.Message) || 'no systems in response'}`);
  const seen = new Set(), rows = [];
  for (const w of list) {
    const id = clean(w && w.PWSId).toUpperCase();
    if (!/^[A-Z0-9]{2}\d{7}$/.test(id) || seen.has(id)) continue;
    if (w.PWSTypeCode && clean(w.PWSTypeCode).toUpperCase() !== 'CWS') continue;
    if (w.PWSActivityCode && clean(w.PWSActivityCode).toUpperCase() !== 'A') continue;
    seen.add(id);
    rows.push([id, clean(w.PWSName), int(w.PopulationServedCount), clean(w.PrimarySourceCode).toUpperCase(), clean(w.SNC), yes(w.SeriousViolator), yes(w.HealthFlag),
      int(w.RulesVio), int(w.QtrsWithVio), clean(w.SDWAContaminantsInCurViol), clean(w.SDWAContaminantsInViol3yr), clean(w.CitiesServed), clean(w.OwnerDesc), dfr(w.DfrUrl)]);
  }
  rows.sort((a, b) => (b[2] || 0) - (a[2] || 0) || (a[1] < b[1] ? -1 : 1));
  const violating = (r) => (r[7] || 0) > 0 || !!r[9] || (/violat|noncompl/i.test(r[4]) && !/^no\b/i.test(r[4]));
  return {
    source: 'EPA ECHO · Safe Drinking Water Information System (SDWIS/Fed)', url: 'https://echo.epa.gov/facilities/facility-search?mediaSelected=sdwa', fips,
    fields: WATER_FIELDS, nSystems: rows.length, population: rows.reduce((t, r) => t + (r[2] || 0), 0),
    nViolating: rows.filter(violating).length, nPriority: rows.filter((r) => r[5]).length, systems: rows.slice(0, 1000),
  };
}
async function readWater(fips) {
  const base = `output=JSON&p_fips=${fips}&p_systyp=CWS&p_act=Y`;
  let j = JSON.parse(await getText(`${ECHO_SDW}.get_systems?${base}&responseset=1000`, 30000, 'application/json'));
  const R = j && j.Results;
  // Some ECHO deployments answer get_systems with summary counts and a query ID only; the rows then come from get_qid.
  if (R && !R.Error && !Array.isArray(R.WaterSystems) && int(R.QueryRows) > 0 && /^\d+$/.test(clean(R.QueryID))) {
    j = JSON.parse(await getText(`${ECHO_SDW}.get_qid?output=JSON&qid=${clean(R.QueryID)}&pageno=1&responseset=1000`, 30000, 'application/json'));
    if (j && j.Results && j.Results.QueryRows === undefined) j.Results.QueryRows = R.QueryRows;
  }
  return compactWater(j, fips);
}

// ------------------------------------------------------------------ Water: drought (U.S. Drought Monitor)
// County statistics from the National Drought Mitigation Center's data services, asked for the categorical
// form (each category's own share of the county's area). D0 is "abnormally dry"; drought is D1 to D4. If
// the service answers in the cumulative form instead (D0 counts D0 to D4), the shares are converted.
const USDM = 'https://usdmdataservices.unl.edu/api/CountyStatistics/GetDroughtSeverityStatisticsByAreaPercent';
const ymd = (x) => { const t = clean(x); const m = t.match(/^(\d{4})-?(\d{2})-?(\d{2})/); return m ? `${m[1]}-${m[2]}-${m[3]}` : null; };
export function compactDrought(rows, fips) {
  if (!Array.isArray(rows)) throw new Error('USDM: unexpected response');
  const norm = (o) => Object.fromEntries(Object.entries(o || {}).map(([k, v]) => [k.toLowerCase().replace(/[^a-z0-9]/g, ''), v]));
  const recs = rows.map(norm).map((r) => ({ r, week: ymd(r.mapdate) || ymd(r.validstart) })).filter((x) => x.week).sort((a, b) => (a.week < b.week ? 1 : -1));
  if (!recs.length) throw new Error('USDM: no weekly statistics for this county');
  const { r, week } = recs[0];
  const pct = (k) => { const v = Number(clean(r[k]).replace(/,/g, '')); return Number.isFinite(v) ? Math.max(0, Math.min(100, v)) : null; };
  let c = { none: pct('none'), d0: pct('d0'), d1: pct('d1'), d2: pct('d2'), d3: pct('d3'), d4: pct('d4') };
  if (Object.values(c).some((v) => v == null)) throw new Error('USDM: drought categories missing');
  const sum = c.none + c.d0 + c.d1 + c.d2 + c.d3 + c.d4;
  const cumulative = Math.abs(c.none + c.d0 - 100) < 0.6 && c.d0 >= c.d1 && c.d1 >= c.d2 && c.d2 >= c.d3 && c.d3 >= c.d4 && Math.abs(sum - 100) > 0.6;
  if (cumulative) c = { none: c.none, d0: c.d0 - c.d1, d1: c.d1 - c.d2, d2: c.d2 - c.d3, d3: c.d3 - c.d4, d4: c.d4 };
  else if (Math.abs(sum - 100) > 1.5) throw new Error(`USDM: categories sum to ${sum.toFixed(1)}%`);
  const r2 = (v) => Math.round(v * 100) / 100;
  const out = { none: r2(c.none), d0: r2(c.d0), d1: r2(c.d1), d2: r2(c.d2), d3: r2(c.d3), d4: r2(c.d4) };
  const worst = ['d4', 'd3', 'd2', 'd1', 'd0'].find((k) => out[k] >= 0.5) || null;
  return {
    source: 'U.S. Drought Monitor (NDMC, USDA, NOAA)', url: 'https://droughtmonitor.unl.edu/', fips, week,
    validStart: ymd(r.validstart), validEnd: ymd(r.validend), ...out, inDrought: r2(c.d1 + c.d2 + c.d3 + c.d4), worst: worst ? worst.toUpperCase() : null,
  };
}
async function readDrought(fips) {
  const d = (t) => { const x = new Date(t); return `${x.getUTCMonth() + 1}/${x.getUTCDate()}/${x.getUTCFullYear()}`; };
  const url = `${USDM}?aoi=${fips}&startdate=${d(Date.now() - 21 * 864e5)}&enddate=${d(Date.now())}&statisticsType=2`;
  return compactDrought(JSON.parse(await getText(url, 20000, 'application/json')), fips);
}

// County lookups reach a publisher with a value from the request, so misses are capped per instance.
const budget = { t: 0, n: 0 };
function spend() { const now = Date.now(); if (now - budget.t > 60000) { budget.t = now; budget.n = 0; } budget.n += 1; return budget.n <= 40; }

// ------------------------------------------------------------------ serve
function json(o, status = 200, maxAge = 0) {
  return new Response(JSON.stringify(o), { status, headers: { ...CORS, 'content-type': 'application/json; charset=utf-8', 'cache-control': `public, max-age=${maxAge}` } });
}

export async function handle(req) {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (req.method !== 'GET') return json({ error: 'GET only' }, 405);
  const qs = new URL(req.url).searchParams;
  const src = qs.get('src') || 'ercot';
  const t0 = Date.now();
  let body;
  const fips = qs.get('fips') || '';
  if ((src === 'water' || src === 'drought') && !/^\d{5}$/.test(fips)) return json({ error: 'fips must be a five-digit county code' }, 400);
  const county = async (key, ttl, fn) => {
    const hit = cache.get(key);
    if ((!hit || Date.now() - hit.t >= ttl) && !spend()) return hit ? { ...hit.v, stale: true, staleReason: 'busy' } : { error: 'busy: try again in a minute' };
    return cached(key, ttl, fn);
  };
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
  } else if (src === 'empower') {
    body = await cached('empower', 12 * 3600e3, async () => ({ ...(await readEmpower()), fetched: new Date().toISOString() }));
  } else if (src === 'rivers') {
    body = await cached('rivers', 600000, async () => ({ ...(await readRivers()), fetched: new Date().toISOString() }));
  } else if (src === 'water') {
    body = await county('water:' + fips, 24 * 3600e3, async () => ({ ...(await readWater(fips)), fetched: new Date().toISOString() }));
  } else if (src === 'drought') {
    body = await county('drought:' + fips, 6 * 3600e3, async () => ({ ...(await readDrought(fips)), fetched: new Date().toISOString() }));
  } else {
    return json({ error: 'unknown src: use ercot, outages, empower, rivers, water or drought' }, 400);
  }
  // One line per request: counts and timings only, never a request value beyond the county code.
  console.log(JSON.stringify({ src, fips: src === 'water' || src === 'drought' ? fips : null, ms: Date.now() - t0, ok: !body.error, stale: !!body.stale, err: body.error || body.staleReason || null, hz: body.frequency ?? null, counties: body.nCounties ?? null, customers: body.customers ?? null, dependent: body.electricityDependent ?? null, asOf: body.asOf ?? null, gauges: body.rows ? body.rows.length : null, inFlood: body.inFlood ?? null, systems: body.nSystems ?? null, week: body.week ?? null }));
  const maxAge = { ercot: 4, empower: 3600, rivers: 300, water: 3600, drought: 3600 }[src] ?? 30;
  return json({ schema: 'KKP-GRID-LIVE-1.0', src, ...body }, body.error ? (/^busy/.test(body.error) ? 429 : 502) : 200, body.error ? 0 : maxAge);
}

if (typeof Deno !== 'undefined') Deno.serve(handle);
