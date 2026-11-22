// Live panels beside the map. Each value carries its evidence glyph.
import { EVIDENCE, gScale } from '../live/sources.js';
import { FUEL } from '../map/map.js';
import { sparkline, demandChart, kpBars } from './charts.js';

export const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
export const ev = (k, extra = '') => `<span class="ev ev-${k}" title="${esc(EVIDENCE[k]?.label || k)}: ${esc(EVIDENCE[k]?.note || '')}">${EVIDENCE[k]?.glyph || '?'} ${esc(EVIDENCE[k]?.label || k)}${extra ? ' · ' + esc(extra) : ''}</span>`;
export function ago(t) {
  if (!t) return '—';
  const s = Math.max(0, (Date.now() - (t instanceof Date ? t.getTime() : Date.parse(t))) / 1000);
  if (s < 90) return `${Math.round(s)} s ago`; if (s < 5400) return `${Math.round(s / 60)} min ago`; if (s < 172800) return `${(s / 3600).toFixed(1)} h ago`; return `${Math.round(s / 86400)} d ago`;
}
const fmt = (v, d = 1) => (Number.isFinite(v) ? v.toLocaleString(undefined, { maximumFractionDigits: d, minimumFractionDigits: d }) : '—');
const eiaTime = (p) => (p ? new Date(p + ':00:00Z') : null);

export function renderDemand(el, st) {
  const eia = st.eia?.data || (st.relay?.data?.eia ? st.relay.data.eia : null);
  const via = st.eia?.data ? 'LIVE' : st.relay?.data?.eia ? 'RELAY' : null;
  if (eia && eia.series && eia.series.D && eia.series.D.length) {
    const D = eia.series.D.filter((p) => Number.isFinite(p.v)), DF = (eia.series.DF || []).filter((p) => Number.isFinite(p.v));
    const last = D.at(-1), f = DF.find((p) => p.t === last.t);
    const dlt = f ? ((last.v - f.v) / f.v) * 100 : null;
    el.innerHTML = `<div class="sub"><span>Lower 48 demand</span>${ev(via, 'EIA-930')}</div>
      <div class="row"><div class="big">${fmt(last.v / 1000, 1)}<small>GW</small></div>
      <div class="kv"><span>Hour ending</span><b>${eiaTime(last.t)?.toISOString().slice(11, 16)}Z</b><span>vs forecast</span><b>${dlt === null ? '—' : (dlt >= 0 ? '+' : '') + dlt.toFixed(1) + '%'}</b><span>48 h peak</span><b>${fmt(Math.max(...D.map((p) => p.v)) / 1000, 0)} GW</b></div></div>
      <canvas class="chart" id="c-demand"></canvas>
      <div class="legend"><span><i style="background:#c1e8ce"></i>demand</span><span><i style="background:#bc9c6c"></i>day-ahead forecast</span><span>${ago(eiaTime(last.t))}</span></div>`;
    demandChart(el.querySelector('#c-demand'), D.slice(-48), DF.slice(-60));
    return;
  }
  const isos = st.relay?.data?.isos;
  const live = isos ? Object.values(isos).filter((d) => Number.isFinite(d.load_mw)) : [];
  if (live.length) {
    const sum = live.reduce((a, d) => a + d.load_mw, 0);
    el.innerHTML = `<div class="sub"><span>Load in reporting ISOs/RTOs</span>${ev('RELAY', `${live.length} of 7`)}</div>
      <div class="row"><div class="big">${fmt(sum / 1000, 1)}<small>GW</small></div><div class="kv"><span>Snapshot</span><b>${ago(st.relay.data.generated_utc)}</b></div></div>
      <p class="note">Sum of the operators’ own latest load values; organised markets serve about two-thirds of U.S. load. Add a free EIA key in Sources for the full Lower-48 balance.</p>`;
    return;
  }
  el.innerHTML = `<div class="sub"><span>Lower 48 demand</span>${ev('LIVE', 'EIA-930')}</div>
    <h2>Waiting for a national feed</h2>
    <p class="note">${st.eia?.error ? `EIA: ${esc(st.eia.error)}. ` : ''}${st.relay?.error ? `Relay: ${esc(st.relay.error)}. ` : ''}The EIA-930 hourly balance needs a free API key (<a href="https://www.eia.gov/opendata/register.php" target="_blank" rel="noopener">register</a>, then paste it in <button class="link-btn" data-tab="sources">Sources</button>). The ISO relay starts publishing once its workflow runs.</p>`;
}

const ISO_FUEL = [[/solar/i, 'SUN'], [/wind/i, 'WND'], [/nuclear/i, 'NUC'], [/coal/i, 'COL'], [/gas|ng\b|natural/i, 'NG'], [/hydro|water/i, 'WAT'], [/batter|storage|esr/i, 'BAT'], [/oil|petrol|diesel|dual/i, 'OIL'], [/geo/i, 'GEO'], [/bio|wood|refuse|waste|landfill/i, 'BIO'], [/import/i, 'IMP']];
export function isoFuelCode(name) { for (const [re, c] of ISO_FUEL) if (re.test(name)) return c; return 'OTH'; }

export function renderMix(el, st) {
  const eia = st.eia?.data || st.relay?.data?.eia;
  const via = st.eia?.data ? 'LIVE' : st.relay?.data?.eia ? 'RELAY' : null;
  let parts = null, label = '', when = '';
  if (eia && eia.fuel) {
    parts = Object.entries(eia.fuel).filter(([, v]) => Number.isFinite(v) && v > 0).map(([k, v]) => ({ k, v }));
    label = 'Lower 48 generation by source'; when = eia.fuelHour ? `hour ending ${eia.fuelHour.slice(11)}:00Z` : '';
  } else if (st.relay?.data?.isos) {
    const agg = {};
    for (const d of Object.values(st.relay.data.isos)) for (const [k, v] of Object.entries(d.fuel_mix || {})) { const c = isoFuelCode(k); if (c === 'IMP' || !(v > 0)) continue; agg[c] = (agg[c] || 0) + v; }
    parts = Object.entries(agg).map(([k, v]) => ({ k, v })); label = 'ISO/RTO generation by source'; when = ago(st.relay.data.generated_utc);
  }
  if (!parts || !parts.length) { el.innerHTML = `<div class="sub"><span>Generation mix</span></div><p class="note">Appears with the EIA-930 or relay feed.</p>`; return; }
  parts.sort((a, b) => b.v - a.v);
  const tot = parts.reduce((a, p) => a + p.v, 0);
  const col = (k) => (FUEL[k] || { color: '#7f8b90' }).color, lab = (k) => (FUEL[k] || { label: k }).label;
  const clean = parts.filter((p) => ['SUN', 'WND', 'WAT', 'NUC', 'GEO', 'SNB', 'WNB'].includes(p.k)).reduce((a, p) => a + p.v, 0);
  el.innerHTML = `<div class="sub"><span>${label}</span>${ev(via || 'RELAY', when)}</div>
    <div class="row"><h2>${fmt(tot / 1000, 1)} GW</h2><span class="mono" style="color:var(--mint);font-size:12px">${((clean / tot) * 100).toFixed(0)}% carbon-free</span></div>
    <div class="mix">${parts.map((p) => `<i title="${esc(lab(p.k))} ${fmt(p.v / 1000, 1)} GW" style="flex:${p.v};background:${col(p.k)}"></i>`).join('')}</div>
    <div class="legend">${parts.slice(0, 8).map((p) => `<span><i style="background:${col(p.k)}"></i>${esc(lab(p.k))} ${((p.v / tot) * 100).toFixed(0)}%</span>`).join('')}</div>`;
}

export function renderIso(el, st) {
  const isos = st.relay?.data?.isos;
  if (!isos) {
    el.innerHTML = `<div class="sub"><span>ISO / RTO operators</span>${ev('RELAY')}</div><p class="note">${st.relay?.error ? 'Relay not reachable yet: ' + esc(st.relay.error) + '. ' : ''}The relay runs every 10 minutes on GitHub Actions and reads CAISO, ERCOT, ISO-NE, MISO, NYISO, SPP (and PJM with a key) through their public endpoints.</p>`;
    return;
  }
  const order = ['ERCOT', 'CAISO', 'MISO', 'PJM', 'SPP', 'NYISO', 'ISONE'];
  el.innerHTML = `<div class="sub"><span>ISO / RTO operators</span>${ev('RELAY', ago(st.relay.data.generated_utc))}</div>
    <div class="iso-grid">${order.filter((k) => isos[k]).map((k) => {
      const d = isos[k];
      const mix = Object.entries(d.fuel_mix || {}).filter(([, v]) => v > 0);
      const tot = mix.reduce((a, [, v]) => a + v, 0);
      const ren = mix.filter(([n]) => /solar|wind|hydro|nuclear|geo/i.test(n)).reduce((a, [, v]) => a + v, 0);
      return `<div class="iso"><div class="nm"><span>${k}</span><span>${d.status ? esc(d.status) : (tot ? Math.round((ren / tot) * 100) + '% cf' : '')}</span></div>
        ${Number.isFinite(d.load_mw) ? `<div class="ld">${fmt(d.load_mw / 1000, 1)}<small> GW · ${ago(d.time)}</small></div>` : `<div class="err">${esc(d.skipped || Object.values(d.errors || {})[0] || 'no data')}</div>`}
        ${(d.history || []).length > 2 ? `<canvas data-iso="${k}"></canvas>` : ''}
        ${tot ? `<div class="mixbar">${mix.sort((a, b) => b[1] - a[1]).map(([n, v]) => `<i title="${esc(n)} ${fmt(v, 0)} MW" style="flex:${v};background:${(FUEL[isoFuelCode(n)] || { color: '#7f8b90' }).color}"></i>`).join('')}</div>` : ''}</div>`;
    }).join('')}</div>`;
  el.querySelectorAll('canvas[data-iso]').forEach((c) => sparkline(c, isos[c.dataset.iso].history.map((p) => p[1]), { h: 22 }));
}

export function renderSpace(el, st) {
  const sw = st.space?.data;
  if (!sw) { el.innerHTML = `<div class="sub"><span>Space weather</span>${ev('LIVE', 'NOAA SWPC')}</div><p class="note">${st.space?.error ? esc(st.space.error) : 'Loading…'}</p>`; return; }
  const now = sw.kp1m.at(-1), kp = now ? now.kp : sw.kp3h.at(-1)?.kp;
  const G = sw.scales ? sw.scales.G.scale : gScale(kp ?? 0);
  const alert = sw.alerts.find((a) => a.geomagnetic);
  const cells = Array.from({ length: 9 }, (_, i) => `<i style="background:${i < Math.round(kp || 0) ? (i >= 6 ? 'var(--hot)' : i >= 4 ? 'var(--amber)' : 'var(--cyan)') : 'var(--line-soft)'}"></i>`).join('');
  el.innerHTML = `<div class="sub"><span>Geomagnetic conditions</span>${ev('LIVE', now ? ago(now.t) : 'NOAA SWPC')}</div>
    <div class="row"><div class="big">${Number.isFinite(kp) ? kp.toFixed(2) : '—'}<small>Kp</small></div><div class="kv"><span>NOAA scale</span><b>G${G}${sw.scales ? ' · ' + esc(sw.scales.G.text) : ''}</b><span>Radio / solar</span><b>${sw.scales ? `R${sw.scales.R.scale} · S${sw.scales.S.scale}` : '—'}</b></div></div>
    <div class="kpgauge">${cells}</div><canvas class="chart" id="c-kp"></canvas>
    ${alert ? `<p class="note">${esc(alert.title)} · ${ago(alert.issued)}</p>` : '<p class="note">No geomagnetic alert in the current SWPC list.</p>'}
    ${Object.keys(sw.errors || {}).length ? `<p class="note">Partial: ${esc(Object.entries(sw.errors).map(([k, v]) => k + ' ' + v).join('; '))}</p>` : ''}`;
  kpBars(el.querySelector('#c-kp'), sw.kp3h);
}

export function renderHazard(el, st, exposure) {
  if (!exposure) { el.innerHTML = `<div class="sub"><span>Hazards over the grid</span>${ev('MODEL')}</div><p class="note">Waiting for live hazard feeds…</p>`; return; }
  const { nws, fires, quakes, aurora, totals } = exposure;
  const row = (sw, name, val, act) => `<li><span class="sw2" style="background:${sw}"></span>${act ? `<button class="link" data-fly="${act}">${esc(name)}</button>` : `<span>${esc(name)}</span>`}<span class="v">${val}</span></li>`;
  el.innerHTML = `<div class="sub"><span>Generation under live hazards</span>${ev('MODEL', 'plants × live feeds')}</div>
    <div class="row"><div class="big">${fmt(totals.mw / 1000, 1)}<small>GW exposed</small></div><div class="kv"><span>Plants</span><b>${totals.plants.toLocaleString()}</b><span>Alerts w/ area</span><b>${nws.polys}</b></div></div>
    <ul class="list">
      ${nws.byEvent.slice(0, 5).map((e) => row(e.color, e.event, `${fmt(e.mw / 1000, 1)} GW`, e.center ? e.center.join(',') : '')).join('')}
      ${fires.near.slice(0, 3).map((f) => row('#ff6b3d', `${f.name} fire · ${fmt(f.acres, 0)} ac`, `${fmt(f.mw, 0)} MW ≤25 km`, f.lonlat.join(','))).join('')}
      ${quakes.near.slice(0, 2).map((q) => row('#ff9bd2', `M${q.mag.toFixed(1)} ${q.place}`, `${fmt(q.mw, 0)} MW near`, q.lonlat.join(','))).join('')}
      ${aurora.mw > 0 ? row('#5affaa', 'Under auroral oval (OVATION ≥10%)', `${fmt(aurora.mw / 1000, 1)} GW`, '') : ''}
    </ul>
    <p class="note">Plants inside NWS severe/extreme warning polygons, within 25 km of active wildfires (≥100 ac), within the felt radius of M4+ quakes, or under NOAA’s aurora forecast. Nameplate MW, not output.</p>`;
}

export function renderAuditorMini(el, au) {
  if (!au || !au.outcome) { el.innerHTML = `<div class="sub"><span>Certified spectral monitor</span>${ev('CERT')}</div><p class="note">Verifying pinned certificates…</p>`; return; }
  const o = au.outcome, d = o.auditor === 'deliver' ? 'deliver' : o.auditor === 'refuse' ? 'refuse' : 'select';
  const verdict = d === 'deliver' ? 'DELIVER CERTIFIED' : d === 'refuse' ? 'REFUSE · last certified state held' : `SELECT CERTIFIED · ${o.auditor.slice(7)}`;
  const max = Math.max(au.tol * 3, ...o.dev.filter(Number.isFinite).map((x) => Math.min(x, au.tol * 3)));
  el.innerHTML = `<div class="sub"><span>Certified spectral monitor · ${esc(au.label)}</span>${ev('CERT')}</div>
    <div class="decision" data-d="${d}">${verdict}</div>
    <div class="bars">${o.dev.map((x, i) => `<div class="b"><span>R${i + 1}</span><span class="track"><span class="fill ${x > au.tol ? 'bad' : ''}" style="width:${Math.min(100, (Math.min(x, max) / max) * 100)}%"></span><span class="tau" style="left:${(au.tol / max) * 100}%"></span></span><span>${x.toExponential(1)}</span></div>`).join('')}</div>
    <p class="note">τ = s(ε₀) + ρ = ${au.tol.toFixed(5)} · input ${esc(au.inputLabel)} · fault: ${esc(au.faultLabel)} · <button class="link-btn" data-tab="auditor">open auditor</button></p>`;
}

export function renderLocal(el, st, local) {
  const g = st.gps;
  if (!g || g.source !== 'device') {
    el.innerHTML = `<div class="sub"><span>Around you</span>${ev('LIVE', 'GPS on device')}</div><p class="note">${g && g.error ? esc(g.error) + '. ' : ''}Allow location to see the lines, substations and plants near you, and any warnings over your position. The position never leaves this device except as the bounding box of an OpenStreetMap query.</p><button class="btn small" id="btn-locate-2">◎ Use my location</button>`;
    return;
  }
  el.innerHTML = `<div class="sub"><span>Around you</span>${ev('LIVE', `±${Math.round(g.accuracy_m || 0)} m`)}</div>
    <div class="kv"><span>Position</span><b>${g.lat.toFixed(4)}°, ${g.lon.toFixed(4)}°</b>
    ${local?.plant ? `<span>Nearest plant</span><b>${esc(local.plant.name)} · ${fmt(local.plant.mw, 0)} MW ${esc((FUEL[local.plant.fuel] || {}).label || '')} · ${local.plant.km.toFixed(1)} km</b>` : ''}
    ${local?.osm ? `<span>OSM within 12 km</span><b>${local.osm.lines} lines · ${local.osm.subs} substations · ${local.osm.towers} towers</b>` : `<span>OSM</span><b>${local?.osmStatus || 'not loaded'}</b>`}
    ${local?.maxKv ? `<span>Highest voltage</span><b>${local.maxKv} kV</b>` : ''}
    <span>Warnings here</span><b>${local?.alerts?.length ? esc(local.alerts.map((a) => a.event).join(', ')) : 'none in force'}</b></div>
    <div class="rail-actions" style="grid-template-columns:1fr 1fr"><button class="btn small" id="btn-osm">↻ Local grid</button><button class="btn small accent" data-act="fly-here">✈ Fly from here</button></div>`;
}
