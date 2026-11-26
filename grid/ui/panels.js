// Live panels beside the map. Each value carries its evidence glyph.
import { EVIDENCE, gScale } from '../live/sources.js';
import { FUEL } from '../map/map.js';
import { sparkline, demandChart, kpBars } from './charts.js';
import { THRESHOLDS, PLAN, MAX_PLACES } from '../live/alerts.js';
import { detect as detectDisturbance } from '../engine/disturbance.js';
import { tally as massTally, scaleMass } from '../engine/massenergy.js';
import * as W from '../live/water.js';

export const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
export const ev = (k, extra = '') => `<span class="ev ev-${k}" title="${esc(EVIDENCE[k]?.label || k)}: ${esc(EVIDENCE[k]?.note || '')}">${EVIDENCE[k]?.glyph || '?'} ${esc(EVIDENCE[k]?.label || k)}${extra ? ' · ' + esc(extra) : ''}</span>`;
export function ago(t) {
  if (!t) return '—';
  const s = Math.max(0, (Date.now() - (t instanceof Date ? t.getTime() : Date.parse(t))) / 1000);
  if (s < 90) return `${Math.round(s)} s ago`; if (s < 5400) return `${Math.round(s / 60)} min ago`; if (s < 172800) return `${(s / 3600).toFixed(1)} h ago`; return `${Math.round(s / 86400)} d ago`;
}
const fmt = (v, d = 1) => (Number.isFinite(v) ? v.toLocaleString(undefined, { maximumFractionDigits: d, minimumFractionDigits: d }) : '—');
const eiaTime = (p) => (p ? new Date(p + ':00:00Z') : null);

// E = mc², read backwards, on the numbers already on this page.
//
// Two quantities, kept apart on purpose. STORED is the kinetic energy turning
// in the synchronous machines right now, which ERCOT publishes as inertia in
// MW·s; divided by c² it is a mass. FLOWING is demand, which is power, so
// divided by c² it is a mass *rate* — kilograms per second, not a weight, and
// not sitting anywhere.
//
// The grid does not get heavier. Electricity passes through and leaves as
// heat; nothing accumulates in the wires. Rest mass genuinely is converted,
// but at the generator — burning fuel leaves the fuel lighter — and that is
// upstream of everything Grid can see.
export function massEnergyHtml(st) {
  const inertiaMwS = st.ercot?.data?.inertia;
  const ercotMw = st.ercot?.data?.demand;
  const eia = st.eia?.data || st.relay?.data?.eia || null;
  const usRow = eia?.series?.D?.filter?.((p) => Number.isFinite(p.v))?.at?.(-1) || null;
  const usMw = usRow ? usRow.v : null;
  if (!Number.isFinite(inertiaMwS) && !Number.isFinite(usMw) && !Number.isFinite(ercotMw)) return '';

  const tx = massTally({ inertiaMwS, loadMw: ercotMw });
  const us = massTally({ loadMw: usMw });
  const show = (kg, digits = 3) => { const s = scaleMass(kg); return s ? `${fmt(s.value, digits)} ${s.unit}` : '—'; };
  const head = `<div class="eyebrow">Mass-energy in the grid ${ev('MODEL', 'E = mc²')}</div>`;

  const stored = Number.isFinite(tx.storedKg)
    ? `<div class="row"><div class="big">${fmt(tx.storedKg * 1e6, 3)}<small>mg</small></div>
         <div class="kv"><span>Stored as</span><b>kinetic energy</b><span>Where</span><b>spinning machines</b><span>From</span><b>${fmt(inertiaMwS / 1000, 0)} GW·s</b></div></div>
       <p class="note">The energy turning in the Texas Interconnection's synchronous generators at this moment, divided by c². This is a mass, not a rate — it is the only figure here that is actually <em>in</em> the grid.</p>`
    : `<p class="note">ERCOT is not publishing inertia with this reading, so there is no stored figure. The flow rate below does not substitute for it: it is a different quantity in different units.</p>`;

  const rows = [];
  if (Number.isFinite(tx.flowKgPerSec)) rows.push(['Texas', tx]);
  if (Number.isFinite(us.flowKgPerSec)) rows.push(['Lower 48', us]);
  const flow = rows.length
    ? `<div class="eyebrow">Flowing · a rate, not a weight</div>
       <table class="t"><thead><tr><th></th><th>per second</th><th>per hour</th><th>per year</th></tr></thead><tbody>
         ${rows.map(([name, t]) => `<tr><td>${esc(name)}</td><td>${show(t.flowKgPerSec)}</td><td>${show(t.perHourKg)}</td><td>${show(t.perYearKg)}</td></tr>`).join('')}
       </tbody></table>`
    : '';

  // Where the mass framing earns itself: stored ÷ flowing has units of time,
  // and the number it lands on is the inertia constant H/S that power
  // engineers already use. c² cancels, so this is a standard quantity arrived
  // at from the other direction — and it is the ride-through the machines give
  // before frequency has to move.
  const ride = Number.isFinite(tx.storedAsSecondsOfFlow)
    ? `<p class="note"><b>${fmt(tx.storedAsSecondsOfFlow, 2)} s.</b> Stored divided by flowing has units of time, and the number is the inertia constant H/S — c² cancels out of the ratio, so this is the quantity power engineers already use, reached from the other side. It is roughly how long the spinning machines can carry Texas before frequency has to move. Wind and solar are inverter-based and add no synchronous inertia, so as their share rises this figure falls, and the same megawatt loss then falls faster — which is what the disturbance reading in the frequency panel measures.</p>`
    : '';

  return `${head}${stored}${flow}${ride}
    <p class="note">The grid does not weigh this much more. Electricity passes through and leaves as heat; nothing accumulates in the wires. Rest mass is genuinely converted, but at the generator, where burning fuel leaves the fuel lighter — upstream of anything Grid can see. Inertia covers rotating machines only: field energy in lines, transformers and reactors is also stored, also real, and published by nobody, so the stored figure is a floor.</p>`;
}

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
      <div class="legend"><span><i style="background:#c1e8ce"></i>demand</span><span><i style="background:#bc9c6c"></i>day-ahead forecast</span><span>${ago(eiaTime(last.t))}</span></div>
      ${massEnergyHtml(st)}`;
    demandChart(el.querySelector('#c-demand'), D.slice(-48), DF.slice(-60));
    return;
  }
  const isos = st.relay?.data?.isos;
  const live = isos ? Object.values(isos).filter((d) => Number.isFinite(d.load_mw)) : [];
  if (live.length) {
    const sum = live.reduce((a, d) => a + d.load_mw, 0);
    el.innerHTML = `<div class="sub"><span>Load in reporting ISOs/RTOs</span>${ev('RELAY', `${live.length} of 7`)}</div>
      <div class="row"><div class="big">${fmt(sum / 1000, 1)}<small>GW</small></div><div class="kv"><span>Snapshot</span><b>${ago(st.relay.data.generated_utc)}</b></div></div>
      <p class="note">Sum of the operators’ own latest load values; organised markets serve about two-thirds of U.S. load. Add a free EIA key in Sources for the full Lower-48 balance.</p>
      ${massEnergyHtml(st)}`;
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

// The body redraws with every GPS fix; the alerts button below it is a separate element that only changes when
// its own label does, so a tap on it is never lost to a redraw. al: { on, n }
export function renderLocal(el, st, local, al) {
  let body = el.querySelector(':scope > .local-body'), cta = el.querySelector(':scope > .local-alert');
  if (!body || !cta) { el.innerHTML = '<div class="local-body"></div><div class="local-alert"></div>'; body = el.firstChild; cta = el.lastChild; }
  const c = local?.county, bell = '<span class="bell" aria-hidden="true">🔔</span>';
  const html = !al ? '' : al.on
    ? `<button class="btn alert-cta on" id="btn-alert-here">${bell}<span>Alerts on for ${al.n} ${al.n === 1 ? 'county' : 'counties'}<small>Manage, or send a test</small></span></button>`
    : `<button class="btn alert-cta" id="btn-alert-here">${bell}<span>${c ? `Alert me about outages in ${esc(c.properties.label)}` : 'Get outage alerts on this phone'}<small>Power out, power back, severe weather · even with Grid closed</small></span></button>`;
  if (cta._html !== html) { cta.innerHTML = html; cta._html = html; }
  const g = st.gps;
  if (!g || g.source !== 'device') {
    body.innerHTML = `<div class="sub"><span>Around you</span>${ev('LIVE', 'GPS on device')}</div><p class="note">${g && g.error ? esc(g.error) + '. ' : ''}Allow location to see the lines, substations and plants near you, and any warnings over your position. The position never leaves this device except as the bounding box of an OpenStreetMap query.</p><button class="btn small" id="btn-locate-2">◎ Use my location</button>`;
    return;
  }
  body.innerHTML = `<div class="sub"><span>Around you</span>${ev('LIVE', `±${Math.round(g.accuracy_m || 0)} m`)}</div>
    <div class="kv"><span>Position</span><b>${g.lat.toFixed(4)}°, ${g.lon.toFixed(4)}°</b>
    ${local?.plant ? `<span>Nearest plant</span><b>${esc(local.plant.name)} · ${fmt(local.plant.mw, 0)} MW ${esc((FUEL[local.plant.fuel] || {}).label || '')} · ${local.plant.km.toFixed(1)} km</b>` : ''}
    ${local?.osm ? `<span>OSM within 12 km</span><b>${local.osm.lines} lines · ${local.osm.subs} substations · ${local.osm.towers} towers</b>` : `<span>OSM</span><b>${local?.osmStatus || 'not loaded'}</b>`}
    ${local?.maxKv ? `<span>Highest voltage</span><b>${local.maxKv} kV</b>` : ''}
    <span>Warnings here</span><b>${local?.alerts?.length ? esc(local.alerts.map((a) => a.event).join(', ')) : 'none in force'}</b></div>
    <div class="rail-actions" style="grid-template-columns:1fr 1fr"><button class="btn small" id="btn-osm">↻ Local grid</button><button class="btn small accent" data-act="fly-here">✈ Fly from here</button></div>`;
}

// ------------------------------------------------------------------ frequency, outages, at-a-glance
const titleCase = (s) => String(s || '').toLowerCase().replace(/\b([a-z])/g, (m) => m.toUpperCase()).replace(/(?!^)\b(Of|And|The|De)\b/g, (m) => m.toLowerCase()).replace(/\bCo\b/g, 'Co.').replace(/\bInc\b/g, 'Inc.').replace(/\bAssn\b/g, 'Assn.').replace(/\bLlc\b/g, 'LLC');
// ODIN sends most names in capitals; names already in mixed case ("NV Energy") are left as written.
export const utilName = (s) => (/[a-z]/.test(String(s || '')) ? String(s) : titleCase(s));
const hhmm = (t) => { const d = new Date(t); return Number.isFinite(d.getTime()) ? d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '—'; };
const compact = (n) => (n >= 1e6 ? (n / 1e6).toFixed(1) + 'M' : n >= 1e4 ? Math.round(n / 1e3) + 'k' : n >= 1e3 ? (n / 1e3).toFixed(1) + 'k' : String(n));
export function freqBand(f) {
  const dev = (f - 60) * 1000, a = Math.abs(dev);
  return a <= 30 ? { cls: 'ok', text: 'inside the normal band (±30 mHz)' } : a <= 90 ? { cls: 'warn', text: 'outside normal, inside the ACE limit (±90 mHz)' } : { cls: 'bad', text: 'beyond ±90 mHz: a disturbance' };
}

export function renderFrequency(el, st, enf) {
  const d = st.ercot?.data, hist = st.ercot?.hist || [];
  const head = `<div class="sub"><span>Grid frequency · Texas</span>${ev('RELAY', 'ERCOT')}</div>`;
  if (!d) {
    el.innerHTML = `${head}<h2>${st.ercot?.error ? 'ERCOT feed unavailable' : 'Reading ERCOT…'}</h2>${st.ercot?.error ? `<p class="note">${esc(st.ercot.error)}</p>` : ''}<div class="enf" id="enf-box">${enfHtml(enf)}</div>`;
    return;
  }
  const dev = (d.frequency - 60) * 1000, band = freqBand(d.frequency), pos = Math.max(-100, Math.min(100, dev));
  el.innerHTML = `${head}
    <div class="row"><div class="big">${d.frequency.toFixed(3)}<small>Hz</small></div>
      <div class="kv"><span>Deviation</span><b class="f-${band.cls}">${dev >= 0 ? '+' : '−'}${Math.abs(dev).toFixed(0)} mHz</b><span>Time error</span><b>${fmt(d.timeError, 2)} s</b><span>Inertia</span><b>${Number.isFinite(d.inertia) ? fmt(d.inertia / 1000, 0) + ' GW·s' : '—'}</b></div></div>
    <div class="fgauge" role="img" aria-label="Deviation ${dev.toFixed(0)} millihertz from 60 hertz"><i class="b90"></i><i class="b30"></i><i class="mid"></i><b class="f-${band.cls}" style="left:${50 + pos / 2}%"></b></div>
    <div class="fscale mono"><span>−100</span><span>60.000 Hz</span><span>+100 mHz</span></div>
    <canvas class="chart" id="c-freq"></canvas>
    <div class="legend"><span>${esc(band.text)}</span><span>${hist.length > 1 ? `last ${Math.max(1, Math.round((hist.at(-1).t - hist[0].t) / 60000))} min · ` : ''}${ago(d.updated || d.fetched)}${d.stale ? ' · cached' : ''}</span></div>
    <div class="kv kv3"><span>Demand</span><b>${fmt(d.demand / 1000, 1)} GW</b><span>Wind</span><b>${fmt(d.wind / 1000, 1)} GW</b><span>Solar</span><b>${fmt(d.solar / 1000, 1)} GW</b></div>
    ${disturbanceHtml(st)}
    <div class="enf" id="enf-box">${enfHtml(enf)}</div>`;
  if (hist.length > 1) sparkline(el.querySelector('#c-freq'), hist.map((p) => p.f), { h: 34, color: band.cls === 'ok' ? '#c1e8ce' : band.cls === 'warn' ? '#ffd166' : '#ff5f7a' });
}

// Disturbances read out of the frequency trace itself.
//
// A generation or transmission loss leaves a step in frequency, and the trace
// Grid already holds is enough to say that something went and roughly how
// hard. It is never enough to say what went. Breaker status is utility SCADA
// under NERC CIP and is published nowhere, so this block names no line and
// says so where the reader will see it.
export function disturbanceHtml(st) {
  const hist = st.ercot?.hist || [], inertiaMwS = st.ercot?.data?.inertia;
  if (hist.length < 5) return '';
  const events = detectDisturbance(hist, { inertiaMwS });
  const mins = Math.max(1, Math.round((hist.at(-1).t - hist[0].t) / 60000));
  const head = `<div class="eyebrow">Disturbances ${ev('MODEL', 'from this trace')}</div>`;

  if (!events.length) {
    return `${head}<p class="note">No step beyond the ±34 mHz governor deadband in the last ${mins} min. A quiet trace is not proof that nothing happened: Grid samples ERCOT every 10 seconds, and a small event can arrive and be corrected between two readings.</p>`;
  }

  const e = events[events.length - 1];
  const lost = e.direction === 'loss';
  const dev = Math.abs(e.deviationHz) * 1000;
  const severe = e.severity.level === 'ufls' || e.severity.level === 'beyond-ace';
  const floor = Number.isFinite(e.mwFloor)
    ? `<br>Inertia was ${fmt(inertiaMwS / 1000, 0)} GW·s, so the swing equation puts the imbalance at <b>no less than ${Math.round(e.mwFloor).toLocaleString()} MW</b>. Read that as a floor and not an estimate: ten-second sampling averages away the steepest part of the fall, and governors are already arresting it inside the interval, so the true figure is larger — often several times larger.`
    : '<br>ERCOT did not publish inertia with this reading, so no bound on the size is stated. A number without it would be invented.';

  return `${head}
    <div class="here${severe ? ' out' : ''}" role="${severe ? 'alert' : 'note'}">
      <b>${lost ? 'Generation or load lost' : 'Load lost or generation surged'}</b> · ${hhmm(e.atMs)}<br>
      Frequency stepped ${lost ? 'down' : 'up'} ${Math.abs(e.stepHz * 1000).toFixed(0)} mHz in one ${Math.round(e.dtMs / 1000)}-second interval, ${lost ? 'reaching' : 'peaking at'} <b>${e.extremeHz.toFixed(3)} Hz</b> — ${dev.toFixed(0)} mHz from 60 Hz, ${esc(e.severity.text)}.
      ${e.severity.level === 'ufls' ? `<br><b>Automatic load shedding operates at this frequency</b> — ${esc(e.severity.stage.note)}.` : ''}
      ${floor}
    </div>
    <p class="note">Inferred from frequency alone. Grid cannot see breaker positions — those are utility SCADA, protected under NERC CIP and not published — so this says the Texas Interconnection lost or gained something, not which line, unit or substation. Where an outage follows, the counties appear in the outage panel.${events.length > 1 ? ` ${events.length} disturbances in the last ${mins} min; the most recent is shown.` : ''}</p>`;
}

// The outlet meter's block, re-rendered alone while it runs.
export function enfHtml(enf) {
  const ic = enf?.ic;
  const where = ic ? `<span class="ic">${esc(ic.name)}</span>` : '';
  if (!enf || !enf.running) {
    const lead = ic?.id === 'ercot' ? 'You are on the Texas grid, so the reading above is your frequency. Check it yourself:' : ic ? `ERCOT publishes Texas only. You are on the ${esc(ic.name)}; its frequency is in the hum of the wiring around you.` : 'ERCOT publishes Texas only. Your own grid’s frequency is in the hum of the wiring around you.';
    return `<div class="enf-head"><span class="eyebrow">Your outlet</span>${where}</div>
      <p class="note">${lead} This device’s microphone can read it to a few millihertz. The sound is analysed on the device and never leaves it.</p>
      <button class="btn accent" id="enf-start"${enf && enf.supported === false ? ' disabled title="This browser has no AudioWorklet"' : ''}>◉ Measure at your outlet</button>${enf?.error ? `<p class="note err">${esc(enf.error)}</p>` : ''}`;
  }
  return `<div class="enf-head"><span class="eyebrow">Your outlet</span>${where}<button class="btn" id="enf-stop">Stop</button></div><div id="enf-body">${enfBodyHtml(enf)}</div>`;
}

// The changing part of a running meter; the head with its Stop button stays put so taps land.
export function enfBodyHtml(enf) {
  const r = enf && enf.last;
  if (!r || !r.ready) return `<div class="enf-progress"><i style="width:${Math.round(100 * (r?.progress || 0))}%"></i></div><p class="note">Listening: collecting two seconds of sound…</p>`;
  if (!r.ok) return `<h2 class="enf-wait">No steady hum yet</h2><p class="note">Hold the device near a charger, power strip, lamp or appliance, and keep music off. Phones often filter out 60 Hz itself; its 120 and 180 Hz overtones are enough.</p>`;
  const dev = (r.f - 60) * 1000, band = freqBand(r.f);
  return `<div class="row"><div class="big enf-big">${r.f.toFixed(4)}<small>Hz</small></div><div class="kv"><span>Deviation</span><b class="f-${band.cls}">${dev >= 0 ? '+' : '−'}${Math.abs(dev).toFixed(1)} mHz</b><span>Spread</span><b>± ${(r.sd * 1000).toFixed(2)} mHz</b><span>From</span><b>${r.used.join(' · ')} Hz</b></div></div>
    <canvas class="chart" id="c-enf"></canvas>
    <p class="note">${ev('LIVE', 'this device')} Changes are exact to the spread shown; the absolute value also carries your device clock’s offset, typically under ±3 mHz.</p>`;
}

// CDC and CPSC guidance, shown wherever an outage touches the person reading.
export const CO_HTML = `<div class="co" role="note"><b>Generators and carbon monoxide</b><span>Run a generator outdoors only, at least 20 feet from doors, windows and vents: never in a home, garage, basement or carport, even with the doors open. Keep battery-powered CO alarms on. If one sounds, or anyone has a headache, dizziness, weakness, nausea or confusion, get everyone outside and call 911.</span><small>CDC · CPSC</small></div>`;
const monthYear = (t) => { const d = new Date(t); return Number.isFinite(d.getTime()) ? d.toLocaleDateString([], { month: 'short', year: 'numeric' }) : 'this month'; };

// x: { emp(fips) → emPOWER row | null, empower: meta, home: { medical } }
export function renderOutages(el, st, names, local, x = {}) {
  const o = st.outages?.data;
  const head = `<div class="sub"><span>Customers without power</span>${ev('RELAY', 'ODIN · DOE/ORNL')}</div>`;
  if (!o) { el.innerHTML = `${head}<h2>${st.outages?.error ? 'Outage feed unavailable' : 'Reading outages…'}</h2>${st.outages?.error ? `<p class="note">${esc(st.outages.error)}</p>` : ''}`; return; }
  const nm = (f) => (names && names.get(f)) || f;
  const dep = (f) => { const r = x.emp && x.emp(f); return r && Number.isFinite(r[2]) ? r[2] : null; };
  const rows = o.counties.slice(0, 6).map((r) => { const d = dep(r[0]); return `<li><button class="outrow" data-fips="${r[0]}"><span class="n">${esc(nm(r[0]))}</span><b>${r[1].toLocaleString()}</b><small>${d ? `<span class="dep" title="Medicare beneficiaries here who rely on electricity-dependent medical equipment (HHS emPOWER)">⚕ ${d.toLocaleString()}</span> · ` : ''}${esc(utilName(r[3]))}${r[5] ? ' · since ' + hhmm(r[5]) : ''}${r[6] ? ' · back by ' + hhmm(r[6]) : ''}</small></button></li>`; }).join('');
  const mine = local?.county ? o.counties.find((r) => r[0] === local.county.id) : null;
  let here = '';
  if (mine) {
    here = `<div class="here out" role="alert"><b>Power outage in your county</b> · ${esc(nm(mine[0]))}<br>${mine[1].toLocaleString()} customers out · ${esc(utilName(mine[3]))}${mine[6] ? ` · utility estimate: back by ${hhmm(mine[6])}` : ''}
      ${x.home?.medical ? '<p class="medline">Powered medical equipment: check battery hours now, switch to backup oxygen if you use a concentrator, and leave early for the place you planned if the outage may outlast the batteries. If a device someone needs to live stops and there is no backup, call 911.</p>' : ''}${CO_HTML}</div>`;
  } else if (local?.county) {
    here = `<p class="here">Your county, <b>${esc(local.county.properties.label)}</b>: no outage reported by ODIN utilities.</p>`;
  }
  let emp = '';
  if (x.empower) {
    let sum = 0, n = 0;
    for (const r of o.counties) if (r[1] >= 1000) { const d = dep(r[0]); if (d) { sum += d; n++; } }
    emp = `<p class="emp"><span class="g" aria-hidden="true">⚕</span><span>${n ? `<b>${sum.toLocaleString()}</b> Medicare beneficiaries who rely on electricity-dependent medical equipment live in the ${n} ${n === 1 ? 'county' : 'counties'} with 1,000 or more customers out.` : 'No county has 1,000 or more customers out right now.'} <span class="src">${ev('RELAY', 'HHS emPOWER · ' + monthYear(x.empower.asOf))}</span></span></p>`;
  }
  el.innerHTML = `${head}
    <div class="row"><div class="big">${compact(o.customers)}<small>out</small></div>
      <div class="kv"><span>Counties</span><b>${o.nCounties.toLocaleString()}</b><span>Utilities</span><b>${o.nUtilities}${o.feeds ? ' / ' + o.feeds : ''}</b><span>Updated</span><b>${ago(o.fetched)}${o.stale ? ' · cached' : ''}</b></div></div>
    ${here}
    <ol class="outlist">${rows || '<li class="none">No active outages reported right now.</li>'}</ol>
    ${emp}
    <div class="legend"><button class="link-btn" id="out-fit">Show all on the map</button><button class="link-btn" id="out-alerts">${x.alertsOn ? 'Alerts are on' : 'Alert me'}</button><span>${o.events.toLocaleString()} outage events</span></div>
    <p class="note">ODIN is the Department of Energy and Oak Ridge National Laboratory’s outage-data network; ${o.feeds || 'about 160'} utility feeds report to it. Utilities outside ODIN do not appear, so an empty county is not proof that the power is on.${x.empower ? ' HHS emPOWER counts Medicare beneficiaries only, and shows ZIP Codes with 1 to 10 people as 11.' : ''}</p>`;
}

// Water: your water system and how it stands with EPA, drought where you are, rivers at flood stage, and the
// water systems in the counties where the power is out.
// D: { rivers: { data, error }, here: { fips, label, water, wErr, area: { hit, also }, aErr, aBusy, drought, dErr }, top: [{ fips, label, out, water }] }
// x: { gps, outHere: ODIN row for your county or null }
const people = (n) => (Number.isFinite(n) ? `${n >= 1e6 ? (n / 1e6).toFixed(n >= 1e7 ? 0 : 1) + ' million' : n.toLocaleString()} ${n === 1 ? 'person' : 'people'}` : 'an unreported number of people');
const miles = (km) => `${Math.max(1, Math.round(km * 0.621371))} mi`;
const shortDate = (s) => { const d = new Date(String(s || '') + 'T12:00:00Z'); return Number.isFinite(d.getTime()) ? d.toLocaleDateString([], { month: 'short', day: 'numeric' }) : '—'; };
export function renderWater(el, D, local, x = {}) {
  const g = x.gps, h = D.here, county = h?.label || local?.county?.properties?.label || null;
  // 1. You: the system that serves your position, or the county's systems when no boundary holds it.
  let you;
  if (!g || g.source !== 'device') {
    you = `<div class="wsys"><div class="wk">Your drinking water</div><p class="note">Allow location to find the water system that serves you. Grid asks EPA’s service-area map with a box about 2 km across; your exact position stays on this device.</p><button class="btn small" id="w-locate">◎ Find my water system</button></div>`;
  } else if (!h || (!h.area && !h.aErr && !h.water && !h.wErr)) {
    you = `<div class="wsys"><div class="wk">Your drinking water</div><p class="note">Finding the water system that serves your position…</p></div>`;
  } else {
    const sys = W.systems(h.water), hit = h.area?.hit || null;
    if (hit) {
      const mine = sys.find((s) => s.pwsid === hit.pwsid) || null, sd = W.standing(h.water ? mine : null), src = mine && W.sourceText(mine.source);
      const record = !h.water ? (h.wErr ? `<p class="note err">EPA’s compliance records did not load: ${esc(h.wErr)}</p>` : '<p class="note">Reading EPA’s compliance records…</p>')
        : `<p class="wstand ${sd.cls}"><i aria-hidden="true"></i><span>${esc(sd.text)}</span></p>${mine && Number.isFinite(mine.quarters) ? `<div class="wmeta">${mine.quarters === 0 ? 'No violations in the last 12 quarters' : `Violations in ${mine.quarters} of the last 12 quarters`}${mine.health ? ' · health-based violations on record' : ''}</div>` : ''}`;
      you = `<div class="wsys ${h.water ? sd.cls : ''}"><div class="wk"><span>Your water system</span>${ev('LIVE', 'EPA map')}</div><h3>${esc(W.waterName(mine?.name || hit.name))}</h3>
        <div class="wmeta">Serves ${people(mine?.pop ?? hit.pop)}${src ? ` · ${esc(src)}` : ''}</div>${record}
        <div class="wlinks"><a href="${esc(W.dfrUrl(hit.pwsid, mine))}" target="_blank" rel="noopener">EPA report ↗</a><button class="link-btn" id="w-area">Show on map</button><span>${esc(hit.pwsid)} · ${esc(W.basisText(hit))}</span></div>
        ${h.area.also.length ? `<p class="note">Also mapped at your position: ${h.area.also.slice(0, 3).map((p) => esc(W.waterName(p.name))).join(', ')}.</p>` : ''}</div>`;
    } else {
      const why = h.aBusy ? 'Checking EPA’s service-area map for your position…'
        : h.aErr ? `EPA’s service-area map did not answer (${esc(h.aErr)}), so Grid cannot tell which of these serves your exact position.`
        : h.area ? 'EPA’s service-area map has no boundary at your position. Homes on private wells, and some small systems, are not mapped.' : '';
      const list = sys.slice(0, 5).map((s) => { const sd = W.standing(s); return `<li><i class="wdot ${sd.cls}" title="${esc(sd.text)}"></i><span class="n">${esc(W.waterName(s.name))}</span><b>${s.pop != null ? s.pop.toLocaleString() : '—'}</b></li>`; }).join('');
      you = `<div class="wsys"><div class="wk"><span>Drinking water in ${esc(county || 'your county')}</span>${ev('RELAY', 'EPA ECHO')}</div>
        ${h.water ? `<h3>${h.water.nSystems ? `${h.water.nSystems.toLocaleString()} community water ${h.water.nSystems === 1 ? 'system serves' : 'systems serve'} ${people(h.water.population)}` : 'No community water system on EPA’s list'}</h3>
          ${list ? `<ol class="wlist">${list}</ol>` : ''}${h.water.nViolating ? `<div class="wmeta">${h.water.nViolating} in violation in EPA’s latest quarter${h.water.nPriority ? ` · ${h.water.nPriority} an enforcement priority` : ''}</div>` : h.water.nSystems ? '<div class="wmeta">None in violation in EPA’s latest quarter</div>' : ''}`
          : h.wErr ? `<p class="note err">EPA’s records did not load: ${esc(h.wErr)}</p>` : '<p class="note">Reading EPA’s records…</p>'}
        ${why ? `<p class="note">${why}</p>` : ''}</div>`;
    }
  }
  // 2. The power–water link where you are, and drought.
  const out = x.outHere && x.outHere[1] >= 1000 ? `<div class="here out"><b>The power is out in your county</b> · ${x.outHere[1].toLocaleString()} customers. Water systems pump and treat with electricity; if your water pressure drops, your water system may issue a boil-water notice.</div>` : '';
  const dr = h?.drought;
  const drought = dr ? `<p class="wline"><span class="g" aria-hidden="true">◐</span><span>${dr.inDrought >= 0.5 ? `<b>${dr.inDrought.toFixed(0)}%</b> of ${esc(county || 'your county')} is in drought${dr.worst && dr.worst !== 'D0' ? `, up to ${esc(W.DROUGHT[dr.worst])} (${dr.worst})` : ''}` : dr.d0 >= 0.5 ? `No drought in ${esc(county || 'your county')}; ${dr.d0.toFixed(0)}% abnormally dry` : `No drought in ${esc(county || 'your county')}`} <small>U.S. Drought Monitor · ${shortDate(dr.week)}</small></span></p>` : '';
  const boil = `<details class="boil"><summary>If a boil-water notice comes</summary>
    <p>Boil-water notices come from your water system or your state: by text or phone, on local news, or on the utility’s website. No national feed of them exists, so Grid cannot show them. Your water system’s phone number is on your water bill.</p>
    <ul><li>Bring clear water to a rolling boil for 1 minute (3 minutes above 6,500 feet), then let it cool.</li><li>Use bottled or boiled water for drinking, cooking and brushing teeth. For babies, ready-to-use formula if you can.</li><li>Boiling does not remove chemicals. If the notice says do not drink the water, use bottled water.</li></ul>
    <p class="note">From the CDC’s guidance on drinking water advisories · <a href="${W.CDC_BOIL}" target="_blank" rel="noopener">CDC ↗</a></p></details>`;
  // 3. Rivers.
  const R = D.rivers?.data;
  let rivers;
  if (!R) rivers = `<p class="note">${D.rivers?.error ? `River gauges unavailable: ${esc(D.rivers.error)}` : 'Reading river gauges…'}</p>`;
  else {
    const rows = W.rankRivers(W.riverRows(R)), c = R.counts;
    const flooding = rows.filter((r) => r.status !== 'action');
    const show = (flooding.length ? flooding : rows).slice(0, 5);
    let near = '';
    if (g && g.source === 'device') {
      const nr = W.nearRivers(R, g.lon, g.lat, 80);
      near = nr.length ? `<p class="here"><b>Near you</b> · ${nr.length} ${nr.length === 1 ? 'gauge' : 'gauges'} within 50 mi at or near flood stage. Nearest: ${esc(nr[0].name)}, <span style="color:${W.FLOOD[nr[0].status].color}">${esc(W.FLOOD[nr[0].status].label.toLowerCase())}</span>, ${miles(nr[0].km)} away.</p>`
        : `<p class="here">No river gauge within 50 mi of you is at or near flood stage.</p>`;
    }
    rivers = `<div class="row"><div class="big">${R.inFlood.toLocaleString()}<small>${R.inFlood === 1 ? 'gauge' : 'gauges'} in flood</small></div>
      <div class="kv">${['major', 'moderate', 'minor', 'action'].map((k) => `<span><i class="fk" style="background:${W.FLOOD[k].color}"></i>${W.FLOOD[k].short}</span><b>${c[k].toLocaleString()}</b>`).join('')}</div></div>
      ${near}
      <ol class="outlist rivlist">${show.map((r) => { const t = W.stageText(r); return `<li><button class="outrow rivrow" data-lon="${r.lon}" data-lat="${r.lat}"><span class="n"><i class="fk" style="background:${W.FLOOD[r.status].color}"></i>${esc(r.name || r.lid)}${r.state ? `, ${esc(r.state)}` : ''}</span><b style="color:${W.FLOOD[r.status].color}">${esc(t.now || W.FLOOD[r.status].short)}</b><small>${esc(W.FLOOD[r.status].label)}${t.ref ? ` · ${esc(t.ref)}` : ''}</small></button></li>`; }).join('') || '<li class="none">No river gauge is at or near flood stage.</li>'}</ol>
      <div class="legend">${rows.length ? '<button class="link-btn" id="riv-fit">Show all on the map</button>' : ''}<span>${R.reporting ? `${R.reporting.toLocaleString()} NOAA gauges reporting · ` : ''}${ago(R.fetched)}${R.stale ? ' · cached' : ''}</span></div>`;
  }
  // 4. Where the power is out: the water systems in those counties.
  const top = D.top || [];
  const pw = top.length ? `<ol class="outlist">${top.map((t) => `<li><button class="outrow pwrow" data-fips="${esc(t.fips)}"><span class="n">${esc(t.label)}</span><b>${t.out.toLocaleString()} out</b><small>${t.water ? (t.water.nSystems ? `${t.water.nSystems.toLocaleString()} community water ${t.water.nSystems === 1 ? 'system serves' : 'systems serve'} ${people(t.water.population)}` : 'no community water system on EPA’s list') : t.err ? 'EPA records unavailable' : 'reading EPA records…'}</small></button></li>`).join('')}</ol>
      <p class="note">Community water systems that EPA records as serving the counties with the most customers out. Water systems pump and treat with electricity; those with backup power keep running, but a long outage can drop water pressure, and a loss of pressure can lead to a boil-water notice.</p>`
    : '<p class="note">No county has 1,000 or more customers out right now.</p>';
  el.innerHTML = `<div class="sub"><span>Water</span>${ev('RELAY', 'EPA · NOAA · Drought Monitor')}</div>
    ${you}${out}${drought}${boil}
    <div class="wsec"><span>Rivers at flood stage</span>${ev('RELAY', 'NOAA NWPS')}</div>${rivers}
    <div class="wsec"><span>Where the power is out</span>${ev('RELAY', 'ODIN × EPA')}</div>${pw}
    <p class="note">EPA’s drinking-water records come from the states each quarter and can trail by three to six months; some states publish newer data on their own sites. Service areas are EPA’s national map, and some boundaries are modeled. River stages are NOAA’s, refreshed every 30 minutes. Grid is an independent public-data tool, not your water utility.</p>`;
}

// Background alerts and the medical-equipment plan. A: { plat, prefs, home, busy, msg, err, lastSweep }
export function renderAlerts(el, A, local) {
  const p = A.prefs, plat = A.plat, on = p.on, n = p.places.length, dis = A.busy ? ' disabled' : '';
  const head = `<div class="sub"><span>Background alerts</span>${ev('LIVE', 'Web Push')}</div>`;
  let body;
  if (!plat.push) {
    body = plat.ios && !plat.standalone
      ? `<div class="steps"><b>On iPhone and iPad, alerts work from the Home Screen.</b><ol><li>In Safari, tap <b>Share</b> <span class="share-glyph" aria-hidden="true">⎙</span></li><li>Choose <b>Add to Home Screen</b></li><li>Open Grid from the new icon, then turn alerts on here</li></ol><small>Needs iOS or iPadOS 16.4 or later.</small></div>`
      : `<p class="note">This browser cannot receive notifications in the background. Chrome, Edge, Firefox, Samsung Internet and Safari can.</p>`;
  } else {
    const chips = p.places.map((c) => `<span class="place">${esc(c.label)}<button class="x" data-rm="${esc(c.fips)}" aria-label="Stop watching ${esc(c.label)}"${dis}>✕</button></span>`).join('');
    const here = local?.county && !p.places.some((c) => c.fips === local.county.id) && n < MAX_PLACES
      ? `<button class="btn small" id="al-here"${dis}>◎ ${esc(local.county.properties.label)}</button>` : '';
    body = `<div class="places">${chips || '<span class="none">Choose the counties to watch: home, family, work.</span>'}${n < MAX_PLACES ? `<button class="btn small" id="al-add"${dis}>＋ Add a county</button>` : ''}${here}</div>
      <label class="field-row"><span>Outages</span><select id="al-min"${dis}>${THRESHOLDS.map(([v, l]) => `<option value="${v}"${v === p.minOut ? ' selected' : ''}>${l}</option>`).join('')}</select></label>
      <label class="toggle"><input type="checkbox" id="al-wx"${p.weather ? ' checked' : ''}${dis}><span>Severe weather warnings (National Weather Service)</span></label>
      <label class="toggle"><input type="checkbox" id="al-restore"${p.restore ? ' checked' : ''}${dis}><span>Tell me when reported outages fall or clear</span></label>
      <div class="al-actions">${on ? `<button class="btn" id="al-test"${dis}>Send a test alert</button><button class="btn danger" id="al-off"${dis}>Turn off</button>` : `<button class="btn accent" id="al-on"${dis}>${A.busy ? 'Turning on…' : 'Turn on alerts'}</button>`}</div>
      ${plat.permission === 'denied' ? '<p class="note err">Notifications are blocked for this site. Allow them in the browser or phone settings, then turn alerts on.</p>' : ''}
      <p class="note">Keep your phone’s government emergency alerts on as well. Grid adds to them; it does not replace them.</p>`;
  }
  const msg = A.msg ? `<p class="note ${A.err ? 'err' : 'okmsg'}" role="status">${esc(A.msg)}</p>` : '';
  const sweep = A.lastSweep?.at ? `<p class="note">The alert service last checked ODIN and the Weather Service ${ago(A.lastSweep.at)}.</p>` : '';
  const h = A.home;
  const plan = h.medical ? `<ol class="plan">${PLAN.map(([k, t]) => `<li><label><input type="checkbox" data-plan="${k}"${h.done?.[k] ? ' checked' : ''}><span>${esc(t)}</span></label></li>`).join('')}</ol>${CO_HTML}<p class="note">If a device someone needs to live stops and there is no backup, call 911.</p>` : '';
  el.innerHTML = `${head}<h2>${on ? `On for ${n} ${n === 1 ? 'county' : 'counties'}` : 'Know when the power goes out'}</h2>${body}${msg}${sweep}
    <details class="home"${h.medical ? ' open' : ''}><summary>Powered medical equipment at home</summary>
      <label class="toggle"><input type="checkbox" id="home-med"${h.medical ? ' checked' : ''}><span>Someone here relies on electricity for medical equipment</span></label>
      <p class="note">Kept only on this device; Grid’s server never learns it. With it on, alerts cover any outage in your counties, and Grid shows this plan when your county is out.</p>${plan}</details>
    <p class="note">To send alerts, Grid’s server keeps this device’s push address, the counties and these choices, nothing more; turning alerts off deletes them. Grid is an independent public-data tool, not your utility or an emergency service. Alerts can be late, and outages at utilities that do not report to ODIN never appear. In an emergency, call 911.</p>`;
}

// At a glance: one tap from each number to its panel.
export function renderNow(el, st, extra = {}) {
  const chips = [];
  const eia = st.eia?.data || st.relay?.data?.eia;
  const D = eia?.series?.D?.filter((p) => Number.isFinite(p.v));
  const isos = st.relay?.data?.isos ? Object.values(st.relay.data.isos).filter((x) => Number.isFinite(x.load_mw)) : [];
  const load = D && D.length ? { v: D.at(-1).v / 1000, l: 'Lower-48 demand' } : isos.length ? { v: isos.reduce((a, x) => a + x.load_mw, 0) / 1000, l: `load · ${isos.length} operators` } : null;
  chips.push(chip('load', '⚡', load ? `${load.v.toFixed(0)} GW` : '— GW', load ? load.l : 'demand', 'p-demand'));
  const e = st.ercot?.data;
  chips.push(chip('freq', '∿', e ? `${e.frequency.toFixed(3)} Hz` : '— Hz', 'Texas frequency', 'p-freq', e ? 'f-' + freqBand(e.frequency).cls : ''));
  if (extra.enf && extra.enf.running && extra.enf.last?.ok) chips.push(chip('enf', '◉', `${extra.enf.last.f.toFixed(4)} Hz`, 'your outlet', 'p-freq', 'f-' + freqBand(extra.enf.last.f).cls));
  const o = st.outages?.data;
  chips.push(chip('out', '⚠', o ? `${compact(o.customers)} out` : '— out', extra.localOut ? 'your county is out' : o ? `${o.nCounties.toLocaleString()} counties` : 'outages', 'p-outages', extra.localOut ? 'f-bad' : o && o.customers >= 50000 ? 'f-warn' : ''));
  const rv = extra.rivers;
  chips.push(chip('water', '≈', rv ? String(rv.inFlood) : '—', 'rivers in flood', 'p-water', rv && rv.counts && rv.counts.major ? 'f-warn' : ''));
  chips.push(chip('alerts', '⚑', extra.alertsOn ? 'On' : 'Off', 'alerts', 'p-alerts', extra.alertsOn ? 'f-on' : ''));
  const nws = st.nws?.data?.all?.length;
  chips.push(chip('wx', '☁', Number.isFinite(nws) ? String(nws) : '—', 'severe weather', 'p-hazard', nws >= 25 ? 'f-warn' : ''));
  const kp = st.space?.data?.kp1m?.at(-1)?.kp;
  chips.push(chip('kp', '✷', Number.isFinite(kp) ? `Kp ${kp.toFixed(1)}` : 'Kp —', 'geomagnetic', 'p-space', kp >= 5 ? 'f-warn' : ''));
  if (extra.auditor) chips.push(chip('aud', '✦', extra.auditor, 'auditor', 'p-auditor-mini', /refus/i.test(extra.auditor) ? 'f-bad' : ''));
  el.innerHTML = chips.join('');
}
const chip = (id, glyph, value, label, target, cls = '') => `<button class="now-chip ${cls}" data-go="${target}" data-now="${id}" title="${esc(label)}"><span class="g" aria-hidden="true">${glyph}</span><b>${esc(value)}</b><small>${esc(label)}</small></button>`;
