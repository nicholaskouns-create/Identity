// Water beside the grid: which water system serves you and how it stands with EPA, rivers at flood stage,
// drought, and the water systems in the counties where the power is out.
//   Rivers, county water systems and drought come through Grid's edge function (grid-live: NOAA NWPS, EPA
//   ECHO and the U.S. Drought Monitor), which caches them and adds CORS.
//   Your water system's service area comes straight from EPA's public map service, asked with a box of about
//   2 km around your position; the exact position stays on this device and the match is made here.
// Pure functions are exported for tools/grid/test_grid_water.mjs.
import { fetchLive } from './pulse.js';

export const SAB_LAYER = 'https://services.arcgis.com/cJ9YHowT8TU7DUyn/arcgis/rest/services/Water_System_Boundaries/FeatureServer/0';
export const SAB_PAGE = 'https://www.epa.gov/ground-water-and-drinking-water/public-water-system-service-areas';
export const CDC_BOIL = 'https://www.cdc.gov/water-emergency/about/drinking-water-advisories-an-overview.html';

// NWS flood categories in the conventional order and hues (yellow, orange, red, purple).
export const FLOOD = {
  major: { label: 'Major flooding', short: 'Major', color: '#d88cff', rank: 3 },
  moderate: { label: 'Moderate flooding', short: 'Moderate', color: '#ff5f7a', rank: 2 },
  minor: { label: 'Minor flooding', short: 'Minor', color: '#ff9f43', rank: 1 },
  action: { label: 'Near flood stage', short: 'Near flood', color: '#f2d06b', rank: 0 },
};
export const SOURCE_WATER = {
  SW: 'surface water', GW: 'groundwater', GU: 'groundwater influenced by surface water',
  SWP: 'surface water, bought from another system', GWP: 'groundwater, bought from another system', GUP: 'groundwater influenced by surface water, bought from another system',
};
export const DROUGHT = { D0: 'abnormally dry', D1: 'moderate drought', D2: 'severe drought', D3: 'extreme drought', D4: 'exceptional drought' };

const R_KM = 6371.0088, D2R = Math.PI / 180;
export function km(a, b) {
  const x = Math.sin((b[1] - a[1]) * D2R / 2) ** 2 + Math.cos(a[1] * D2R) * Math.cos(b[1] * D2R) * Math.sin((b[0] - a[0]) * D2R / 2) ** 2;
  return 2 * R_KM * Math.asin(Math.sqrt(x));
}

// ------------------------------------------------------------------ rivers (NOAA NWPS via grid-live)
export function fetchRivers() { return fetchLive('rivers', { timeoutMs: 30000 }); }
export function riverRows(d) {
  return (d && Array.isArray(d.rows) ? d.rows : []).map((r) => ({ lid: r[0], status: r[1], name: r[2], river: r[3], state: r[4], at: r[5], observed: r[6], units: r[7], action: r[8], flood: r[9], moderate: r[10], major: r[11], lon: r[12], lat: r[13], url: r[14] }))
    .filter((r) => FLOOD[r.status] && Number.isFinite(r.lon) && Number.isFinite(r.lat));
}
export function riversGeo(d) {
  return { type: 'FeatureCollection', features: riverRows(d).map((r) => ({ type: 'Feature', geometry: { type: 'Point', coordinates: [r.lon, r.lat] },
    properties: { lid: r.lid, s: r.status, rank: FLOOD[r.status].rank, name: r.name, river: r.river, state: r.state, at: r.at, obs: r.observed ?? '', units: r.units, action: r.action ?? '', flood: r.flood ?? '', moderate: r.moderate ?? '', major: r.major ?? '', url: r.url } })) };
}
// Gauges within `radius` km of a point, nearest first.
export function nearRivers(d, lon, lat, radius = 80) {
  return riverRows(d).map((r) => ({ ...r, km: km([lon, lat], [r.lon, r.lat]) })).filter((r) => r.km <= radius).sort((a, b) => a.km - b.km);
}
// "32.1 ft" with the stage that defines the gauge's category beside it.
export function stageText(r) {
  const u = r.units || 'ft', v = (x) => (Number.isFinite(x) ? `${Number(x).toLocaleString(undefined, { maximumFractionDigits: 2 })} ${u}` : null);
  const thr = { major: ['major', r.major], moderate: ['moderate', r.moderate], minor: ['flood', r.flood], action: ['action', r.action] }[r.status];
  return { now: v(r.observed), ref: thr && v(thr[1]) ? `${thr[0]} stage ${v(thr[1])}` : (v(r.flood) ? `flood stage ${v(r.flood)}` : null) };
}

// ------------------------------------------------------------------ drinking-water systems (EPA ECHO via grid-live)
const memo = new Map();
function remember(key, ttl, fn) {
  const hit = memo.get(key);
  if (hit && Date.now() - hit.t < ttl) return hit.p;
  const p = fn().catch((e) => { memo.delete(key); throw e; });
  memo.set(key, { t: Date.now(), p });
  return p;
}
export const fetchWater = (fips) => remember('w' + fips, 6 * 3600e3, () => fetchLive('water', { timeoutMs: 45000, params: { fips } }));
export const fetchDrought = (fips) => remember('d' + fips, 3 * 3600e3, () => fetchLive('drought', { timeoutMs: 30000, params: { fips } }));

export function systemRow(r) {
  return { pwsid: r[0], name: r[1], pop: r[2], source: r[3], status: r[4], priority: !!r[5], health: !!r[6], rules: r[7], quarters: r[8], now: r[9], past3: r[10], cities: r[11], owner: r[12], report: r[13] || null };
}
export const systems = (d) => (d && Array.isArray(d.systems) ? d.systems.map(systemRow) : []);
export const sourceText = (code) => SOURCE_WATER[String(code || '').toUpperCase()] || null;
// EPA's Detailed Facility Report for the system: ECHO's own link when it sent one, otherwise the same address built from the ID.
export const dfrUrl = (pwsid, s = null) => (s && s.report) || `https://echo.epa.gov/detailed-facility-report?fid=${encodeURIComponent(pwsid)}&sys=SDWIS`;

// How a system stands in EPA's latest quarter, in ECHO's own terms.
export function standing(s) {
  if (!s) return { cls: '', text: 'Not in EPA’s current list for this county' };
  if (s.priority) return { cls: 'bad', text: 'EPA enforcement priority: unresolved serious, multiple or continuing violations' };
  if ((s.rules || 0) > 0 || s.now) return { cls: 'warn', text: `In violation in EPA’s latest quarter${s.now ? `: ${s.now}` : ''}` };
  if (/^no\b/i.test(s.status || '')) return { cls: 'ok', text: 'No violations in EPA’s latest quarter' };
  return { cls: '', text: s.status ? `EPA status: ${s.status}` : 'No compliance status reported' };
}

// Names from SDWIS arrive in capitals: "LAS VEGAS VALLEY WATER DISTRICT" → "Las Vegas Valley Water District".
const KEEP = new Set(['MUD', 'WSC', 'PUD', 'PSD', 'WD', 'WSD', 'USA', 'LLC', 'II', 'III', 'IV', 'KOA', 'RV', 'MHP', 'HOA', 'CDP', 'WTP', 'SUD', 'FWSD', 'MWD', 'CSD', 'CWD', 'PWS', 'PWSD', 'UD', 'WA']);
export function waterName(s) {
  const t = String(s || '').trim();
  if (/[a-z]/.test(t)) return t;
  return t.toLowerCase().replace(/[a-z0-9]+(?:'[a-z]+)?/g, (w) => (KEEP.has(w.toUpperCase()) || /\d/.test(w) && w.length <= 3 ? w.toUpperCase() : w[0].toUpperCase() + w.slice(1)))
    .replace(/(?!^)\b(Of|And|The|At|In|On|For)\b/g, (m) => m.toLowerCase());
}

// ------------------------------------------------------------------ your service area (EPA, direct)
// Shoelace area: positive for counter-clockwise rings (x east, y north).
function signedArea(ring) { let a = 0; for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) a += ring[j][0] * ring[i][1] - ring[i][0] * ring[j][1]; return a / 2; }
export function pointInRing(pt, ring) {
  let c = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i], [xj, yj] = ring[j];
    if (((yi > pt[1]) !== (yj > pt[1])) && (pt[0] < ((xj - xi) * (pt[1] - yi)) / (yj - yi) + xi)) c = !c;
  }
  return c;
}
export function pointInGeom(pt, g) {
  const poly = (p) => pointInRing(pt, p[0]) && !p.slice(1).some((h) => pointInRing(pt, h));
  if (!g) return false;
  if (g.type === 'Polygon') return poly(g.coordinates);
  if (g.type === 'MultiPolygon') return g.coordinates.some(poly);
  return false;
}
// Esri JSON rings → GeoJSON. Esri draws outer rings clockwise and holes counter-clockwise; each hole joins
// the outer ring that contains it.
export function esriPolygon(g) {
  const rings = g && Array.isArray(g.rings) ? g.rings.filter((r) => Array.isArray(r) && r.length >= 4 && r.every((p) => Array.isArray(p) && Number.isFinite(p[0]) && Number.isFinite(p[1]))) : [];
  if (!rings.length) return null;
  let outers = rings.filter((r) => signedArea(r) < 0), holes = rings.filter((r) => signedArea(r) >= 0);
  if (!outers.length) { outers = holes; holes = []; }
  const polys = outers.map((o) => [o]);
  for (const h of holes) { const p = polys.find((pp) => pointInRing(h[0], pp[0])); if (p) p.push(h); else polys.push([h]); }
  return polys.length === 1 ? { type: 'Polygon', coordinates: polys[0] } : { type: 'MultiPolygon', coordinates: polys };
}
function ringsArea(g) { const rs = g.type === 'Polygon' ? [g.coordinates[0]] : g.coordinates.map((p) => p[0]); return rs.reduce((t, r) => t + Math.abs(signedArea(r)), 0); }
// Attribute names vary in case and separators between dataset versions; match them loosely.
const key = (k) => String(k).toLowerCase().replace(/[^a-z0-9]/g, '');
function attr(a, ...names) { const m = new Map(Object.entries(a || {}).map(([k, v]) => [key(k), v])); for (const n of names) { const v = m.get(n); if (v !== undefined && v !== null && String(v).trim() !== '') return v; } return null; }
export function pickServiceArea(j, pt) {
  if (!j || typeof j !== 'object') throw new Error('EPA service areas: unexpected response');
  if (j.error) throw new Error(`EPA service areas: ${j.error.message || j.error.code || 'error'}`);
  if (!Array.isArray(j.features)) throw new Error('EPA service areas: unexpected response');
  const feats = [];
  for (const f of j.features) {
    const geometry = esriPolygon(f && f.geometry); if (!geometry) continue;
    const a = (f && f.attributes) || {};
    const pwsid = String(attr(a, 'pwsid') || '').trim().toUpperCase();
    if (!/^[A-Z0-9]{2}\d{7}$/.test(pwsid)) continue;
    const pop = Number(attr(a, 'populationservedcount', 'popservedcount', 'populationserved', 'popserved'));
    feats.push({ type: 'Feature', geometry, properties: {
      pwsid, name: String(attr(a, 'pwsname', 'name', 'systemname') || pwsid), pop: Number.isFinite(pop) ? pop : null,
      basis: String(attr(a, 'symbologyfield', 'symbology') || ''), verified: String(attr(a, 'verificationstatus') || ''),
      provider: String(attr(a, 'originaldataprovider', 'dataprovider') || ''), area: ringsArea(geometry), mine: false } });
  }
  // Overlapping areas are common (a wholesaler and the town it sells to); the smallest one holding the point is the
  // most specific answer, the rest are listed beside it.
  const hits = feats.filter((f) => pointInGeom(pt, f.geometry)).sort((a, b) => a.properties.area - b.properties.area);
  if (hits[0]) hits[0].properties.mine = true;
  return { hit: hits[0] ? hits[0].properties : null, also: hits.slice(1).map((f) => f.properties), features: hits };
}
export function sabQuery(lon, lat) {
  const d = 0.01, box = [lon - d, lat - d, lon + d, lat + d].map((v) => v.toFixed(3)).join(',');
  return `${SAB_LAYER}/query?${new URLSearchParams({ geometry: box, geometryType: 'esriGeometryEnvelope', inSR: '4326', spatialRel: 'esriSpatialRelIntersects', outFields: '*', returnGeometry: 'true', outSR: '4326', geometryPrecision: '5', maxAllowableOffset: '0.0004', resultRecordCount: '40', f: 'json' })}`;
}
export async function serviceAreaAt(lon, lat, { timeoutMs = 25000 } = {}) {
  const c = new AbortController(), h = setTimeout(() => c.abort(), timeoutMs);
  try {
    const r = await fetch(sabQuery(lon, lat), { mode: 'cors', signal: c.signal });
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return pickServiceArea(await r.json(), [lon, lat]);
  } catch (e) { throw new Error(e.name === 'AbortError' ? 'timed out' : String(e.message || e)); }
  finally { clearTimeout(h); }
}
export const basisText = (p) => (!p ? '' : /model/i.test(p.basis) ? 'EPA-modeled boundary' : /system|sourced/i.test(p.basis) ? `boundary from ${p.provider || 'the water system or state'}` : p.provider ? `boundary from ${p.provider}` : 'EPA service-area map');
