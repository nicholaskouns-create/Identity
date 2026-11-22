// KKP-GRID live sources. Every fetcher returns normalised data plus provenance;
// nothing here fabricates a value. A source that cannot be reached reports its
// status and the panel that depends on it says so.

export const EVIDENCE = Object.freeze({
  LIVE: { glyph: '●', label: 'Live', note: 'fetched from the publisher in this session' },
  RELAY: { glyph: '◆', label: 'Relay', note: 'fetched server-side by the Grid relay (GitHub Actions), served as a snapshot' },
  PUBLISHED: { glyph: '■', label: 'Published', note: 'fixed published dataset, version stated' },
  MODEL: { glyph: '△', label: 'Model', note: 'computed in this browser from live inputs and stated formulas' },
  SIM: { glyph: '○', label: 'Simulated', note: 'synthetic perturbation or injected fault (auditor benchmark)' },
  CERT: { glyph: '✦', label: 'Certified', note: 'exact arithmetic against a SHA-256-pinned certificate' },
});

export const RELAY_URL_DEFAULT = 'https://raw.githubusercontent.com/nicholaskouns-create/Identity/grid-live/live.json';

const settingsKey = 'kkp-grid-settings-v1';
export function loadSettings() {
  try { const s = { relayUrl: RELAY_URL_DEFAULT, eiaKey: '', ...JSON.parse(localStorage.getItem(settingsKey) || '{}') }; s.eiaKey = String(s.eiaKey || '').trim(); return s; }
  catch { return { relayUrl: RELAY_URL_DEFAULT, eiaKey: '' }; }
}
export function saveSettings(s) { try { localStorage.setItem(settingsKey, JSON.stringify(s)); } catch { /* private mode */ } }

async function getJSON(url, { timeout = 15000, init = {} } = {}) {
  const c = new AbortController();
  const t = setTimeout(() => c.abort(), timeout);
  try {
    const r = await fetch(url, { mode: 'cors', cache: 'no-store', ...init, signal: c.signal });
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return await r.json();
  } finally { clearTimeout(t); }
}

// ---------------------------------------------------------------- registry
export const SOURCES = [
  { id: 'swpc-kp', label: 'Planetary K-index (estimated, 1-minute and 3-hour)', provider: 'NOAA Space Weather Prediction Center', evidence: 'LIVE', cadence: 60, url: 'https://services.swpc.noaa.gov/json/planetary_k_index_1m.json', why: 'Geomagnetic storms drive geomagnetically induced currents in high-voltage transformers.' },
  { id: 'swpc-scales', label: 'NOAA space-weather scales (G, S, R)', provider: 'NOAA SWPC', evidence: 'LIVE', cadence: 300, url: 'https://services.swpc.noaa.gov/products/noaa-scales.json', why: 'G-scale is the operational storm level grid operators act on.' },
  { id: 'swpc-alerts', label: 'Space-weather alerts, watches and warnings', provider: 'NOAA SWPC', evidence: 'LIVE', cadence: 300, url: 'https://services.swpc.noaa.gov/products/alerts.json', why: 'K-index warnings and geomagnetic storm watches.' },
  { id: 'swpc-aurora', label: 'OVATION aurora probability', provider: 'NOAA SWPC', evidence: 'LIVE', cadence: 900, url: 'https://services.swpc.noaa.gov/json/ovation_aurora_latest.json', why: 'Where the auroral electrojet sits now: the latitude band of GIC exposure.' },
  { id: 'nws', label: 'Active severe and extreme weather alerts', provider: 'National Weather Service API', evidence: 'LIVE', cadence: 120, url: 'https://api.weather.gov/alerts/active?status=actual&message_type=alert,update&severity=Extreme,Severe', why: 'Heat, ice, wind, hurricane and fire-weather warnings over generation and lines.' },
  { id: 'usgs', label: 'Earthquakes M2.5+ past day', provider: 'USGS Earthquake Hazards Program', evidence: 'LIVE', cadence: 120, url: 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_day.geojson', why: 'Ground motion near substations and plants.' },
  { id: 'wfigs', label: 'Current wildland fire incidents', provider: 'NIFC WFIGS', evidence: 'LIVE', cadence: 600, url: 'https://services3.arcgis.com/T4QMspbfLg3qTGWY/arcgis/rest/services/WFIGS_Incident_Locations_Current/FeatureServer/0/query?where=1%3D1&outFields=*&returnGeometry=true&outSR=4326&f=geojson', why: 'Fires under transmission corridors force de-energisation.' },
  { id: 'wfigs-perim', label: 'Current wildland fire perimeters', provider: 'NIFC WFIGS', evidence: 'LIVE', cadence: 900, url: 'https://services3.arcgis.com/T4QMspbfLg3qTGWY/arcgis/rest/services/WFIGS_Interagency_Perimeters_Current/FeatureServer/0/query?where=1%3D1&outFields=*&returnGeometry=true&outSR=4326&geometryPrecision=4&maxAllowableOffset=0.003&f=geojson', why: 'Burned area footprint.' },
  { id: 'hifld', label: 'Electric power transmission lines (HIFLD, ≥ 345 kV nationally; all voltages in view)', provider: 'HIFLD via DOE NETL ArcGIS', evidence: 'LIVE', cadence: 0, url: 'https://arcgis.netl.doe.gov/server/rest/services/Hosted/EAT_Online_2025_Update_WFL1/FeatureServer/12/query', why: 'The network itself.' },
  { id: 'overpass', label: 'Local power infrastructure around you (lines, substations, towers, plants)', provider: 'OpenStreetMap via Overpass API', evidence: 'LIVE', cadence: 0, url: 'https://overpass-api.de/api/interpreter', why: 'What is near your GPS position, to the tower.' },
  { id: 'eia', label: 'EIA-930 hourly demand, forecast, generation by fuel, interchange', provider: 'U.S. Energy Information Administration API v2', evidence: 'LIVE', cadence: 600, url: 'https://api.eia.gov/v2/electricity/rto/', why: 'The national balance, hour by hour. Needs a free EIA API key (Sources tab).' },
  { id: 'relay', label: 'ISO/RTO real-time load and fuel mix (CAISO, ERCOT, ISO-NE, MISO, NYISO, PJM, SPP)', provider: 'Grid relay: GitHub Actions + gridstatus, publishers’ public endpoints', evidence: 'RELAY', cadence: 300, url: RELAY_URL_DEFAULT, why: 'Operators’ own real-time numbers, fetched server-side because their sites do not allow browser access.' },
  { id: 'ercot-rt', label: 'Real-time grid frequency, time error, inertia, demand, wind and solar (Texas Interconnection)', provider: 'ERCOT Real-Time System Conditions, read by Grid’s edge function (Supabase grid-live)', evidence: 'RELAY', cadence: 10, url: 'https://www.ercot.com/content/cdr/html/real_time_system_conditions.html', why: 'The only live grid frequency a U.S. operator publishes: the interconnection’s heartbeat.' },
  { id: 'odin', label: 'Active power outages by county: customers out, utility, start, estimated restoration', provider: 'ODIN · Outage Data Initiative Nationwide (DOE / ORNL) public feed, read by Grid’s edge function', evidence: 'RELAY', cadence: 60, url: 'https://odin.ornl.gov/odi', why: 'Where the lights are out now, county by county, for the utilities that report to ODIN.' },
  { id: 'empower', label: 'Medicare beneficiaries who rely on electricity-dependent medical equipment, by county', provider: 'HHS emPOWER Program (CMS, HHS) public REST service, read by Grid’s edge function', evidence: 'RELAY', cadence: 43200, url: 'https://empowerprogram.hhs.gov/empowermap', why: 'Where an outage puts people on ventilators, oxygen concentrators, home dialysis and other powered equipment at risk. Medicare only; HHS shows ZIP Codes with 1 to 10 people as 11.' },
  { id: 'alerts', label: 'Background alerts for the counties you choose: outages, restorations, severe weather warnings (on request)', provider: 'Grid’s alert service (Supabase grid-alerts) over standard Web Push; checks ODIN and the National Weather Service every 5 minutes', evidence: 'LIVE', cadence: 300, onDemand: true, url: 'https://github.com/nicholaskouns-create/Identity/tree/main/tools/grid/supabase/grid-alerts', why: 'A notification on your phone when the power goes out where you or your family live, even with Grid closed.' },
  { id: 'counties', label: 'U.S. county boundaries (1:10m)', provider: 'U.S. Census Bureau cartographic boundaries via us-atlas 3.0.1', evidence: 'PUBLISHED', cadence: 0, url: 'https://github.com/topojson/us-atlas', why: 'Where each county’s outages are drawn, and which county you are in.' },
  { id: 'enf', label: 'Your outlet’s frequency, from mains hum at this device’s microphone (on request)', provider: 'This device: Web Audio AudioWorklet; the sound never leaves it', evidence: 'LIVE', cadence: 0, onDemand: true, url: 'https://en.wikipedia.org/wiki/Electrical_network_frequency_analysis', why: 'The frequency of your own interconnection, which no public feed publishes outside Texas.' },
  { id: 'nominatim', label: 'Place search (on request)', provider: 'OpenStreetMap Nominatim', evidence: 'LIVE', cadence: 0, onDemand: true, url: 'https://nominatim.org/', why: 'Find a city or address; counties, states, utilities and plants are searched on the device.' },
  { id: 'imagery', label: 'World Imagery, hillshade, boundaries and places', provider: 'Esri (same registry as the City flight simulators)', evidence: 'LIVE', cadence: 0, url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer', why: 'Base imagery.' },
  { id: 'terrain', label: 'Terrain elevation (Terrarium encoding)', provider: 'AWS Open Data Terrain Tiles · JAXA AW3D30 via MapLibre demo tiles as fallback', evidence: 'PUBLISHED', cadence: 0, url: 'https://registry.opendata.aws/terrain-tiles/', why: '3D relief under the network.' },
  { id: 'night', label: 'VIIRS night lights (Black Marble) and daily Day/Night Band', provider: 'NASA GIBS', evidence: 'LIVE', cadence: 0, url: 'https://gibs.earthdata.nasa.gov/', why: 'Where the load is, seen from orbit; daily band shows outages after major events.' },
  { id: 'plants', label: '9,833 U.S. generating plants', provider: 'WRI Global Power Plant Database v1.3.0 (EIA-860, capacity year 2019)', evidence: 'PUBLISHED', cadence: 0, url: 'https://github.com/wri/global-power-plant-database', why: 'Generation fleet by fuel and nameplate capacity.' },
  { id: 'ieee', label: 'IEEE 14-bus and 118-bus test systems', provider: 'MATPOWER case files via PYPOWER 5.1.21', evidence: 'PUBLISHED', cadence: 0, url: 'https://matpower.org/', why: 'Pinned topology models for the certified spectral monitor.' },
];

// ---------------------------------------------------------------- parsers
export function parseKp1m(rows) {
  if (!Array.isArray(rows)) return [];
  return rows.map((r) => {
    const t = r.time_tag || r.timeTag;
    const kp = Number(r.estimated_kp ?? r.kp_index ?? r.kp ?? r.Kp);
    return { t: new Date(t.endsWith('Z') ? t : t + 'Z'), kp };
  }).filter((r) => Number.isFinite(r.kp) && !Number.isNaN(r.t.getTime()));
}

// noaa-planetary-k-index.json: array-of-arrays with a header row (pre-2026)
// or array of objects (SWPC SCN 26-21, from about 31 March 2026). Both handled.
export function parseKp3h(data) {
  if (!Array.isArray(data) || !data.length) return [];
  let rows;
  if (Array.isArray(data[0])) {
    const head = data[0].map((h) => String(h).toLowerCase());
    const it = head.indexOf('time_tag'), ik = head.findIndex((h) => h === 'kp');
    rows = data.slice(1).map((r) => ({ time_tag: r[it], kp: r[ik] }));
  } else rows = data.map((r) => ({ time_tag: r.time_tag, kp: r.Kp ?? r.kp ?? r.kp_index }));
  return rows.map((r) => ({ t: new Date(String(r.time_tag).replace(' ', 'T') + (String(r.time_tag).endsWith('Z') ? '' : 'Z')), kp: Number(r.kp) }))
    .filter((r) => Number.isFinite(r.kp) && !Number.isNaN(r.t.getTime()));
}

export function gScale(kp) { return kp >= 9 ? 5 : kp >= 8 ? 4 : kp >= 7 ? 3 : kp >= 6 ? 2 : kp >= 5 ? 1 : 0; }

export function parseScales(d) {
  const cur = d && (d['0'] || d[0]);
  if (!cur) return null;
  const pick = (k) => ({ scale: Number(cur[k]?.Scale ?? 0), text: cur[k]?.Text || 'none' });
  return { stamp: `${cur.DateStamp || ''} ${cur.TimeStamp || ''}`.trim(), G: pick('G'), S: pick('S'), R: pick('R') };
}

export function parseSwpcAlerts(rows) {
  if (!Array.isArray(rows)) return [];
  return rows.slice(0, 40).map((a) => {
    const msg = String(a.message || '');
    const head = (msg.match(/(WARNING|ALERT|WATCH|SUMMARY|CANCEL[^:\r\n]*)[^\r\n]*/) || [msg.split('\n')[0]])[0];
    return { id: a.product_id, issued: new Date(String(a.issue_datetime).replace(' ', 'T') + 'Z'), title: head.trim().slice(0, 140), geomagnetic: /geomagnetic|K-index/i.test(msg) };
  }).filter((a) => !Number.isNaN(a.issued.getTime()));
}

export function parseAurora(d) {
  const pts = [];
  const coords = d && d.coordinates;
  if (!Array.isArray(coords)) return { pts, observed: null, forecast: null };
  for (const [lon, lat, p] of coords) {
    if (p < 10 || lat < 15 || lat > 80) continue;
    const L = lon > 180 ? lon - 360 : lon;
    if (L < -170 || L > -50) continue;
    pts.push({ type: 'Feature', properties: { p }, geometry: { type: 'Point', coordinates: [L, lat] } });
  }
  return { pts, observed: d['Observation Time'] || null, forecast: d['Forecast Time'] || null };
}

const NWS_COLORS = [
  [/Tornado/i, '#d87e74'], [/Hurricane|Tropical/i, '#e2a0e6'], [/Ice Storm|Freezing/i, '#9fd3ff'], [/Blizzard|Winter Storm|Winter Weather|Extreme Cold|Cold/i, '#7fb7ff'],
  [/Heat/i, '#ff9b54'], [/Red Flag|Fire/i, '#ff6b3d'], [/Wind/i, '#c9b6ff'], [/Flood/i, '#4fb3a9'], [/Thunderstorm/i, '#f2d06b'], [/Dust|Smoke/i, '#bc9c6c'],
];
export function nwsColor(ev) { for (const [re, c] of NWS_COLORS) if (re.test(ev)) return c; return '#98a6a8'; }

export function parseNws(fc) {
  const feats = (fc && fc.features) || [];
  const withGeom = [], all = [];
  for (const f of feats) {
    const p = f.properties || {};
    const item = { id: p.id || f.id, event: p.event, severity: p.severity, urgency: p.urgency, headline: p.headline, area: p.areaDesc, onset: p.onset || p.effective, ends: p.ends || p.expires, sender: p.senderName, color: nwsColor(p.event || '') };
    all.push(item);
    if (f.geometry) withGeom.push({ type: 'Feature', id: withGeom.length, geometry: f.geometry, properties: { event: item.event, severity: item.severity, headline: item.headline, color: item.color, ends: item.ends } });
  }
  return { all, geo: { type: 'FeatureCollection', features: withGeom } };
}

export function parseQuakes(fc) {
  const feats = ((fc && fc.features) || []).filter((f) => f.geometry && f.geometry.coordinates);
  return {
    type: 'FeatureCollection',
    features: feats.map((f, i) => ({ type: 'Feature', id: i, geometry: { type: 'Point', coordinates: f.geometry.coordinates.slice(0, 2) }, properties: { mag: f.properties.mag, place: f.properties.place, time: f.properties.time, depth: f.geometry.coordinates[2], url: f.properties.url, tsunami: f.properties.tsunami } })),
  };
}

export function parseFires(fc) {
  const feats = ((fc && fc.features) || []).filter((f) => f.geometry && f.geometry.type === 'Point');
  return {
    type: 'FeatureCollection',
    features: feats.map((f, i) => {
      const p = f.properties || {};
      return { type: 'Feature', id: i, geometry: f.geometry, properties: {
        name: p.IncidentName || p.incidentname || p.poly_IncidentName || 'Unnamed incident',
        acres: Number(p.IncidentSize ?? p.DailyAcres ?? p.CalculatedAcres ?? p.DiscoveryAcres ?? 0) || 0,
        contained: p.PercentContained ?? null, state: p.POOState || '', type: p.IncidentTypeCategory || '',
        discovered: p.FireDiscoveryDateTime || null,
      } };
    }).filter((f) => !f.properties.type || f.properties.type === 'WF'),
  };
}

// ---------------------------------------------------------------- fetchers
export async function fetchSpaceWeather() {
  const out = { kp1m: [], kp3h: [], scales: null, alerts: [], errors: {} };
  await Promise.all([
    getJSON('https://services.swpc.noaa.gov/json/planetary_k_index_1m.json').then((d) => { out.kp1m = parseKp1m(d); }).catch((e) => { out.errors.kp1m = String(e.message || e); }),
    getJSON('https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json').then((d) => { out.kp3h = parseKp3h(d); }).catch((e) => { out.errors.kp3h = String(e.message || e); }),
    getJSON('https://services.swpc.noaa.gov/products/noaa-scales.json').then((d) => { out.scales = parseScales(d); }).catch((e) => { out.errors.scales = String(e.message || e); }),
    getJSON('https://services.swpc.noaa.gov/products/alerts.json').then((d) => { out.alerts = parseSwpcAlerts(d); }).catch((e) => { out.errors.alerts = String(e.message || e); }),
  ]);
  return out;
}

export async function fetchAurora() { return parseAurora(await getJSON('https://services.swpc.noaa.gov/json/ovation_aurora_latest.json', { timeout: 30000 })); }
export async function fetchNws() { return parseNws(await getJSON(SOURCES.find((s) => s.id === 'nws').url, { init: { headers: { Accept: 'application/geo+json' } } })); }
export async function fetchQuakes() { return parseQuakes(await getJSON(SOURCES.find((s) => s.id === 'usgs').url)); }
export async function fetchFires() { return parseFires(await getJSON(SOURCES.find((s) => s.id === 'wfigs').url, { timeout: 30000 })); }
export async function fetchPerimeters() {
  const fc = await getJSON(SOURCES.find((s) => s.id === 'wfigs-perim').url, { timeout: 45000 });
  return { type: 'FeatureCollection', features: ((fc && fc.features) || []).filter((f) => f.geometry).map((f, i) => ({ type: 'Feature', id: i, geometry: f.geometry, properties: { name: f.properties?.poly_IncidentName || f.properties?.attr_IncidentName || 'Perimeter', acres: f.properties?.poly_GISAcres || f.properties?.attr_IncidentSize || null } })) };
}

/** HIFLD transmission lines in a bounding box; national view filters to ≥ 345 kV. */
export async function fetchLines(bbox, { minKv = 0, offset = 0.002, maxPages = 6 } = {}) {
  const base = SOURCES.find((s) => s.id === 'hifld').url;
  const feats = [];
  for (let page = 0; page < maxPages; page++) {
    const q = new URLSearchParams({
      where: minKv > 0 ? `voltage >= ${minKv}` : '1=1',
      outFields: 'voltage,volt_class,owner,status,type',
      geometry: bbox.join(','), geometryType: 'esriGeometryEnvelope', inSR: '4326', spatialRel: 'esriSpatialRelIntersects',
      outSR: '4326', maxAllowableOffset: String(offset), geometryPrecision: '5', resultOffset: String(page * 2000), resultRecordCount: '2000', f: 'geojson',
    });
    const fc = await getJSON(`${base}?${q}`, { timeout: 30000 });
    const got = (fc && fc.features) || [];
    for (const f of got) if (f.geometry) feats.push({ type: 'Feature', geometry: f.geometry, properties: { kv: Number(f.properties?.voltage) > 0 ? Number(f.properties.voltage) : null, cls: f.properties?.volt_class || '', owner: f.properties?.owner || '', status: f.properties?.status || '' } });
    if (got.length < 2000 && !(fc && fc.exceededTransferLimit)) break;
  }
  return { type: 'FeatureCollection', features: feats };
}

/** OpenStreetMap power infrastructure within radiusKm of a point. */
export async function fetchLocalPower(lat, lon, radiusKm = 12) {
  const dLat = radiusKm / 111.32, dLon = radiusKm / (111.32 * Math.cos(lat * Math.PI / 180));
  const bb = `${(lat - dLat).toFixed(5)},${(lon - dLon).toFixed(5)},${(lat + dLat).toFixed(5)},${(lon + dLon).toFixed(5)}`;
  const q = `[out:json][timeout:25];(way["power"~"^(line|minor_line|cable)$"](${bb});way["power"~"^(substation|plant|generator)$"](${bb});node["power"~"^(substation|plant|tower|transformer)$"](${bb}););out geom qt;`;
  const d = await getJSON('https://overpass-api.de/api/interpreter', { timeout: 40000, init: { method: 'POST', body: new URLSearchParams({ data: q }) } });
  const feats = [];
  for (const el of (d && d.elements) || []) {
    const t = el.tags || {}, kind = t.power;
    const kv = t.voltage ? Math.max(...String(t.voltage).split(';').map((v) => Number(v) / 1000).filter(Number.isFinite)) : null;
    const props = { kind, kv: Number.isFinite(kv) ? kv : null, name: t.name || t.operator || '', operator: t.operator || '', ref: t.ref || '' };
    if (el.type === 'node') feats.push({ type: 'Feature', geometry: { type: 'Point', coordinates: [el.lon, el.lat] }, properties: props });
    else if (el.geometry) {
      const coords = el.geometry.map((p) => [p.lon, p.lat]);
      const closed = coords.length > 3 && coords[0][0] === coords.at(-1)[0] && coords[0][1] === coords.at(-1)[1];
      feats.push({ type: 'Feature', geometry: closed && kind !== 'line' && kind !== 'minor_line' && kind !== 'cable' ? { type: 'Polygon', coordinates: [coords] } : { type: 'LineString', coordinates: coords }, properties: props });
    }
  }
  return { type: 'FeatureCollection', features: feats, bbox: bb, osmBase: d && d.osm3s && d.osm3s.timestamp_osm_base };
}

// ---------------------------------------------------------------- EIA-930
const EIA = 'https://api.eia.gov/v2/electricity/rto';
function eiaUrl(route, key, params) {
  const q = new URLSearchParams({ api_key: key, frequency: 'hourly', 'data[0]': 'value', 'sort[0][column]': 'period', 'sort[0][direction]': 'desc', length: '5000', ...params.base });
  for (const [k, vs] of Object.entries(params.facets || {})) vs.forEach((v) => q.append(`facets[${k}][]`, v));
  return `${EIA}/${route}/data/?${q}`;
}
export const EIA_REGIONS = ['CAL', 'CAR', 'CENT', 'FLA', 'MIDA', 'MIDW', 'NE', 'NW', 'NY', 'SE', 'SW', 'TEN', 'TEX'];

export async function fetchEia(key) {
  const start = new Date(Date.now() - 50 * 3600e3).toISOString().slice(0, 13);
  const [balance, fuel, regions] = await Promise.all([
    getJSON(eiaUrl('region-data', key, { base: { start }, facets: { respondent: ['US48'] } })),
    getJSON(eiaUrl('fuel-type-data', key, { base: { start }, facets: { respondent: ['US48'] } })),
    getJSON(eiaUrl('region-data', key, { base: { start }, facets: { respondent: EIA_REGIONS, type: ['D'] } })),
  ]);
  return normaliseEia(balance, fuel, regions);
}

export function normaliseEia(balance, fuel, regions) {
  const rows = (d) => (d && d.response && d.response.data) || [];
  const series = {};
  for (const r of rows(balance)) { (series[r.type] ||= []).push({ t: r.period, v: Number(r.value) }); }
  for (const k of Object.keys(series)) series[k].sort((a, b) => (a.t < b.t ? -1 : 1));
  const fuelByHour = {};
  for (const r of rows(fuel)) { (fuelByHour[r.period] ||= {})[r.fueltype] = Number(r.value); }
  const hours = Object.keys(fuelByHour).sort();
  const latestFull = [...hours].reverse().find((h) => Object.keys(fuelByHour[h]).length >= 6) || hours.at(-1);
  const reg = {};
  for (const r of rows(regions)) { (reg[r.respondent] ||= []).push({ t: r.period, v: Number(r.value) }); }
  for (const k of Object.keys(reg)) reg[k].sort((a, b) => (a.t < b.t ? -1 : 1));
  return { series, fuelHour: latestFull, fuel: latestFull ? fuelByHour[latestFull] : null, regions: reg };
}

// ---------------------------------------------------------------- relay
export async function fetchRelay(url) {
  const d = await getJSON(url + (url.includes('?') ? '&' : '?') + 't=' + Math.floor(Date.now() / 60000), { timeout: 20000 });
  if (!d || d.schema !== 'KKP-GRID-RELAY-1.0') throw new Error('unexpected relay schema');
  return d;
}
