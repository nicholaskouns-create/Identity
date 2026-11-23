// Grid · live U.S. power-grid monitor with a certified spectral auditor.
// The Mathematical City · Identity. Orchestrates map, live feeds, workers and pages.
import { GridMap, skyline, terminatorImage, haversine, CONUS } from './map/map.js';
import { Flight, Hud } from './map/fly.js';
import * as SRC from './live/sources.js';
import { PINS } from './engine/pins.js';
import { CLASS_INFO } from './engine/monitor.js';
import { E47_LOCK_FALLBACK } from './engine/e47.js';
import * as P from './ui/panels.js';
import * as PG from './ui/pages.js';
import { sparkline } from './ui/charts.js';
import { fetchLive, interconnectionFor } from './live/pulse.js';
import { EnfMeter } from './live/enf.js';
import { loadCounties, countyAt, unionBbox } from './live/counties.js';
import * as AL from './live/alerts.js';
import * as W from './live/water.js';

const $ = (s, r = document) => r.querySelector(s);
const ORIGIN = location.origin;
const st = { status: {}, gps: null, eia: null, relay: null, space: null, aurora: null, nws: null, quakes: null, fires: null, perimeters: null, lines: null, osm: null };
let settings = SRC.loadSettings();
let gm = null, flight = null, hud = null, plants = null, plantsGeo = null, exposure = null, local = {};
const layerState = {};
const ticker = [];

// ----------------------------------------------------------------- status
function setStatus(id, state, detail = '') {
  st.status[id] = { state, detail, at: state === 'ok' ? new Date() : (st.status[id]?.at || null) };
  const ok = Object.values(st.status).filter((s) => s.state === 'ok').length;
  const tracked = Object.keys(st.status).length;
  $('#live-count').textContent = `${ok}/${tracked}`;
  const li = document.querySelector(`[data-src-dot="${id}"]`);
  if (li) li.className = 'dot ' + (state === 'ok' ? 'ok' : state === 'error' ? 'err' : state === 'loading' ? 'warn' : 'idle');
  if (currentTab === 'sources') PG.updateSources($('#view-sources'), st, settings);
  scheduleNow();
}
function toast(msg) { const t = $('#toast'); t.textContent = msg; t.classList.add('on'); clearTimeout(t._h); t._h = setTimeout(() => t.classList.remove('on'), 3800); }
function pushTicker(time, html, key) {
  if (key && ticker.some((t) => t.key === key)) return;
  ticker.unshift({ time, html, key }); ticker.splice(30);
  $('#ticker').innerHTML = ticker.slice(0, 14).map((t) => `<span class="t"><time>${new Date(t.time).toISOString().slice(11, 16)}Z</time>${t.html}</span>`).join('');
}

// ----------------------------------------------------------------- tabs
let currentTab = 'map';
function showTab(tab) {
  if (!['map', 'fly', 'auditor', 'formalism', 'sources'].includes(tab)) tab = 'map';
  if (currentTab === 'fly' && tab !== 'fly' && flight) flight.stop();
  currentTab = tab;
  document.querySelectorAll('.tabs [data-tab]').forEach((b) => b.setAttribute('aria-selected', String(b.dataset.tab === tab)));
  $('#app').dataset.view = tab;
  $('#view-map').hidden = !(tab === 'map' || tab === 'fly');
  for (const v of ['auditor', 'formalism', 'sources']) $('#view-' + v).hidden = tab !== v;
  $('#rail-left').style.display = tab === 'fly' ? 'none' : '';
  $('#rail-right').style.display = tab === 'fly' ? 'none' : '';
  if (tab === 'fly') startFlight(); else if (gm) gm.map.resize();
  if (tab === 'auditor') { ensureAuditorPage(); PG.updateAuditor($('#view-auditor'), auditorView()); }
  if (tab === 'formalism') { ensureFormalismPage(); PG.updateFormalism($('#view-formalism'), fx); }
  if (tab === 'sources') { ensureSourcesPage(); PG.updateSources($('#view-sources'), st, settings); }
  if (location.hash.slice(1) !== tab) history.replaceState(null, '', tab === 'map' ? location.pathname : '#' + tab);
}
document.addEventListener('click', (e) => {
  const t = e.target.closest('[data-tab]'); if (t) { e.preventDefault(); showTab(t.dataset.tab); return; }
  const f = e.target.closest('[data-fly]'); if (f && f.dataset.fly) { const [lon, lat] = f.dataset.fly.split(',').map(Number); if (Number.isFinite(lon)) { showTab('map'); gm.map.flyTo({ center: [lon, lat], zoom: 8, pitch: 50, duration: 2200 }); } return; }
  const a = e.target.closest('[data-act="fly-here"]'); if (a) { showTab('fly'); return; }
  if (e.target.id === 'btn-locate-2') locate();
  if (e.target.closest('#btn-alert-here')) alertHere();
  if (e.target.id === 'btn-osm') loadLocalGrid(true);
});
window.addEventListener('hashchange', () => showTab(location.hash.slice(1)));

// ----------------------------------------------------------------- clock
setInterval(() => {
  const d = new Date();
  $('#clock').textContent = `${d.toISOString().slice(11, 19)}Z · ${d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} local`;
}, 1000);

// ----------------------------------------------------------------- evidence key
$('#evidence-key').innerHTML = Object.entries(SRC.EVIDENCE).map(([k, v]) => `<span class="ev ev-${k}" title="${v.note}">${v.glyph} ${v.label}</span>`).join('');

// ----------------------------------------------------------------- shared City modules (same origin on github.io)
async function cityModule(path) {
  try { return await import(`${ORIGIN}${path}`); } catch { return null; }
}

// ----------------------------------------------------------------- layers rail
const LAYERS = [
  { id: 'lines', label: 'Transmission (HIFLD)', src: 'hifld', layers: ['lines-glow', 'lines-core'], on: true },
  { id: 'osm', label: 'Local grid around you (OSM)', src: 'overpass', layers: ['osm-line-glow', 'osm-line', 'osm-area', 'osm-point'], on: true },
  { id: 'plants', label: 'Generating plants', src: 'plants', layers: ['plants-heat', 'plants-glow', 'plants-core'], on: true },
  { id: 'skyline', label: 'Generation skyline (3D)', src: 'plants', layers: ['skyline'], on: false },
  { id: 'outages', label: 'Power outages by county (ODIN)', src: 'odin', layers: ['outage-fill', 'outage-line', 'outage-pulse'], on: true },
  { id: 'rivers', label: 'Rivers at flood stage (NOAA)', src: 'nwps', layers: ['rivers-glow', 'rivers'], on: true },
  { id: 'waterarea', label: 'Your water system’s service area (EPA)', src: 'epa-sab', layers: ['waterarea-fill', 'waterarea-line'], on: true },
  { id: 'alerts', label: 'Severe weather warnings', src: 'nws', layers: ['alerts-fill', 'alerts-line'], on: true },
  { id: 'fires', label: 'Wildfires', src: 'wfigs', layers: ['fires-glow', 'fires-core'], on: true },
  { id: 'perims', label: 'Fire perimeters', src: 'wfigs-perim', layers: ['perim-fill', 'perim-line'], on: false },
  { id: 'quakes', label: 'Earthquakes (24 h)', src: 'usgs', layers: ['quakes'], on: true },
  { id: 'aurora', label: 'Auroral oval (GIC band)', src: 'swpc-aurora', layers: ['aurora'], on: true },
  { id: 'dnb', label: 'Night band, last night (VIIRS)', src: 'night', layers: ['dnb'], on: false },
  { id: 'terminator', label: 'Day–night terminator', src: null, layers: ['terminator'], on: true },
  { id: 'labels', label: 'Places and borders', src: 'imagery', layers: ['labels'], on: false },
  { id: 'states', label: 'State lines', src: null, layers: ['states-line'], on: true },
];
function buildLayerRail() {
  $('#layer-list').innerHTML = LAYERS.map((l) => `<li><label><input type="checkbox" data-layer="${l.id}" ${l.on ? 'checked' : ''}><span>${l.label}</span><span class="meta">${l.src ? `<span class="dot idle" data-src-dot="${l.src}"></span>` : ''}</span></label></li>`).join('');
  $('#layer-list').addEventListener('change', (e) => { const id = e.target.dataset.layer; if (id) setLayer(id, e.target.checked); });
  LAYERS.forEach((l) => { layerState[l.id] = l.on; });
}
function setLayer(id, on) {
  layerState[id] = on;
  const l = LAYERS.find((x) => x.id === id); if (!l || !gm) return;
  if (id === 'terminator') { gm.paint('terminator', 'raster-opacity', on && (gm.scene === 'satellite' || gm.scene === 'terrain') ? 0.82 : 0); return; }
  gm.vis(l.layers, on);
  if (id === 'lines' && on) refreshLines();
  if (id === 'perims' && on && !st.perimeters) loadPerimeters();
  if (id === 'skyline' && on && gm.map.getPitch() < 30) gm.map.easeTo({ pitch: 60, duration: 1200 });
  if (id === 'osm' && on) loadLocalGrid(false);
}

// ----------------------------------------------------------------- map boot
async function bootMap() {
  let worldSources = null;
  const reg = await cityModule('/E47-Kartekeya/interfaces/skyrmion/world-registry.js');
  if (reg && reg.loadWorldRegistry) {
    try { const r = await reg.loadWorldRegistry({ timeoutMs: 2500 }); worldSources = reg.selectWorldSources(r, {}); setStatus('imagery', 'ok', `City world registry · ${r.online ? 'online' : 'fallback'} · ${worldSources.imagery.name}`); }
    catch { /* fall back to the same defaults */ }
  }
  gm = new GridMap($('#map'), { worldSources, onError: (id, msg) => { if (id === 'night' || id === 'dnb') setStatus('night', 'error', msg); if (id === 'dem-hill' || id === 'dem-terrain') setStatus('terrain', 'error', msg); if (id === 'imagery') setStatus('imagery', 'error', msg); } });
  gm.map.on('load', async () => {
    window.__gridMap = gm.map;
    gm.map.once('idle', dismissBoot); setTimeout(dismissBoot, 1200);
    gm.setScene('night');
    for (const l of LAYERS) gm.vis(l.layers, l.on);
    setStatus('terrain', 'ok', 'AWS Terrain Tiles (Terrarium)');
    setStatus('night', 'ok', 'NASA GIBS');
    if (!st.status.imagery || st.status.imagery.state === 'idle') setStatus('imagery', 'ok', 'Esri World Imagery');
    staticReady.then(pushStatic);
    updateTerminator(); setInterval(updateTerminator, 60000);
    wireMapInteractions();
    gm.map.on('moveend', () => { clearTimeout(gm._lt); gm._lt = setTimeout(refreshLines, 700); });
    refreshLines();
    if (st.gps && st.gps.source === 'device') gm.setGps(st.gps);
    pushMapData();
    focusPending();
  });
}

async function updateTerminator() {
  try { const bmp = await terminatorImage(new Date(), 1024); const s = gm.map.getSource('terminator'); if (s) s.updateImage({ image: bmp }); }
  catch (e) { console.warn('terminator', e); }
}

let statesGeo = null;
async function loadStatic() {
  const [pj, sj] = await Promise.all([fetch('data/plants-us.json').then((r) => r.json()), fetch('data/us-states.json').then((r) => r.json())]);
  plants = pj; statesGeo = sj;
  plantsGeo = { type: 'FeatureCollection', features: pj.rows.map(([lon, lat, mw, fuel, name, id], i) => ({ type: 'Feature', id: i, geometry: { type: 'Point', coordinates: [lon, lat] }, properties: { mw, fuel, name, gppd: id } })) };
  setStatus('plants', 'ok', `${pj.count.toLocaleString()} plants · ${(pj.total_mw / 1000).toFixed(0)} GW nameplate`);
  recomputeExposure();
}
function pushStatic() { if (!gm || !gm.ready || !plantsGeo) return; gm.set('plants', plantsGeo); gm.set('skyline', skyline(plantsGeo)); gm.set('states', statesGeo); }
const staticReady = loadStatic().catch((e) => { setStatus('plants', 'error', String(e.message || e)); });

function pushMapData() {
  if (!gm || !gm.ready) return;
  if (st.nws?.data) gm.set('alerts', st.nws.data.geo);
  if (st.quakes?.data) gm.set('quakes', st.quakes.data);
  if (st.fires?.data) gm.set('fires', st.fires.data);
  if (st.perimeters?.data) gm.set('perimeters', st.perimeters.data);
  if (st.aurora?.data) gm.set('aurora', { type: 'FeatureCollection', features: st.aurora.data.pts });
  if (st.osm?.data) gm.set('osm', st.osm.data);
  if (outageGeo) { gm.set('outages', outageGeo.fill); gm.set('outagept', outageGeo.pts); }
  if (water.rivers?.geo) gm.set('rivers', water.rivers.geo);
  gm.set('waterarea', { type: 'FeatureCollection', features: water.here?.area?.features || [] });
}

function wireMapInteractions() {
  const m = gm.map;
  const clickable = ['rivers', 'outage-fill', 'plants-core', 'skyline', 'alerts-fill', 'fires-core', 'quakes', 'lines-core', 'osm-line', 'osm-point', 'osm-area', 'perim-fill', 'waterarea-fill'];
  m.on('click', (e) => {
    const f = m.queryRenderedFeatures(e.point, { layers: clickable.filter((id) => m.getLayer(id)) })[0];
    if (!f) return;
    const p = f.properties, L = f.layer.id; let html = '';
    if (L === 'plants-core' || L === 'skyline') html = `<div class="pop"><div class="k">${P.esc(fuelLabel(p.fuel))} · ${P.ev('PUBLISHED', 'GPPD')}</div><h3>${P.esc(p.name)}</h3><div class="kv"><span>Nameplate</span><b>${Number(p.mw).toLocaleString()} MW</b><span>ID</span><b>${P.esc(p.gppd || '')}</b></div></div>`;
    else if (L === 'alerts-fill') html = `<div class="pop"><div class="k">NWS · ${P.esc(p.severity)} · ${P.ev('LIVE')}</div><h3>${P.esc(p.event)}</h3><p>${P.esc(p.headline || '')}</p><div class="k">until ${P.esc(p.ends || '—')}</div></div>`;
    else if (L === 'fires-core') html = `<div class="pop"><div class="k">NIFC WFIGS · ${P.ev('LIVE')}</div><h3>${P.esc(p.name)}</h3><div class="kv"><span>Size</span><b>${Number(p.acres).toLocaleString()} ac</b><span>Contained</span><b>${p.contained == null || p.contained === 'null' ? '—' : p.contained + '%'}</b><span>State</span><b>${P.esc(p.state)}</b></div></div>`;
    else if (L === 'quakes') html = `<div class="pop"><div class="k">USGS · ${P.ev('LIVE')}</div><h3>M${Number(p.mag).toFixed(1)} · ${P.esc(p.place)}</h3><div class="kv"><span>Time</span><b>${new Date(Number(p.time)).toISOString().replace('T', ' ').slice(0, 16)}Z</b><span>Depth</span><b>${Number(p.depth).toFixed(1)} km</b></div></div>`;
    else if (L === 'lines-core') html = `<div class="pop"><div class="k">HIFLD transmission · ${P.ev('LIVE')}</div><h3>${p.kv && p.kv !== 'null' ? p.kv + ' kV' : P.esc(p.cls || 'voltage not recorded')}</h3><div class="kv"><span>Owner</span><b>${P.esc(p.owner || '—')}</b><span>Status</span><b>${P.esc(p.status || '—')}</b></div></div>`;
    else if (L.startsWith('osm')) html = `<div class="pop"><div class="k">OpenStreetMap · power=${P.esc(p.kind)} · ${P.ev('LIVE')}</div><h3>${P.esc(p.name || p.kind)}</h3><div class="kv"><span>Voltage</span><b>${p.kv && p.kv !== 'null' ? p.kv + ' kV' : '—'}</b><span>Operator</span><b>${P.esc(p.operator || '—')}</b></div></div>`;
    else if (L === 'outage-fill') html = outagePopup(p);
    else if (L === 'rivers') html = riverPopup(p);
    else if (L === 'waterarea-fill') html = waterAreaPopup(p);
    else if (L === 'perim-fill') html = `<div class="pop"><div class="k">Fire perimeter · ${P.ev('LIVE')}</div><h3>${P.esc(p.name)}</h3><div class="kv"><span>Area</span><b>${p.acres ? Number(p.acres).toLocaleString() + ' ac' : '—'}</b></div></div>`;
    if (html) gm.popup(e.lngLat, html);
  });
  for (const id of clickable) { m.on('mouseenter', id, () => { m.getCanvas().style.cursor = 'pointer'; }); m.on('mouseleave', id, () => { m.getCanvas().style.cursor = ''; }); }
}
const fuelLabel = (k) => ({ NUC: 'Nuclear', COL: 'Coal', NG: 'Natural gas', OIL: 'Oil', PET: 'Petroleum coke', WAT: 'Hydro', WND: 'Wind', SUN: 'Solar', GEO: 'Geothermal', BIO: 'Biomass', WST: 'Waste', BAT: 'Battery storage', CHP: 'Cogeneration', OTH: 'Other' }[k] || k);


// ----------------------------------------------------------------- water: rivers, your water system, drought, power–water
// Rivers come every 10 minutes for everyone. Your water system, its EPA record and your county's drought are
// looked up once your position is known; the water systems of the counties with the most customers out are
// looked up as outages change. Failed lookups wait before trying again (two minutes here, five for other counties).
const water = { rivers: null, here: null, top: [], byFips: new Map(), failed: new Map() };
const due = (t, ms) => !t || Date.now() - t > ms;
async function pollRivers() {
  if (!water.rivers) setStatus('nwps', 'loading');
  try {
    const d = await W.fetchRivers();
    water.rivers = { data: d, geo: W.riversGeo(d), at: new Date() };
    setStatus('nwps', 'ok', `${d.inFlood.toLocaleString()} gauges in flood · ${d.counts.action.toLocaleString()} near flood stage${d.reporting ? ` · ${d.reporting.toLocaleString()} reporting` : ''}${d.stale ? ' · cached' : ''}`);
    for (const r of W.riverRows(d).filter((x) => x.status === 'major').slice(0, 3)) pushTicker(Date.now(), `<b style="color:${W.FLOOD.major.color}">Major flooding</b> ${P.esc(r.name)}${r.state ? ', ' + P.esc(r.state) : ''}`, 'riv-' + r.lid + '-major');
    pushMapData();
  } catch (e) { water.rivers = { ...(water.rivers || {}), error: String(e.message || e) }; setStatus('nwps', 'error', water.rivers.error); }
  renderWaterPanel();
}
function loadHereWater() {
  const c = local.county, g = st.gps;
  if (!c || !g || g.source !== 'device') return;
  if (!water.here || water.here.fips !== c.id) water.here = { fips: c.id, label: c.properties.label };
  const h = water.here, label = c.properties.label;
  if (!h.water && !h.wBusy && due(h.wAt, 120000)) {
    h.wBusy = true; h.wAt = Date.now(); setStatus('echo-sdw', 'loading');
    W.fetchWater(c.id).then((d) => { h.water = d; h.wErr = null; water.byFips.set(c.id, d); setStatus('echo-sdw', 'ok', `${d.nSystems.toLocaleString()} community water systems in ${label}${d.stale ? ' · cached' : ''}`); })
      .catch((e) => { h.wErr = String(e.message || e); setStatus('echo-sdw', 'error', h.wErr); }).finally(() => { h.wBusy = false; renderWaterPanel(); });
  }
  if (!h.drought && !h.dBusy && due(h.dAt, 120000)) {
    h.dBusy = true; h.dAt = Date.now(); setStatus('usdm', 'loading');
    W.fetchDrought(c.id).then((d) => { h.drought = d; setStatus('usdm', 'ok', `${label}: ${d.inDrought.toFixed(0)}% in drought · week of ${d.week}`); })
      .catch((e) => { h.dErr = String(e.message || e); setStatus('usdm', 'error', h.dErr); }).finally(() => { h.dBusy = false; renderWaterPanel(); });
  }
  // EPA is asked again only after you leave the area found, or move more than 1 km where none was found.
  const at = [g.lon, g.lat], mine = h.area?.hit ? h.area.features[0] : null;
  const inside = !!(mine && W.pointInGeom(at, mine.geometry)), moved = h.areaAt ? W.km(h.areaAt, at) : Infinity;
  if (!h.aBusy && !inside && moved > 1 && (!h.aErr || due(h.aAt, 120000))) {
    h.aBusy = true; h.aAt = Date.now(); setStatus('epa-sab', 'loading');
    W.serviceAreaAt(g.lon, g.lat).then((r) => { h.area = r; h.areaAt = at; h.aErr = null; setStatus('epa-sab', 'ok', r.hit ? `${W.waterName(r.hit.name)} · ${W.basisText(r.hit)}` : 'no service area mapped at your position'); pushMapData(); })
      .catch((e) => { h.aErr = String(e.message || e); setStatus('epa-sab', 'error', h.aErr); }).finally(() => { h.aBusy = false; renderWaterPanel(); });
  }
}
function loadOutageWater() {
  const o = st.outages?.data; if (!o) return;
  water.top = o.counties.filter((r) => r[1] >= 1000).slice(0, 3).map((r) => ({ fips: r[0], out: r[1], label: counties?.byFips.get(r[0])?.properties.label || r[0] }));
  for (const t of water.top) {
    if (water.byFips.has(t.fips) || !due(water.failed.get(t.fips), 300000)) continue;
    W.fetchWater(t.fips).then((d) => { water.byFips.set(t.fips, d); water.failed.delete(t.fips); }).catch(() => { water.failed.set(t.fips, Date.now()); }).finally(renderWaterPanel);
  }
}
function renderWaterPanel() {
  const top = water.top.map((t) => ({ ...t, water: water.byFips.get(t.fips) || null, err: water.failed.has(t.fips) }));
  P.renderWater($('#p-water'), { rivers: water.rivers, here: water.here, top }, local, { gps: st.gps, outHere: local.county ? outageByFips.get(local.county.id) || null : null });
  scheduleNow();
}
const numOr = (x) => (x === '' || x === null || x === undefined ? null : Number(x));
function riverPopup(p) {
  const f = W.FLOOD[p.s] || W.FLOOD.action;
  const t = W.stageText({ status: p.s, observed: numOr(p.obs), units: p.units, action: numOr(p.action), flood: numOr(p.flood), moderate: numOr(p.moderate), major: numOr(p.major) });
  const url = /^https:\/\/water\.(noaa|weather)\.gov\//i.test(String(p.url || '')) ? p.url : `https://water.noaa.gov/gauges/${encodeURIComponent(p.lid)}`;
  return `<div class="pop"><div class="k">NOAA river gauge ${P.esc(p.lid)} · ${P.ev('RELAY')}</div><h3>${P.esc(p.name)}</h3><div class="kv"><span>Status</span><b style="color:${f.color}">${P.esc(f.label)}</b><span>Stage</span><b>${P.esc(t.now || '—')}</b><span>Threshold</span><b>${P.esc(t.ref || '—')}</b><span>Observed</span><b>${P.esc(p.at || '—')}</b></div><p class="pop-link"><a href="${P.esc(url)}" target="_blank" rel="noopener">Hydrograph and forecast at NOAA ↗</a></p></div>`;
}
function waterAreaPopup(p) {
  const s = W.systems(water.here?.water).find((x) => x.pwsid === p.pwsid) || null, sd = W.standing(water.here?.water ? s : null);
  const pop = Number(p.pop);
  return `<div class="pop"><div class="k">${p.mine ? 'Your water system' : 'Water system'} · EPA · ${P.ev('LIVE')}</div><h3>${P.esc(W.waterName(s?.name || p.name))}</h3><div class="kv"><span>Serves</span><b>${Number.isFinite(pop) && pop > 0 ? pop.toLocaleString() + ' people' : '—'}</b><span>System ID</span><b>${P.esc(p.pwsid)}</b><span>Boundary</span><b>${P.esc(W.basisText(p))}</b></div>${water.here?.water ? `<p class="pop-link">${P.esc(sd.text)}</p>` : ''}</div>`;
}
$('#p-water').addEventListener('click', (e) => {
  const rv = e.target.closest('.rivrow'), pw = e.target.closest('.pwrow');
  if (rv && gm) { closeSheets(); if (!layerState.rivers) syncLayer('rivers', true); gm.map.flyTo({ center: [Number(rv.dataset.lon), Number(rv.dataset.lat)], zoom: 10, duration: 1600 }); }
  else if (pw) focusCounty(pw.dataset.fips);
  else if (e.target.closest('#riv-fit') && gm) { const rows = W.riverRows(water.rivers?.data), fl = rows.filter((r) => r.status !== 'action'), use = fl.length ? fl : rows; if (use.length) { closeSheets(); if (!layerState.rivers) syncLayer('rivers', true); fitBox([Math.min(...use.map((r) => r.lon)) - 0.5, Math.min(...use.map((r) => r.lat)) - 0.5, Math.max(...use.map((r) => r.lon)) + 0.5, Math.max(...use.map((r) => r.lat)) + 0.5], 8); } }
  else if (e.target.closest('#w-locate')) locate();
  else if (e.target.closest('#w-area')) { const fts = water.here?.area?.features; if (fts && fts[0]) { closeSheets(); if (!layerState.waterarea) syncLayer('waterarea', true); fitBox(bboxOf(fts[0].geometry), 13); } }
});

// ----------------------------------------------------------------- frequency (ERCOT) and outages (ODIN) via grid-live
let counties = null, outageGeo = null, outageByFips = new Map();
// Background alerts (live/alerts.js) and the HHS emPOWER layer, declared early: the outage panel reads both.
const alerts = { plat: AL.platform(), prefs: AL.loadPrefs(), home: AL.loadHome(), busy: false, msg: '', err: false, key: null, lastSweep: null };
let empower = null, empByFips = null;
// A notification tap opens Grid at ?county=FIPS; the map flies there once counties and the map are ready.
let pendingCounty = (() => { const c = new URLSearchParams(location.search).get('county'); return c && /^\d{5}$/.test(c) ? c : null; })();
async function ensureCounties() {
  if (counties) return counties;
  try { counties = await loadCounties(); setStatus('counties', 'ok', `${counties.features.length.toLocaleString()} counties`); computeLocal(); buildOutageGeo(); focusPending(); }
  catch (e) { setStatus('counties', 'error', String(e.message || e)); }
  return counties;
}
function focusPending() {
  if (!pendingCounty || !counties || !gm || !gm.ready) return;
  const f = pendingCounty; pendingCounty = null;
  if (currentTab !== 'map') showTab('map');
  if (!layerState.outages) syncLayer('outages', true);
  if (!layerState.alerts) syncLayer('alerts', true);
  focusCounty(f);
}
async function pollErcot() {
  if (!st.ercot) setStatus('ercot-rt', 'loading');
  try {
    const d = await fetchLive('ercot', { timeoutMs: 15000 });
    const hist = st.ercot?.hist || [], t = Date.parse(d.updated || d.fetched) || Date.now();
    if (!hist.length || hist.at(-1).t !== t) hist.push({ t, f: d.frequency });
    while (hist.length && hist[0].t < Date.now() - 45 * 60000) hist.shift();
    st.ercot = { data: d, at: new Date(), hist };
    setStatus('ercot-rt', 'ok', `${d.frequency.toFixed(3)} Hz · time error ${d.timeError} s${d.stale ? ' · cached' : ''}`);
    const dev = (d.frequency - 60) * 1000;
    if (Math.abs(dev) >= 50) pushTicker(t, `<b style="color:#ff9f43">ERCOT ${d.frequency.toFixed(3)} Hz</b> ${dev > 0 ? '+' : '−'}${Math.abs(dev).toFixed(0)} mHz from 60`, 'ercot-' + Math.round(t / 120000));
  } catch (e) { st.ercot = { hist: [], ...(st.ercot || {}), error: String(e.message || e) }; setStatus('ercot-rt', 'error', st.ercot.error); }
  renderFreqPanel();
}
function renderFreqPanel() {
  const keep = enf.running ? $('#enf-box') : null;
  P.renderFrequency($('#p-freq'), st, enf);
  if (keep) $('#enf-box')?.replaceWith(keep);
  drawEnf();
}
async function pollOutages() {
  if (!st.outages) setStatus('odin', 'loading');
  try {
    const d = await fetchLive('outages', { timeoutMs: 30000 });
    st.outages = { data: d, at: new Date() };
    setStatus('odin', 'ok', `${d.customers.toLocaleString()} customers out · ${d.nCounties} counties · ${d.feeds || '?'} utility feeds${d.stale ? ' · cached' : ''}`);
    await ensureCounties(); buildOutageGeo(); loadOutageWater();
    for (const r of d.counties.filter((x) => x[1] >= 5000).slice(0, 3)) {
      const f = counties?.byFips.get(r[0]);
      pushTicker(Date.parse(r[5]) || Date.now(), `<b style="color:#ff5f7a">${r[1].toLocaleString()} out</b> ${P.esc(f ? f.properties.label : r[0])} · ${P.esc(P.utilName(r[3]))}`, 'out-' + r[0] + '-' + Math.round(r[1] / 2500));
    }
    if (local.county) { const r = outageByFips.get(local.county.id); if (r && r[1] >= 10) notify('out-' + r[0] + '-' + Math.round(r[1] / 500), `Power outage in ${local.county.properties.label}`, `${r[1].toLocaleString()} customers out (${P.utilName(r[3])}).`); }
    focusPending();
  } catch (e) { st.outages = { ...(st.outages || {}), error: String(e.message || e) }; setStatus('odin', 'error', st.outages.error); }
  renderOutagePanel(); renderWaterPanel();
}
function buildOutageGeo() {
  const o = st.outages?.data; if (!o || !counties) return;
  outageByFips = new Map(o.counties.map((r) => [r[0], r]));
  const fill = [], pts = [];
  for (const r of o.counties) {
    const f = counties.byFips.get(r[0]); if (!f) continue;
    fill.push({ type: 'Feature', geometry: f.geometry, properties: { fips: r[0], label: f.properties.label, m: r[1], n: r[2], util: P.utilName(r[3]), nu: r[4], since: r[5] || '', back: r[6] || '', cause: r[7] || '', ...empProps(r[0]) } });
    if (r[1] >= 100) pts.push({ type: 'Feature', geometry: { type: 'Point', coordinates: [(f.bbox[0] + f.bbox[2]) / 2, (f.bbox[1] + f.bbox[3]) / 2] }, properties: { m: r[1] } });
  }
  outageGeo = { fill: { type: 'FeatureCollection', features: fill }, pts: { type: 'FeatureCollection', features: pts } };
  pushMapData();
  renderOutagePanel();
}
function renderOutagePanel() {
  P.renderOutages($('#p-outages'), st, countyNames(), local, { emp: empRow, empower, home: alerts.home, alertsOn: alerts.prefs.on });
  scheduleNow();
}

// ----------------------------------------------------------------- HHS emPOWER: who in each county depends on powered medical equipment
const EMP_KEY = 'kkp-grid-empower';
function empRow(f) { if (!empByFips) return null; return empByFips.get(f) || (empower.aliases && empower.aliases[f] ? empByFips.get(empower.aliases[f]) : null) || null; }
function empProps(f) { const e = empRow(f); return e ? { dep: e[2] ?? -1, med: e[1] ?? -1, dia: e[3] ?? -1, oxy: e[4] ?? -1, hh: e[5] ?? -1, hos: e[6] ?? -1 } : { dep: -1 }; }
function setEmpower(d, saved) {
  empower = d; empByFips = new Map(d.rows.map((r) => [r[0], r]));
  const month = d.asOf ? new Date(d.asOf).toLocaleDateString([], { month: 'short', year: 'numeric' }) : 'latest';
  setStatus('empower', 'ok', `${d.electricityDependent.toLocaleString()} Medicare beneficiaries rely on powered equipment · ${d.nCounties.toLocaleString()} counties · HHS data of ${month}${saved ? ' · saved copy' : ''}`);
  buildOutageGeo(); renderOutagePanel();
}
async function loadEmpower() {
  try { const c = JSON.parse(localStorage.getItem(EMP_KEY) || 'null'); if (c && c.d && Date.now() - c.t < 12 * 3600e3) return setEmpower(c.d, true); } catch { /* refetch */ }
  setStatus('empower', 'loading');
  try {
    const d = await fetchLive('empower', { timeoutMs: 60000 });
    setEmpower(d, false);
    try { localStorage.setItem(EMP_KEY, JSON.stringify({ t: Date.now(), d })); } catch { /* storage full: keep in memory */ }
  } catch (e) { setStatus('empower', 'error', String(e.message || e)); }
}
function countyNames() { const m = new Map(); if (counties && st.outages?.data) for (const r of st.outages.data.counties) { const f = counties.byFips.get(r[0]); if (f) m.set(r[0], f.properties.label); } return m; }
const when = (t) => { const d = new Date(t); return t && Number.isFinite(d.getTime()) ? d.toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—'; };
function outagePopup(p) {
  const v = (x) => (x == null || x === 'null' || x === '' ? null : x);
  const k = (x) => (Number(x) >= 0 ? Number(x).toLocaleString() : '—');
  const emp = Number(p.dep) >= 0 ? `<div class="k pop-emp">HHS emPOWER · Medicare only · ${P.ev('RELAY')}</div><div class="kv"><span>Rely on powered medical equipment</span><b>${k(p.dep)}</b><span>Medicare beneficiaries</span><b>${k(p.med)}</b><span>…also on facility dialysis</span><b>${k(p.dia)}</b><span>…also on oxygen service</span><b>${k(p.oxy)}</b><span>…also home health</span><b>${k(p.hh)}</b><span>…also hospice at home</span><b>${k(p.hos)}</b></div>` : '';
  return `<div class="pop"><div class="k">Outages · ODIN · ${P.ev('RELAY')}</div><h3>${P.esc(p.label)}</h3><div class="kv"><span>Customers out</span><b>${Number(p.m).toLocaleString()}</b><span>Outage events</span><b>${Number(p.n).toLocaleString()}</b><span>Utility</span><b>${P.esc(p.util)}${Number(p.nu) > 1 ? ` +${Number(p.nu) - 1}` : ''}</b><span>Since</span><b>${when(v(p.since))}</b><span>Back by</span><b>${v(p.back) ? when(p.back) : 'no estimate'}</b><span>Cause</span><b>${P.esc(v(p.cause) || '—')}</b></div>${emp}<p class="co-line">Generator: outdoors only, 20+ ft from doors, windows and vents.</p></div>`;
}
function fitBox(b, maxZoom = 9) { if (gm && b) gm.map.fitBounds([[b[0], b[1]], [b[2], b[3]]], { padding: GridMap.padding(), maxZoom, duration: 1400 }); }
function fitOutages() { const o = st.outages?.data; if (!o || !counties) return; fitBox(unionBbox(o.counties.slice(0, 40).map((r) => counties.byFips.get(r[0])?.bbox)), 8); }
function focusCounty(fips) {
  const f = counties?.byFips.get(fips); if (!f || !gm) return;
  closeSheets(); fitBox(f.bbox, 9.5);
  const r = outageByFips.get(fips);
  if (r) gm.map.once('moveend', () => gm.popup([(f.bbox[0] + f.bbox[2]) / 2, (f.bbox[1] + f.bbox[3]) / 2], outagePopup({ label: f.properties.label, m: r[1], n: r[2], util: P.utilName(r[3]), nu: r[4], since: r[5], back: r[6], cause: r[7], ...empProps(fips) })));
}

// ----------------------------------------------------------------- your outlet's frequency (microphone, on this device)
const enf = { supported: EnfMeter.supported(), running: false, last: null, hist: [], ic: null, meter: null, error: null, n: 0 };
async function startEnf() {
  enf.error = null; enf.hist = []; enf.n = 0;
  try {
    enf.meter = new EnfMeter((r) => { enf.last = r; if (r.ok && enf.n++ % 5 === 0) { enf.hist.push(r.f); if (enf.hist.length > 240) enf.hist.shift(); } enfTick(); });
    setStatus('enf', 'loading', 'listening');
    await enf.meter.start(); enf.running = true;
  } catch (e) {
    enf.running = false; enf.meter?.stop();
    enf.error = e && e.name === 'NotAllowedError' ? 'Microphone permission was declined, so nothing was measured.' : String((e && e.message) || e);
    setStatus('enf', 'error', enf.error);
  }
  P.renderFrequency($('#p-freq'), st, enf); drawEnf();
}
function stopEnf() { enf.meter?.stop(); enf.meter = null; enf.running = false; enf.last = null; enf.hist = []; setStatus('enf', 'idle', 'stopped'); P.renderFrequency($('#p-freq'), st, enf); }
let enfT = 0;
function enfTick() {
  const now = performance.now(); if (now - enfT < 300) return; enfT = now;
  const body = $('#enf-body'), box = $('#enf-box');
  if (body) body.innerHTML = P.enfBodyHtml(enf); else if (box) box.innerHTML = P.enfHtml(enf);
  drawEnf();
  if (enf.last?.ok) setStatus('enf', 'ok', `${enf.last.f.toFixed(4)} Hz from ${enf.last.used.join('/')} Hz hum`);
}
function drawEnf() { const c = $('#c-enf'); if (c && enf.hist.length > 1) sparkline(c, enf.hist, { h: 30, color: '#6edfd4' }); }
$('#p-freq').addEventListener('click', (e) => { if (e.target.closest('#enf-start')) startEnf(); else if (e.target.closest('#enf-stop')) stopEnf(); });
$('#p-outages').addEventListener('click', (e) => { const r = e.target.closest('.outrow'); if (r) focusCounty(r.dataset.fips); else if (e.target.closest('#out-fit')) { closeSheets(); fitOutages(); } else if (e.target.closest('#out-alerts')) goPanel('p-alerts'); });

// ----------------------------------------------------------------- at a glance
let nowTimer = null;
function scheduleNow() { if (!nowTimer) nowTimer = setTimeout(() => { nowTimer = null; P.renderNow($('#now'), st, { enf, auditor: (($('#audit-pill')?.textContent || '').split('·').pop() || '').trim().toLowerCase() || null, alertsOn: alerts.prefs.on, localOut: !!(local.county && outageByFips.get(local.county.id)), rivers: water.rivers?.data || null }); }, 250); }
function closeSheets() { $('#rail-right').classList.remove('open'); $('#rail-left').classList.remove('open'); }
function goPanel(id) {
  if (currentTab !== 'map') showTab('map');
  const el = $('#' + id); if (!el) return;
  if (matchMedia('(max-width: 860px)').matches) { $('#rail-right').classList.add('open'); $('#rail-left').classList.remove('open'); }
  else $('#rail-right').classList.remove('collapsed');
  el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  el.classList.remove('flash'); void el.offsetWidth; el.classList.add('flash');
}
$('#now').addEventListener('click', (e) => {
  const b = e.target.closest('.now-chip'); if (!b) return;
  if (b.dataset.now === 'out' && st.outages?.data) { if (!layerState.outages) syncLayer('outages', true); fitOutages(); }
  if (b.dataset.now === 'wx' && !layerState.alerts) syncLayer('alerts', true);
  if (b.dataset.now === 'water' && !layerState.rivers) syncLayer('rivers', true);
  goPanel(b.dataset.go);
});
function syncLayer(id, on) { setLayer(id, on); const cb = document.querySelector(`[data-layer="${id}"]`); if (cb) cb.checked = on; }

// ----------------------------------------------------------------- search: counties, states, utilities, plants, places
let palItems = [], palRes = [], palSel = 0, palMode = null; // palMode 'alert': choosing a county to watch
function buildIndex() {
  const items = [];
  if (palMode === 'alert') {
    if (counties) for (const f of counties.features) items.push({ k: 'County', label: f.properties.label, sub: '', fips: f.id, w: 4, n: f.properties.label.toLowerCase() });
    return items;
  }
  if (statesGeo) for (const f of statesGeo.features) items.push({ k: 'State', label: f.properties.name, sub: '', b: bboxOf(f.geometry), w: 5 });
  if (counties) for (const f of counties.features) { const r = outageByFips.get(f.id); items.push({ k: 'County', label: f.properties.label, sub: r ? `${r[1].toLocaleString()} customers out now` : '', b: f.bbox, fips: f.id, w: r ? 4.5 : 4 }); }
  if (st.outages?.data) for (const u of st.outages.data.utilities) items.push({ k: 'Utility', label: P.utilName(u[1]), sub: `${u[2].toLocaleString()} customers out · ${u[4]} ${u[4] === 1 ? 'county' : 'counties'}`, fipsList: String(u[5] || '').split(',').filter(Boolean), w: 3.5 });
  if (plants) for (const r of plants.rows) items.push({ k: 'Plant', label: r[4], sub: `${Math.round(r[2]).toLocaleString()} MW · ${fuelLabel(r[3])}`, pt: [r[0], r[1]], w: 1 + Math.min(1.5, r[2] / 1500) });
  for (const it of items) it.n = it.label.toLowerCase();
  return items;
}
function search(q) {
  q = q.trim().toLowerCase(); if (!q) return [];
  const out = [];
  for (const it of palItems) { const i = it.n.indexOf(q); if (i < 0) continue; out.push([(i === 0 ? 3 : /[\s,(.-]/.test(it.n[i - 1]) ? 2 : 0.5) + it.w * 0.4, it]); }
  return out.sort((a, b) => b[0] - a[0]).slice(0, 12).map((x) => x[1]);
}
function renderPalette() {
  const q = $('#palette-q').value.trim();
  const list = palRes.slice();
  if (q.length >= 3) list.push({ k: 'Place', label: `Find “${q}” on OpenStreetMap`, sub: 'cities, towns and addresses', geo: q });
  palSel = Math.min(palSel, Math.max(0, list.length - 1));
  $('#palette-res').innerHTML = list.length ? list.map((it, i) => `<li role="option" id="pal-${i}" aria-selected="${i === palSel}" data-i="${i}"><span class="kind k-${it.k.toLowerCase()}">${it.k}</span><b>${P.esc(it.label)}</b>${it.sub ? `<small>${P.esc(it.sub)}</small>` : ''}</li>`).join('') : `<li class="hint">${q ? 'Nothing local matches yet.' : palMode === 'alert' ? 'Type a county, or a town to find its county.' : 'Type a county, state, city, utility or power plant.'}</li>`;
  $('#palette-q').setAttribute('aria-activedescendant', list.length ? `pal-${palSel}` : '');
  $('#palette-res')._list = list;
}
async function openPalette(mode = null) {
  palMode = mode === 'alert' ? 'alert' : null;
  $('#palette-q').placeholder = palMode ? 'Which county should Grid watch? A county or a town' : 'County, state, city, utility or power plant';
  $('#palette').hidden = false; $('#palette-q').value = ''; palRes = []; palSel = 0;
  palItems = buildIndex(); renderPalette(); $('#palette-q').focus();
  if (!counties) { await ensureCounties(); palItems = buildIndex(); palRes = search($('#palette-q').value); renderPalette(); }
}
function closePalette() { $('#palette').hidden = true; }
async function choose(it) {
  if (!it) return;
  if (palMode === 'alert' && !it.geo) {
    let c = it.fips ? { fips: it.fips, label: it.label } : null;
    if (!c && it.b && counties) { const f = countyAt(counties, (it.b[0] + it.b[2]) / 2, (it.b[1] + it.b[3]) / 2); if (f) c = { fips: f.id, label: f.properties.label }; }
    closePalette();
    if (c) { addAlertPlace(c); goPanel('p-alerts'); } else alertMsg('That place is not inside a U.S. county that Grid knows.', true);
    return;
  }
  if (it.geo) {
    $('#palette-res').innerHTML = '<li class="hint">Asking OpenStreetMap…</li>';
    try {
      const r = await fetch(`https://nominatim.openstreetmap.org/search?format=jsonv2&countrycodes=us&limit=6&q=${encodeURIComponent(it.geo)}`, { headers: { Accept: 'application/json' } });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      palRes = (await r.json()).map((p) => ({ k: 'Place', label: p.display_name.split(',').slice(0, 3).join(','), sub: (p.type || '').replace(/_/g, ' '), b: [+p.boundingbox[2], +p.boundingbox[0], +p.boundingbox[3], +p.boundingbox[1]] }));
      setStatus('nominatim', 'ok', `${palRes.length} places for “${it.geo}”`);
    } catch (e) { palRes = []; setStatus('nominatim', 'error', String(e.message || e)); }
    palSel = 0; renderPalette(); if (!palRes.length) $('#palette-res').insertAdjacentHTML('afterbegin', '<li class="hint">No place found.</li>');
    return;
  }
  closePalette(); closeSheets();
  if (currentTab !== 'map' && currentTab !== 'fly') showTab('map');
  if (it.pt) gm.map.flyTo({ center: it.pt, zoom: 12.5, pitch: 55, duration: 1800 });
  else if (it.fips) focusCounty(it.fips);
  else if (it.b) fitBox(it.b, it.k === 'Place' ? 13 : 7.5);
  else if (it.fipsList && counties) fitBox(unionBbox(it.fipsList.map((f) => counties.byFips.get(f)?.bbox)), 9);
}
$('#search-btn').addEventListener('click', () => openPalette());
$('#palette').addEventListener('click', (e) => { if (e.target.id === 'palette') closePalette(); const li = e.target.closest('li[data-i]'); if (li) choose($('#palette-res')._list[+li.dataset.i]); });
$('#palette-q').addEventListener('input', () => { palRes = search($('#palette-q').value); palSel = 0; renderPalette(); });
$('#palette-q').addEventListener('keydown', (e) => {
  const list = $('#palette-res')._list || [];
  if (e.key === 'ArrowDown') { palSel = Math.min(list.length - 1, palSel + 1); renderPalette(); e.preventDefault(); }
  else if (e.key === 'ArrowUp') { palSel = Math.max(0, palSel - 1); renderPalette(); e.preventDefault(); }
  else if (e.key === 'Enter') { choose(list[palSel]); e.preventDefault(); }
  else if (e.key === 'Escape') closePalette();
});
document.addEventListener('keydown', (e) => {
  if (e.key === '/' && !/input|textarea|select/i.test(document.activeElement?.tagName || '') && $('#palette').hidden) { e.preventDefault(); openPalette(); }
  else if (e.key === 'Escape' && !$('#palette').hidden) closePalette();
});

// ----------------------------------------------------------------- scenes
document.querySelectorAll('.scene').forEach((b) => b.addEventListener('click', () => {
  document.querySelectorAll('.scene').forEach((x) => x.setAttribute('aria-checked', String(x === b)));
  gm.setScene(b.dataset.scene);
  setLayer('terminator', layerState.terminator);
}));
$('#globe-toggle').addEventListener('change', (e) => gm.setGlobe(e.target.checked));
$('#btn-conus').addEventListener('click', () => gm.fitConus());
$('#btn-locate').addEventListener('click', () => locate());
$('#btn-fly-here').addEventListener('click', () => showTab('fly'));
document.querySelectorAll('[data-collapse]').forEach((b) => b.addEventListener('click', () => { const el = $('#' + b.dataset.collapse); el.classList.toggle('collapsed'); b.textContent = el.classList.contains('collapsed') ? '›' : '‹'; }));
$('#sheet-layers').addEventListener('click', () => { $('#rail-left').classList.toggle('open'); $('#rail-right').classList.remove('open'); });
$('#sheet-panels').addEventListener('click', () => { $('#rail-right').classList.toggle('open'); $('#rail-left').classList.remove('open'); });

// ----------------------------------------------------------------- GPS (CITY-GPS-RUNTIME-1.0 when reachable)
let gpsRuntime = null;
async function bootGps() {
  const chip = $('#gps-chip');
  const onUpdate = (d) => {
    st.gps = { lat: d.lat, lon: d.lon, altitude_m: d.altitude_m, accuracy_m: d.accuracy_m, source: d.source, t: d.timestamp };
    if (d.source === 'device') { setStatus('gps', 'ok', `±${Math.round(d.accuracy_m || 0)} m`); if (gm && gm.ready) gm.setGps(st.gps); if (!local.firstFix) { local.firstFix = true; loadLocalGrid(false); } }
    computeLocal(); renderLocalPanel();
  };
  const mod = await cityModule('/E47-Kartekeya/interfaces/shared/city-gps-runtime.js');
  if (mod && mod.installCityGps) {
    gpsRuntime = mod.installCityGps({ chip, watch: false, label: 'GPS', onUpdate });
  }
  renderLocalPanel();
  if (navigator.permissions) {
    try { const p = await navigator.permissions.query({ name: 'geolocation' }); if (p.state === 'granted') locate(true); else chip.textContent = 'GPS · tap to locate'; } catch { chip.textContent = 'GPS · tap to locate'; }
  }
  chip.style.cursor = 'pointer'; chip.addEventListener('click', () => locate());
  window.__gridGpsUpdate = onUpdate;
}
function locate(quiet) {
  if (!navigator.geolocation) { if (!quiet) toast('This browser has no geolocation.'); return; }
  const chip = $('#gps-chip');
  navigator.geolocation.watchPosition((p) => {
    const d = { lat: p.coords.latitude, lon: p.coords.longitude, altitude_m: p.coords.altitude ?? 0, accuracy_m: p.coords.accuracy, source: 'device', timestamp: p.timestamp };
    if (gpsRuntime && gpsRuntime.publish) gpsRuntime.publish(d); else { chip.textContent = `GPS · ${d.lat.toFixed(4)}°, ${d.lon.toFixed(4)}° · ±${Math.round(d.accuracy_m)} m`; window.__gridGpsUpdate(d); }
    chip.classList.add('live');
    if (!local.flown && gm && gm.ready && !quiet) { local.flown = true; gm.map.flyTo({ center: [d.lon, d.lat], zoom: 11.5, pitch: 55, duration: 2600 }); }
  }, (err) => { st.gps = { ...(st.gps || {}), error: err.message, source: 'seed' }; setStatus('gps', 'error', err.message); renderLocalPanel(); if (!quiet) toast('Location unavailable: ' + err.message); }, { enableHighAccuracy: true, maximumAge: 5000, timeout: 15000 });
}

async function loadLocalGrid(force) {
  if (!st.gps || st.gps.source !== 'device' || !layerState.osm) return;
  if (st.osm?.data && !force && st.osm.center && haversine(st.osm.center, [st.gps.lon, st.gps.lat]) < 3) return;
  setStatus('overpass', 'loading'); local.osmStatus = 'loading…'; renderLocalPanel();
  try {
    const d = await SRC.fetchLocalPower(st.gps.lat, st.gps.lon, 12);
    st.osm = { data: d, center: [st.gps.lon, st.gps.lat], at: new Date() };
    setStatus('overpass', 'ok', `${d.features.length} features · OSM base ${d.osmBase || ''}`);
    pushMapData(); computeLocal();
  } catch (e) { st.osm = { ...(st.osm || {}), error: String(e.message || e) }; local.osmStatus = 'unavailable: ' + (e.message || e); setStatus('overpass', 'error', String(e.message || e)); }
  renderLocalPanel();
}

function computeLocal() {
  const g = st.gps; if (!g || g.source !== 'device') return;
  const here = [g.lon, g.lat];
  if (plants) { let best = null; for (const r of plants.rows) { const d = haversine(here, [r[0], r[1]]); if (!best || d < best.km) best = { km: d, name: r[4], mw: r[2], fuel: r[3] }; } local.plant = best; }
  if (st.osm?.data) {
    const f = st.osm.data.features;
    local.osm = { lines: f.filter((x) => ['line', 'minor_line', 'cable'].includes(x.properties.kind)).length, subs: f.filter((x) => x.properties.kind === 'substation').length, towers: f.filter((x) => x.properties.kind === 'tower').length };
    local.maxKv = Math.max(0, ...f.map((x) => x.properties.kv || 0)) || null;
  }
  local.alerts = st.nws?.data ? st.nws.data.geo.features.filter((a) => pointInGeom(here, a.geometry)).map((a) => a.properties) : [];
  const before = local.county?.id;
  if (counties) local.county = countyAt(counties, g.lon, g.lat);
  if (local.county?.id !== before) {
    renderAlertsPanel(); renderOutagePanel();
    if (!before && local.county && !alerts.prefs.on) { try { if (!sessionStorage.getItem('kkp-grid-alert-tip')) { sessionStorage.setItem('kkp-grid-alert-tip', '1'); toast(`Tap 🔔 Alerts at the top for outage alerts in ${local.county.properties.label}.`); } } catch { /* private mode */ } }
  }
  if (statesGeo) { const sf = statesGeo.features.find((f) => pointInGeom(here, f.geometry)); local.state = sf ? sf.properties.name : null; local.ic = interconnectionFor(local.state, g.lon, g.lat); enf.ic = local.ic; }
  loadHereWater();
}

// ----------------------------------------------------------------- geometry helpers
function pointInRing(pt, ring) { let c = false; for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) { const [xi, yi] = ring[i], [xj, yj] = ring[j]; if (((yi > pt[1]) !== (yj > pt[1])) && (pt[0] < ((xj - xi) * (pt[1] - yi)) / (yj - yi) + xi)) c = !c; } return c; }
function pointInPoly(pt, poly) { if (!pointInRing(pt, poly[0])) return false; for (let k = 1; k < poly.length; k++) if (pointInRing(pt, poly[k])) return false; return true; }
function pointInGeom(pt, g) { if (!g) return false; if (g.type === 'Polygon') return pointInPoly(pt, g.coordinates); if (g.type === 'MultiPolygon') return g.coordinates.some((p) => pointInPoly(pt, p)); return false; }
function bboxOf(g) { let x0 = 180, y0 = 90, x1 = -180, y1 = -90; const walk = (c) => { if (typeof c[0] === 'number') { x0 = Math.min(x0, c[0]); x1 = Math.max(x1, c[0]); y0 = Math.min(y0, c[1]); y1 = Math.max(y1, c[1]); } else c.forEach(walk); }; walk(g.coordinates); return [x0, y0, x1, y1]; }

// ----------------------------------------------------------------- exposure engine (MODEL)
function recomputeExposure() {
  if (!plants) return;
  const rows = plants.rows;
  const exposed = new Set();
  const byEvent = new Map(); let polys = 0;
  for (const f of st.nws?.data?.geo.features || []) {
    polys += 1; const bb = bboxOf(f.geometry); let mw = 0, n = 0;
    for (let i = 0; i < rows.length; i++) { const r = rows[i]; if (r[0] < bb[0] || r[0] > bb[2] || r[1] < bb[1] || r[1] > bb[3]) continue; if (pointInGeom([r[0], r[1]], f.geometry)) { mw += r[2]; n += 1; exposed.add(i); } }
    const e = byEvent.get(f.properties.event) || { event: f.properties.event, color: f.properties.color, mw: 0, n: 0, center: [(bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2] };
    e.mw += mw; e.n += n; byEvent.set(f.properties.event, e);
  }
  const near = [];
  for (const f of st.fires?.data?.features || []) {
    if ((f.properties.acres || 0) < 100) continue;
    const c = f.geometry.coordinates; let mw = 0;
    for (let i = 0; i < rows.length; i++) { const r = rows[i]; if (Math.abs(r[1] - c[1]) > 0.3 || Math.abs(r[0] - c[0]) > 0.4) continue; if (haversine(c, [r[0], r[1]]) <= 25) { mw += r[2]; exposed.add(i); } }
    near.push({ name: f.properties.name, acres: f.properties.acres, mw, lonlat: c });
  }
  near.sort((a, b) => b.mw - a.mw || b.acres - a.acres);
  const qnear = [];
  for (const q of st.quakes?.data?.features || []) {
    const m = q.properties.mag; if (!(m >= 4)) continue;
    const R = m >= 6 ? 200 : m >= 5 ? 100 : 50, c = q.geometry.coordinates; let mw = 0;
    for (let i = 0; i < rows.length; i++) { const r = rows[i]; if (Math.abs(r[1] - c[1]) > R / 100) continue; if (haversine(c, [r[0], r[1]]) <= R) { mw += r[2]; exposed.add(i); } }
    if (mw > 0) qnear.push({ mag: m, place: q.properties.place || '', mw, lonlat: c });
  }
  let amw = 0;
  if (st.aurora?.data?.pts?.length) {
    const grid = new Map(); for (const p of st.aurora.data.pts) grid.set(`${Math.round(p.geometry.coordinates[0])},${Math.round(p.geometry.coordinates[1])}`, p.properties.p);
    for (let i = 0; i < rows.length; i++) { const r = rows[i]; const p = grid.get(`${Math.round(r[0])},${Math.round(r[1])}`); if (p >= 10) { amw += r[2]; exposed.add(i); } }
  }
  let tmw = 0; for (const i of exposed) tmw += rows[i][2];
  exposure = { nws: { polys, byEvent: [...byEvent.values()].filter((e) => e.mw > 0).sort((a, b) => b.mw - a.mw) }, fires: { near }, quakes: { near: qnear }, aurora: { mw: amw }, totals: { mw: tmw, plants: exposed.size } };
  P.renderHazard($('#p-hazard'), st, exposure);
  computeLocal(); renderLocalPanel();
}

// ----------------------------------------------------------------- live loops
function every(sec, fn) { fn(); return setInterval(() => { if (!document.hidden) fn(); }, sec * 1000); }

async function pollSpace() {
  setStatus('swpc-kp', st.space ? 'ok' : 'loading');
  const d = await SRC.fetchSpaceWeather();
  st.space = { data: d, at: new Date() };
  setStatus('swpc-kp', d.kp1m.length || d.kp3h.length ? 'ok' : 'error', d.errors.kp1m || d.errors.kp3h || `${d.kp1m.length} one-minute values`);
  setStatus('swpc-scales', d.scales ? 'ok' : 'error', d.errors.scales || (d.scales ? `G${d.scales.G.scale} S${d.scales.S.scale} R${d.scales.R.scale}` : ''));
  setStatus('swpc-alerts', d.alerts.length || !d.errors.alerts ? 'ok' : 'error', d.errors.alerts || `${d.alerts.length} products`);
  P.renderSpace($('#p-space'), st);
  const kp = d.kp1m.at(-1)?.kp;
  if (kp >= 6) notify('geomagnetic', `Kp ${kp.toFixed(1)} · NOAA G${SRC.gScale(kp)}`, 'Geomagnetic storm conditions: elevated GIC risk for high-voltage transformers.');
  for (const a of d.alerts.filter((x) => x.geomagnetic).slice(0, 2)) pushTicker(a.issued, `<b>SWPC</b> ${P.esc(a.title)}`, 'swpc-' + a.id + a.issued.getTime());
}
async function pollAurora() {
  setStatus('swpc-aurora', 'loading');
  try { st.aurora = { data: await SRC.fetchAurora(), at: new Date() }; setStatus('swpc-aurora', 'ok', `${st.aurora.data.pts.length} cells ≥10% over North America · forecast ${st.aurora.data.forecast || ''}`); pushMapData(); recomputeExposure(); }
  catch (e) { setStatus('swpc-aurora', 'error', String(e.message || e)); }
}
async function pollNws() {
  if (!st.nws) setStatus('nws', 'loading');
  try {
    const d = await SRC.fetchNws(); const prev = new Set((st.nws?.data?.all || []).map((a) => a.id));
    st.nws = { data: d, at: new Date() }; setStatus('nws', 'ok', `${d.all.length} severe/extreme alerts · ${d.geo.features.length} with polygons`);
    for (const a of d.all.filter((x) => !prev.has(x.id)).slice(0, 4)) pushTicker(a.onset || Date.now(), `<b style="color:${a.color}">${P.esc(a.event)}</b> ${P.esc((a.area || '').slice(0, 80))}`, 'nws-' + a.id);
    if (st.gps?.source === 'device') { const here = d.geo.features.filter((f) => f.properties.severity === 'Extreme' && pointInGeom([st.gps.lon, st.gps.lat], f.geometry)); for (const f of here) notify('nws-' + f.id, f.properties.event, f.properties.headline || 'Extreme warning in force at your location.'); }
    pushMapData(); recomputeExposure();
  } catch (e) { setStatus('nws', 'error', String(e.message || e)); }
}
async function pollQuakes() {
  try { const d = await SRC.fetchQuakes(); st.quakes = { data: d, at: new Date() }; setStatus('usgs', 'ok', `${d.features.length} events M2.5+`); for (const q of d.features.filter((f) => f.properties.mag >= 4).slice(0, 3)) pushTicker(q.properties.time, `<b>M${q.properties.mag.toFixed(1)}</b> ${P.esc(q.properties.place || '')}`, 'q-' + q.properties.time); pushMapData(); recomputeExposure(); }
  catch (e) { setStatus('usgs', 'error', String(e.message || e)); }
}
async function pollFires() {
  try { const d = await SRC.fetchFires(); st.fires = { data: d, at: new Date() }; setStatus('wfigs', 'ok', `${d.features.length} wildfire incidents`); for (const f of d.features.filter((x) => x.properties.acres >= 5000).slice(0, 3)) pushTicker(Date.now(), `<b style="color:#ff6b3d">${P.esc(f.properties.name)} fire</b> ${Math.round(f.properties.acres).toLocaleString()} ac ${P.esc(f.properties.state)}`, 'fire-' + f.properties.name); pushMapData(); recomputeExposure(); }
  catch (e) { setStatus('wfigs', 'error', String(e.message || e)); }
}
async function loadPerimeters() {
  setStatus('wfigs-perim', 'loading');
  try { st.perimeters = { data: await SRC.fetchPerimeters(), at: new Date() }; setStatus('wfigs-perim', 'ok', `${st.perimeters.data.features.length} perimeters`); pushMapData(); }
  catch (e) { setStatus('wfigs-perim', 'error', String(e.message || e)); }
}
async function pollEia() {
  if (!settings.eiaKey) { setStatus('eia', 'idle', 'add a free EIA API key in Sources'); P.renderDemand($('#p-demand'), st); return; }
  try { st.eia = { data: await SRC.fetchEia(settings.eiaKey), at: new Date() }; setStatus('eia', 'ok', `Lower 48 + ${Object.keys(st.eia.data.regions).length} regions`); }
  catch (e) { st.eia = { error: String(e.message || e) }; setStatus('eia', 'error', st.eia.error); }
  P.renderDemand($('#p-demand'), st); P.renderMix($('#p-mix'), st);
}
async function pollRelay() {
  try {
    const d = await SRC.fetchRelay(settings.relayUrl); st.relay = { data: d, at: new Date() };
    const live = Object.values(d.isos).filter((x) => Number.isFinite(x.load_mw)).length;
    setStatus('relay', live ? 'ok' : 'error', `${live} operators live · snapshot ${P.ago(d.generated_utc)}${d.eia ? ' · EIA-930 included' : ''}`);
  } catch (e) { st.relay = { ...(st.relay || {}), error: String(e.message || e) }; setStatus('relay', 'error', st.relay.error); }
  P.renderDemand($('#p-demand'), st); P.renderMix($('#p-mix'), st); P.renderIso($('#p-iso'), st);
}

// HIFLD lines: national ≥345 kV once, then the viewport at finer voltage when zoomed in.
const lineCache = new Map();
async function refreshLines() {
  if (!gm || !gm.ready || !layerState.lines) return;
  const z = gm.map.getZoom(), b = gm.map.getBounds();
  let key, bbox, opts;
  if (z < 5.5) { key = 'national'; bbox = [CONUS[0][0], CONUS[0][1], CONUS[1][0], CONUS[1][1]]; opts = { minKv: 345, offset: 0.01, maxPages: 8 }; }
  else {
    const q = z < 8 ? 1 : 0.25, r = (v) => Math.round(v / q) * q;
    bbox = [r(b.getWest()) - q, r(b.getSouth()) - q, r(b.getEast()) + q, r(b.getNorth()) + q];
    opts = { minKv: z < 7 ? 230 : z < 9 ? 100 : 0, offset: z < 8 ? 0.003 : 0.0005, maxPages: 5 };
    key = bbox.join(',') + '|' + opts.minKv;
  }
  if (!lineCache.has(key)) {
    setStatus('hifld', 'loading');
    try { lineCache.set(key, await SRC.fetchLines(bbox, opts)); if (lineCache.size > 12) lineCache.delete(lineCache.keys().next().value); }
    catch (e) { setStatus('hifld', 'error', String(e.message || e)); return; }
  }
  const nat = lineCache.get('national');
  const cur = lineCache.get(key);
  const merged = key === 'national' ? cur : { type: 'FeatureCollection', features: [...(nat ? nat.features : []), ...cur.features] };
  st.lines = { data: merged }; gm.set('lines', merged);
  setStatus('hifld', 'ok', `${merged.features.length.toLocaleString()} segments in view`);
}

// nearest infrastructure for the flight HUD
const nearest = {
  line(here) {
    let best = null;
    const consider = (f, src) => {
      const coords = f.geometry.type === 'LineString' ? f.geometry.coordinates : f.geometry.type === 'MultiLineString' ? f.geometry.coordinates.flat() : null; if (!coords) return;
      for (let i = 0; i < coords.length; i += Math.max(1, Math.floor(coords.length / 40))) { const d = haversine(here, coords[i]); if (!best || d < best.d) best = { d, coords, label: `${f.properties.kv ? f.properties.kv + ' kV' : 'line'} · ${src}` }; }
    };
    for (const f of st.osm?.data?.features || []) if (f.geometry.type === 'LineString' && ['line', 'cable'].includes(f.properties.kind)) consider(f, 'OSM');
    for (const f of st.lines?.data?.features || []) consider(f, 'HIFLD');
    return best && best.d < 40 ? best : null;
  },
  text(here) {
    const parts = [];
    if (plants) { let b = null; for (const r of plants.rows) { const d = haversine(here, [r[0], r[1]]); if (!b || d < b.d) b = { d, r }; } if (b) parts.push(`Plant <b>${P.esc(b.r[4])}</b> · ${b.r[2].toLocaleString()} MW ${fuelLabel(b.r[3])} · ${b.d.toFixed(1)} km`); }
    const l = this.line(here); if (l) parts.push(`Line <b>${P.esc(l.label)}</b> · ${l.d.toFixed(2)} km`);
    const a = (st.nws?.data?.geo.features || []).filter((f) => pointInGeom(here, f.geometry)).map((f) => f.properties.event); if (a.length) parts.push(`<span style="color:var(--hot)">${P.esc(a.join(', '))}</span>`);
    return parts.join('<br>') || 'No infrastructure loaded near the aircraft yet.';
  },
};
function startFlight() {
  if (!gm || !gm.ready) { setTimeout(startFlight, 400); return; }
  if (!hud) { hud = new Hud($('#hud')); hud.nearFn = (h) => nearest.text(h); }
  if (!flight) flight = new Flight(gm, { hud, nearest, onExit: () => showTab('map') });
  if (!flight.active) {
    const o = st.gps && st.gps.source === 'device' ? st.gps : { lat: 36.1699, lon: -115.1398, altitude_m: 610 };
    if (!layerState.osm || !st.osm) loadLocalGrid(false);
    gm.map.jumpTo({ center: [o.lon, o.lat], zoom: 12, pitch: 75 });
    setTimeout(() => flight.start(o), 600);
    toast(st.gps?.source === 'device' ? 'Flying from your position. P starts a line patrol.' : 'Flying from the City default origin (Las Vegas). Allow location to fly from yours.');
  }
}

// ----------------------------------------------------------------- background alerts (Web Push through grid-alerts)
function renderAlertsPanel() {
  alerts.plat = AL.platform(); P.renderAlerts($('#p-alerts'), alerts, local); scheduleNow();
  const b = $('#alerts-btn'), n = alerts.prefs.places.length;
  b.dataset.on = String(!!alerts.prefs.on);
  b.setAttribute('aria-label', alerts.prefs.on ? `Alerts: on for ${n} ${n === 1 ? 'county' : 'counties'}` : 'Alerts: off');
  renderLocalPanel();
}
function renderLocalPanel() { P.renderLocal($('#p-local'), st, local, { on: alerts.prefs.on, n: alerts.prefs.places.length }); }
// One tap from the GPS panel: watch the county you are in and turn alerts on (the permission prompt needs this tap).
function alertHere() {
  if (alerts.prefs.on) { goPanel('p-alerts'); return; }
  const h = hereAsPlace();
  if (h && !alerts.prefs.places.some((x) => x.fips === h.fips) && alerts.prefs.places.length < AL.MAX_PLACES) alerts.prefs = { ...alerts.prefs, places: [...alerts.prefs.places, h] };
  if (!alerts.plat.push || !alerts.prefs.places.length) { AL.savePrefs(alerts.prefs); renderAlertsPanel(); goPanel('p-alerts'); return; }
  const go = AL.turnOn(alerts.prefs, alerts.key);
  goPanel('p-alerts');
  busy(async () => { alerts.prefs = await go; done('Alerts are on. A confirmation notification is on its way.'); });
}
$('#alerts-btn').addEventListener('click', () => goPanel('p-alerts'));
function alertMsg(msg, err = false) { alerts.msg = msg; alerts.err = err; renderAlertsPanel(); }
async function busy(fn) {
  alerts.busy = true; alerts.msg = ''; renderAlertsPanel();
  try { await fn(); } catch (e) { alerts.err = true; alerts.msg = String(e.message || e); } finally { alerts.busy = false; renderAlertsPanel(); renderOutagePanel(); }
}
function done(msg) { alerts.err = false; alerts.msg = msg; }
function commitAlerts(msg = '') {
  AL.savePrefs(alerts.prefs);
  if (!alerts.prefs.on) return alertMsg(msg);
  return busy(async () => { alerts.prefs = await AL.update(alerts.prefs); done(msg ? `${msg} Saved.` : 'Saved.'); });
}
function addAlertPlace(c) {
  const p = alerts.prefs;
  if (p.places.some((x) => x.fips === c.fips)) return alertMsg(`${c.label} is already on the list.`);
  if (p.places.length >= AL.MAX_PLACES) return alertMsg(`Grid watches up to ${AL.MAX_PLACES} counties per device.`, true);
  alerts.prefs = { ...p, places: [...p.places, { fips: c.fips, label: c.label }] };
  return commitAlerts(`Added ${c.label}.`);
}
const hereAsPlace = () => (local.county ? { fips: local.county.id, label: local.county.properties.label } : null);
$('#p-alerts').addEventListener('click', (e) => {
  const t = e.target.closest('button'); if (!t || t.disabled) return;
  if (t.id === 'al-on') {
    if (!alerts.prefs.places.length && hereAsPlace()) alerts.prefs = { ...alerts.prefs, places: [hereAsPlace()] };
    if (!alerts.prefs.places.length) return alertMsg('Add at least one county first.', true);
    // turnOn asks for notification permission first, inside this tap.
    const go = AL.turnOn(alerts.prefs, alerts.key);
    busy(async () => { alerts.prefs = await go; done('Alerts are on. A confirmation notification is on its way.'); });
  } else if (t.id === 'al-test') busy(async () => {
    try { await AL.sendTest(alerts.prefs); done(`Test on its way in about ${AL.TEST_DELAY} seconds. Lock your phone or close Grid now to see it arrive; tapping it should open ${alerts.prefs.places[0]?.label || 'Grid'}.`); }
    catch (err) { throw new Error(err.status === 429 ? 'One test a minute. Try again shortly.' : err.status === 404 ? 'The alert service no longer knows this device. Turn alerts off, then on again.' : String(err.message || err)); }
  });
  else if (t.id === 'al-off') busy(async () => { alerts.prefs = await AL.turnOff(alerts.prefs); done('Alerts are off, and the server copy is deleted.'); });
  else if (t.id === 'al-add') openPalette('alert');
  else if (t.id === 'al-here' && hereAsPlace()) addAlertPlace(hereAsPlace());
  else if (t.dataset.rm) {
    const p = alerts.prefs;
    if (p.on && p.places.length === 1) return alertMsg('Alerts need at least one county. Turn alerts off to remove the last one.', true);
    alerts.prefs = { ...p, places: p.places.filter((x) => x.fips !== t.dataset.rm) };
    commitAlerts('Removed.');
  }
});
$('#p-alerts').addEventListener('change', (e) => {
  const t = e.target;
  if (t.id === 'al-min') { alerts.prefs = { ...alerts.prefs, minOut: +t.value }; commitAlerts(); }
  else if (t.id === 'al-wx') { alerts.prefs = { ...alerts.prefs, weather: t.checked }; commitAlerts(); }
  else if (t.id === 'al-restore') { alerts.prefs = { ...alerts.prefs, restore: t.checked }; commitAlerts(); }
  else if (t.id === 'home-med') {
    alerts.home = { ...alerts.home, medical: t.checked }; AL.saveHome(alerts.home);
    if (t.checked) {
      alerts.prefs = { ...alerts.prefs, minOut: 1, restore: true, weather: true, places: alerts.prefs.places.length || !hereAsPlace() ? alerts.prefs.places : [hereAsPlace()] };
      commitAlerts(alerts.prefs.on ? 'Alerts now cover any outage in your counties.' : 'Set to alert on any outage. Turn alerts on above.');
    } else renderAlertsPanel();
    renderOutagePanel();
  } else if (t.dataset.plan) { alerts.home = { ...alerts.home, done: { ...alerts.home.done, [t.dataset.plan]: t.checked } }; AL.saveHome(alerts.home); }
});
// Notifications switched off for Grid in the browser or phone settings: alerts cannot arrive, so say so plainly,
// show them as off, and remove the server copy so nothing is sent into the void.
async function checkPermission() {
  if (!alerts.prefs.on || !('Notification' in window) || Notification.permission === 'granted') return;
  const denied = Notification.permission === 'denied';
  alerts.prefs = await AL.turnOff(alerts.prefs).catch(() => ({ ...alerts.prefs, on: false }));
  alertMsg(denied ? 'Alerts are off: notifications for Grid are turned off in your settings. Allow them, then turn alerts on again.' : 'Alerts are off: Grid no longer has permission to notify you. Turn alerts on again to allow it.', true);
  renderOutagePanel();
}
document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') checkPermission(); });
if ('serviceWorker' in navigator) navigator.serviceWorker.addEventListener('message', (e) => {
  const d = e.data || {};
  if (d.type !== 'grid-open' || !d.url) return;
  try { const c = new URL(d.url).searchParams.get('county'); if (c && /^\d{5}$/.test(c)) { pendingCounty = c; focusPending(); } } catch { /* ignore */ }
});

// ----------------------------------------------------------------- notifications and capabilities
let notifyOn = false; const notified = new Set();
function notify(key, title, body) {
  if (!notifyOn || notified.has(key) || !('Notification' in window) || Notification.permission !== 'granted') return;
  notified.add(key); try { new Notification('Grid · ' + title, { body, icon: 'icons/grid-192.png', tag: key }); } catch { /* ignore */ }
}
let installEvt = null;
window.addEventListener('beforeinstallprompt', (e) => { e.preventDefault(); installEvt = e; const b = $('#set-install'); if (b) b.hidden = false; });
let wakeLock = null;
const pageHandlers = {
  saveKey(key, relay) { settings = { ...settings, eiaKey: key, relayUrl: relay || SRC.RELAY_URL_DEFAULT }; SRC.saveSettings(settings); toast(key ? 'Key saved on this device. Fetching EIA-930…' : 'Key removed.'); pollEia(); pollRelay(); },
  openAlerts() { goPanel('p-alerts'); },
  async enableNotify() { if (!('Notification' in window)) return toast('Notifications are not supported here.'); const p = await Notification.requestPermission(); notifyOn = p === 'granted'; $('#set-status').textContent = notifyOn ? 'Alerts on for this session.' : 'Notifications were not allowed.'; },
  async wallMode() {
    try { await document.documentElement.requestFullscreen(); } catch { /* optional */ }
    try { wakeLock = await navigator.wakeLock.request('screen'); $('#set-status').textContent = 'Wall mode: screen kept awake while Grid is visible.'; } catch (e) { $('#set-status').textContent = 'Wake lock unavailable: ' + (e.message || e); }
    showTab('map');
  },
  async install() { if (!installEvt) return; installEvt.prompt(); await installEvt.userChoice; installEvt = null; },
};
document.addEventListener('visibilitychange', async () => { if (wakeLock && document.visibilityState === 'visible') { try { wakeLock = await navigator.wakeLock.request('screen'); } catch { /* ignore */ } } });

// ----------------------------------------------------------------- certified spectral monitor (workers)
const monitorW = new Worker(new URL('./engine/worker.js', import.meta.url), { type: 'module' });
const benchW = new Worker(new URL('./engine/worker.js', import.meta.url), { type: 'module' });
let reqId = 0; const pending = new Map();
function ask(w, msg) { return new Promise((res, rej) => { const id = ++reqId; pending.set(id, { res, rej, onStep: msg.onStep, onProgress: msg.onProgress }); const { onStep, onProgress, ...m } = msg; w.postMessage({ ...m, id }); }); }
for (const w of [monitorW, benchW]) w.onmessage = (ev) => {
  const m = ev.data, p = pending.get(m.id); if (!p) return;
  if (m.type === 'verify-step') { if (p.onStep) p.onStep(m.check); return; }
  if (m.type === 'progress') { if (p.onProgress) p.onProgress(m); return; }
  pending.delete(m.id); if (m.type === 'error') p.rej(new Error(m.error)); else p.res(m);
};

const SYS = { ieee14: { label: 'IEEE 14-bus' }, ieee118: { label: 'IEEE 118-bus' } };
const au = { key: 'ieee14', fault: 'L0', untouched: false, flipBranch: null, ticks: 0, ledger: [], lastCertified: null, outcome: null, tol: 0, runs: {} };
const fx = { e47: null, lock: null, lockSource: '', reports: {}, systems: {} };
let reference = null;

async function bootMonitor() {
  const files = {};
  for (const key of Object.keys(SYS)) {
    const [t, c] = await Promise.all([fetch(`data/topology-${key}.json`, { cache: 'no-cache' }).then((r) => r.arrayBuffer()), fetch(`data/certificate-${key}.json`, { cache: 'no-cache' }).then((r) => r.arrayBuffer())]);
    files[key] = { t, c };
    const text = new TextDecoder().decode(t);
    SYS[key].topoText = text; SYS[key].cert = JSON.parse(new TextDecoder().decode(c));
    for (const w of [monitorW, benchW]) {
      const r = await ask(w, { type: 'init', key, topoBytes: t.slice(0), certBytes: c.slice(0) });
      if (w === monitorW) Object.assign(SYS[key], { tol: r.tol, g: r.g, eps0: r.eps0, nonisland: r.nonisland, branches: r.branches, buses: r.buses });
    }
    const cert = SYS[key].cert;
    fx.systems[key] = { lam: cert.eigenvalue_estimates, lo: frac(cert.window.enclosure.lo), hi: frac(cert.window.enclosure.hi), g: frac(cert.gap.g), eps0: frac(cert.envelope.eps0), est: null };
    SYS[key].layout = layoutFor(SYS[key]);
    SYS[key].survey = await fetch(`data/cm2-survey-${key}.json`).then((r) => r.json()).then((d) => d.flips).catch(() => []);
    SYS[key].branchPairs = SYS[key].branches.map((b) => ({ i: SYS[key].buses.findIndex((x) => x[0] === b[0]), j: SYS[key].buses.findIndex((x) => x[0] === b[1]), on: b[4] === 1 }));
  }
  for (const key of Object.keys(SYS)) {
    const rep = (await ask(monitorW, { type: 'verify', key, scope: key === 'ieee14' ? 'all' : 'critical' })).report;
    fx.reports[key] = rep; SYS[key].verified = rep.ok; SYS[key].certHash = rep.certHash; SYS[key].pinnedTopoHash = rep.topoHash;
  }
  au.tol = SYS[au.key].tol;
  if (currentTab === 'formalism') PG.updateFormalism($('#view-formalism'), fx);
  fetch('data/reference-acceptance.json').then((r) => r.json()).then((d) => { reference = d; }).catch(() => {});
  try { const lock = await cityModule('/E47-Kartekeya/interfaces/shared/e47-lock.js'); fx.lock = lock?.E47_LOCK || null; fx.lockSource = lock ? 'E47-Kartekeya/interfaces/shared/e47-lock.js (live import)' : ''; } catch { /* fallback below */ }
  if (!fx.lock) { fx.lock = E47_LOCK_FALLBACK; fx.lockSource = 'embedded copy of the E47 lock contract (live module not reachable from this origin)'; }
  ask(monitorW, { type: 'e47' }).then((r) => { fx.e47 = r.result; if (currentTab === 'formalism') PG.updateFormalism($('#view-formalism'), fx); });
  tickLoop();
}
const frac = (s) => { const [a, b] = String(s).split('/'); return b ? Number(a) / Number(b) : Number(a); };

function layoutFor(sys) {
  const n = sys.buses.length, U = sys.cert.basis.U;
  let pos = U.map((r) => [r[0] + 1e-3 * Math.sin(1.7 * r.length), r[1] ?? 0]);
  const idx = new Map(sys.buses.map((b, i) => [b[0], i]));
  const edges = sys.branches.filter((b) => b[4] === 1).map((b) => [idx.get(b[0]), idx.get(b[1])]);
  const sx = Math.max(...pos.map((p) => Math.abs(p[0]))) || 1, sy = Math.max(...pos.map((p) => Math.abs(p[1]))) || 1;
  pos = pos.map(([x, y], i) => [x / sx + 0.02 * Math.cos(i * 2.39996), y / sy + 0.02 * Math.sin(i * 2.39996)]);
  const k = 1.6 / Math.sqrt(n);
  for (let it = 0; it < 260; it++) {
    const f = pos.map(() => [0, 0]);
    for (let i = 0; i < n; i++) for (let j = i + 1; j < n; j++) { const dx = pos[i][0] - pos[j][0], dy = pos[i][1] - pos[j][1], d2 = dx * dx + dy * dy + 1e-6, s = (k * k) / d2 * 0.02; f[i][0] += dx * s; f[i][1] += dy * s; f[j][0] -= dx * s; f[j][1] -= dy * s; }
    for (const [a, b] of edges) { const dx = pos[a][0] - pos[b][0], dy = pos[a][1] - pos[b][1], d = Math.sqrt(dx * dx + dy * dy) + 1e-9, s = (d - k) * 0.08 / d; f[a][0] -= dx * s; f[a][1] -= dy * s; f[b][0] += dx * s; f[b][1] += dy * s; }
    const t = 0.9 * (1 - it / 260) + 0.05;
    pos = pos.map((p, i) => [p[0] + Math.max(-0.05, Math.min(0.05, f[i][0])) * t, p[1] + Math.max(-0.05, Math.min(0.05, f[i][1])) * t]);
  }
  return pos;
}

function liveScale() {
  const eia = st.eia?.data || st.relay?.data?.eia;
  const D = eia?.series?.D?.filter((p) => Number.isFinite(p.v));
  if (D && D.length > 12) { const mean = D.reduce((a, p) => a + p.v, 0) / D.length; return { scale: Math.max(0.8, Math.min(1.2, D.at(-1).v / mean)), label: `● EIA-930 Lower-48 demand ratio ${(D.at(-1).v / mean).toFixed(3)}` }; }
  const isos = st.relay?.data?.isos;
  if (isos) { const r = []; for (const d of Object.values(isos)) { const h = (d.history || []).map((x) => x[1]); if (h.length > 6 && Number.isFinite(d.load_mw)) r.push(d.load_mw / (h.reduce((a, b) => a + b, 0) / h.length)); } if (r.length) { const s = r.reduce((a, b) => a + b, 0) / r.length; return { scale: Math.max(0.8, Math.min(1.2, s)), label: `◆ ISO load ratio ${s.toFixed(3)} (${r.length} operators)` }; } }
  const h = new Date().getHours() + new Date().getMinutes() / 60;
  const s = 1 + 0.11 * Math.sin((2 * Math.PI * (h - 10)) / 24);
  return { scale: s, label: `△ diurnal model ${s.toFixed(3)} (no live demand feed yet)` };
}

let tickTimer = null, lastDecision = null;
async function tickLoop() {
  clearTimeout(tickTimer);
  const busy = document.hidden ? 15000 : currentTab === 'auditor' ? 2200 : 4500;
  try {
    const sys = SYS[au.key];
    if (!sys.verified) {
      au.outcome = { auditor: 'refuse', dev: [NaN, NaN, NaN, NaN, NaN], pipelines: {}, vote: false };
    } else {
      const ls = liveScale();
      const cls = au.fault;
      const msg = { type: 'tick', key: au.key, cls, scale: ls.scale };
      if (cls === 'CM2') { if (au.flipBranch == null) au.flipBranch = pickHarmfulBranch(sys); msg.flipBranch = au.flipBranch; msg.untouched = [false, false, false, au.untouched, false]; }
      const r = await ask(monitorW, msg);
      const o = r.outcome; au.outcome = o; au.ticks += 1; au.inputLabel = ls.label;
      au.runtimeHash = cls === 'CM2' ? await alteredHash(sys, au.flipBranch) : sys.pinnedTopoHash;
      au.branchLabel = au.flipBranch != null ? `${sys.branches[au.flipBranch][0]}–${sys.branches[au.flipBranch][1]} shown ${sys.branches[au.flipBranch][4] ? 'open' : 'closed'} (was ${sys.branches[au.flipBranch][4] ? 'closed' : 'open'})` : '';
      if (o.auditor !== 'refuse') au.lastCertified = { time: new Date().toISOString(), y: o.delivered };
      await appendLedger(o);
      const d = o.auditor === 'deliver' ? 'deliver' : o.auditor === 'refuse' ? 'refuse' : 'select';
      const pill = $('#audit-pill'); pill.dataset.state = d; pill.innerHTML = `<span class="ap-k">AUDITOR · </span>${d === 'deliver' ? 'certified' : d === 'refuse' ? 'refused' : 'selected ' + P.esc(o.auditor.slice(7))}`;
      if (d !== lastDecision) { pushTicker(Date.now(), `<b>Auditor</b> ${d === 'deliver' ? 'DELIVER CERTIFIED' : d === 'refuse' ? 'REFUSE · topology reprocessing alarm' : 'SELECT CERTIFIED ' + o.auditor.slice(7)} · ${SYS[au.key].label}`); if (d === 'refuse') notify('refuse-' + Date.now(), 'Auditor refused', 'No replica within tolerance; last certified state held.'); lastDecision = d; }
    }
    P.renderAuditorMini($('#p-auditor-mini'), auditorView());
    if (currentTab === 'auditor') PG.updateAuditor($('#view-auditor'), auditorView());
  } catch (e) { console.warn('tick', e); }
  tickTimer = setTimeout(tickLoop, busy);
}
function pickHarmfulBranch(sys) {
  // The single-entry alteration that moves the window component furthest (data/cm2-survey-*.json).
  const top = (sys.survey || []).find((f) => !f.islanding && sys.nonisland.includes(f.k));
  return top ? top.k : sys.nonisland[0];
}
async function alteredHash(sys, k) {
  let i = -1;
  const text = sys.topoText.replace(/\[(\d+),(\d+),"([^"]+)","([^"]+)",(\d)\]/g, (m, a, b, x, t, s) => { i += 1; return i === k ? `[${a},${b},"${x}","${t}",${s === '1' ? 0 : 1}]` : m; });
  const h = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return Array.from(new Uint8Array(h), (b) => b.toString(16).padStart(2, '0')).join('');
}
async function appendLedger(o) {
  const prev = au.ledger.at(-1)?.hash || '0'.repeat(64);
  const e = { time: new Date().toISOString(), system: SYS[au.key].label, fault: au.fault, decision: o.auditor, maxDev: Math.max(...o.dev), dev: o.dev.map((x) => +x.toPrecision(6)), certificate: SYS[au.key].certHash, runtimeTopology: au.runtimeHash, prev };
  const h = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(JSON.stringify(e)));
  e.hash = Array.from(new Uint8Array(h), (b) => b.toString(16).padStart(2, '0')).join('');
  au.ledger.push(e); if (au.ledger.length > 600) au.ledger.splice(0, au.ledger.length - 600);
  try { localStorage.setItem('kkp-grid-last-certified', JSON.stringify({ system: au.key, time: au.lastCertified?.time })); } catch { /* ignore */ }
}
function auditorView() {
  const sys = SYS[au.key];
  return { ...au, label: sys.label, tol: sys.tol || au.tol, certHash: sys.certHash || '', pinnedTopoHash: sys.pinnedTopoHash || '', runtimeHash: au.runtimeHash || sys.pinnedTopoHash || '', layout: sys.layout, branchPairs: sys.branchPairs, faultLabel: au.fault === 'L0' ? 'none' : `${au.fault} ${CLASS_INFO[au.fault].name}`, inputLabel: au.inputLabel || '' };
}
const auditorHandlers = {
  setSystem(key) { au.key = key; au.flipBranch = null; au.lastCertified = null; au.tol = SYS[key].tol; tickLoop(); },
  setFault(f) { au.fault = f; au.flipBranch = null; pushTicker(Date.now(), `<b>Fault injected</b> ${f === 'L0' ? 'cleared' : f + ' · ' + CLASS_INFO[f].name}`); tickLoop(); },
  setUntouched(v) { au.untouched = v; tickLoop(); },
  reprocess() {
    if (au.fault !== 'CM2') { toast('Runtime topology already matches the pinned model.'); return; }
    au.fault = 'L0'; au.flipBranch = null; au.runtimeHash = SYS[au.key].pinnedTopoHash;
    toast('Topology reprocessed from primary breaker status: runtime hash matches the pin. Normal delivery resumes.');
    pushTicker(Date.now(), '<b>Operator</b> topology reprocessed · runtime hash = pinned hash'); tickLoop();
  },
  async tamperTest() {
    const r = await ask(monitorW, { type: 'verify', key: au.key, tamper: true, scope: 'critical' });
    toast(r.report.ok ? 'Unexpected: tampered certificate passed.' : `Tampered certificate refused: ${r.report.refused || 'checks failed'}. The pinned original stays in force.`);
  },
  exportLedger() {
    const blob = new Blob([au.ledger.map((e) => JSON.stringify(e)).join('\n') + '\n'], { type: 'application/x-ndjson' });
    const a = Object.assign(document.createElement('a'), { href: URL.createObjectURL(blob), download: `grid-auditor-ledger-${new Date().toISOString().slice(0, 19).replace(/:/g, '')}.ndjson` }); a.click();
  },
  async runAcceptance({ n14, n118, seed }) {
    const root = $('#view-auditor'); const prog = root.querySelector('#acc-prog'), stat = root.querySelector('#acc-status'), btn = root.querySelector('#acc-run');
    btn.disabled = true; au.runs = {};
    const plan = [['ieee14', n14], ['ieee118', n118]], total = plan.reduce((a, [, n]) => a + n * 5, 0); let base = 0;
    for (const [key, n] of plan) {
      const t0 = performance.now();
      const r = await ask(benchW, { type: 'acceptance', key, trials: n, seed, onProgress: (m) => { prog.style.width = ((base + m.done) / total * 100).toFixed(1) + '%'; stat.textContent = `${SYS[key].label}: ${m.done}/${m.total} trials · ${((performance.now() - t0) / 1000).toFixed(1)} s`; au.runs[key] = { table: m.table, trials: n, seed, tol: SYS[key].tol }; PG.renderAcceptance(root, au.runs, reference); } });
      au.runs[key] = { table: r.table, trials: n, seed, tol: SYS[key].tol, decisionsSha256: r.decisionsSha256 };
      base += n * 5; PG.renderAcceptance(root, au.runs, reference);
    }
    stat.textContent = `Done. ${total.toLocaleString()} trials.`; btn.disabled = false;
  },
};
function ensureAuditorPage() { const r = $('#view-auditor'); if (!r.firstChild) { PG.buildAuditor(r, auditorHandlers); PG.renderAcceptance(r, referenceRuns(), reference); } }
function referenceRuns() {
  if (!reference) return {};
  const out = {}; for (const [k, v] of Object.entries(reference.systems)) out[k] = { table: v.classes, trials: v.trials_per_class, seed: v.seed, tol: v.tolerance_float, decisionsSha256: null, ref: true };
  return out;
}
function ensureFormalismPage() { const r = $('#view-formalism'); if (!r.firstChild) PG.buildFormalism(r, { verifyAll: async (key) => { toast('Recomputing every inertia count over ℚ…'); const rep = (await ask(benchW, { type: 'verify', key, scope: 'all' })).report; fx.reports[key] = rep; PG.updateFormalism(r, fx); toast(rep.ok ? `All ${rep.totalCounts} counts exact.` : 'A check failed.'); } }); }
function ensureSourcesPage() { const r = $('#view-sources'); if (!r.firstChild) PG.buildSources(r, pageHandlers); }

// ----------------------------------------------------------------- boot
function dismissBoot() { const b = document.getElementById('boot'); if (!b || b.classList.contains('gone')) return; b.classList.add('gone'); setTimeout(() => b.remove(), 900); }
setTimeout(dismissBoot, 5000);
buildLayerRail();
SRC.SOURCES.forEach((s) => { if (!s.onDemand && !st.status[s.id]) st.status[s.id] = { state: 'idle' }; });
P.renderDemand($('#p-demand'), st); P.renderMix($('#p-mix'), st); P.renderIso($('#p-iso'), st); P.renderSpace($('#p-space'), st); P.renderHazard($('#p-hazard'), st, null); P.renderAuditorMini($('#p-auditor-mini'), null);
P.renderFrequency($('#p-freq'), st, enf); renderOutagePanel(); renderAlertsPanel(); renderWaterPanel();
showTab(location.hash.slice(1) || 'map');
bootMap();
bootGps();
bootMonitor().catch((e) => { console.error(e); toast('Auditor failed to start: ' + e.message); });
every(60, () => pollSpace().catch(() => {}));
every(900, () => pollAurora());
every(120, () => pollNws());
every(120, () => pollQuakes());
every(600, () => pollFires());
every(600, () => pollEia());
every(300, () => pollRelay());
every(10, () => pollErcot());
every(60, () => pollOutages());
every(600, () => pollRivers());
if ('serviceWorker' in navigator && location.protocol === 'https:') navigator.serviceWorker.register('sw.js').catch(() => {});
loadEmpower();
if (alerts.plat.push) {
  AL.serviceInfo().then((k) => { alerts.key = k.publicKey; alerts.lastSweep = k.lastSweep; renderAlertsPanel(); }).catch(() => {});
  if (alerts.prefs.on && Notification.permission !== 'granted') checkPermission();
  else if (alerts.prefs.on) AL.resync(alerts.prefs).then(({ prefs, state }) => { alerts.prefs = prefs; if (state === 'lost') alertMsg('This browser dropped Grid’s alert subscription. Turn alerts on again to keep receiving them.', true); else renderAlertsPanel(); }).catch(() => {});
}
