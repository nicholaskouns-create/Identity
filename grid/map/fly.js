// Grid flight mode: the City flight-simulator control scheme driving MapLibre's
// camera from aircraft position and attitude, over live terrain and the grid.
// W/S pitch · A/D roll · Q/E yaw · Z/X throttle · R/F hold altitude up/down · P line patrol · Esc exit.
// Altitude hold: with no pitch input the aircraft flies to the held altitude; letting go of the stick
// holds wherever you are. The camera looks LOOK degrees below the flight path, so level flight shows
// the grid ahead with the horizon still in view.
import { haversine } from './map.js';

const R = 6371008.8, D2R = Math.PI / 180;
const EXAG = 1.2;            // terrain exaggeration in flight; ground heights from the map include it
const START_AGL = 4000;      // m above the ground (about 13,000 ft): the whole local grid in view
const HOLD_STEP = 610;       // m per tap of ▲ / ▼ or R / F (2,000 ft)
const LOOK = 12;             // camera look-down below the flight path, degrees: the horizon stays in view

export class Flight {
  constructor(gridMap, { hud, onExit, nearest } = {}) {
    this.gm = gridMap; this.map = gridMap.map; this.hud = hud; this.onExit = onExit; this.nearest = nearest;
    this.keys = new Set(); this.active = false; this.stickInput = { x: 0, y: 0 };
    this.s = null; this.patrol = null; this.last = 0; this.lastGround = 0; this.t0 = 0;
    this._key = (e) => this.onKey(e);
    this._keyup = (e) => this.keys.delete(e.key.toLowerCase());
  }

  start(origin) {
    const lat = origin?.lat ?? 36.1699, lon = origin?.lon ?? -115.1398;
    this.map.setTerrain({ source: 'dem-terrain', exaggeration: EXAG });
    this.map.setMaxPitch(110);
    // Terrain tiles may not be loaded yet, and then the map reports 0 m. Never start below the device's own
    // altitude (or 600 m), scaled like the rendered terrain; the first seconds of flight raise the aircraft
    // again if the tiles show higher ground.
    const est = Math.max(this.groundAt(lon, lat) || 0, (Number(origin?.altitude_m) || 600) * EXAG);
    this.lastGround = est;
    this.s = { lon, lat, alt: est + START_AGL, hold: est + START_AGL, hdg: 30, pitch: 0, roll: 0, v: 140, thr: 0.42 };
    this.active = true; this.gm.flying = true; this.t0 = performance.now();
    // The attribution stays one tap away (ⓘ) instead of lying open across the cockpit.
    const at = this.map.getContainer && this.map.getContainer().querySelector('.maplibregl-ctrl-attrib');
    if (at) { at.removeAttribute('open'); at.classList.remove('maplibregl-compact-show'); }
    window.addEventListener('keydown', this._key); window.addEventListener('keyup', this._keyup);
    this.installStick();
    this.hud.root.hidden = false;
    this.last = performance.now();
    const loop = (t) => { if (!this.active) return; this.step(Math.min(0.05, (t - this.last) / 1000)); this.last = t; this.raf = requestAnimationFrame(loop); };
    this.raf = requestAnimationFrame(loop);
  }

  stop() {
    this.active = false; this.gm.flying = false; cancelAnimationFrame(this.raf);
    window.removeEventListener('keydown', this._key); window.removeEventListener('keyup', this._keyup);
    this.hud.root.hidden = true; this.patrol = null; this.gm.set('patrol', { type: 'FeatureCollection', features: [] });
    this.map.easeTo({ pitch: 45, roll: 0, duration: 900 });
  }

  onKey(e) {
    const k = e.key.toLowerCase();
    if (k === 'escape') { if (this.onExit) this.onExit(); return; }
    if (k === 'p') { this.togglePatrol(); return; }
    if (k === 'r' || k === 'f') { this.nudgeHold(k === 'r' ? 1 : -1); e.preventDefault(); return; }
    if ('wsadqezx'.includes(k) || k.startsWith('arrow')) { this.keys.add(k); e.preventDefault(); }
  }

  // ▲ / ▼: move the held altitude by 2,000 ft; the autopilot climbs or descends to it.
  nudgeHold(dir) {
    if (!this.s) return;
    const ground = this.lastGround || 0;
    this.s.hold = Math.max(ground + 150, Math.min(18000, (this.s.hold ?? this.s.alt) + dir * HOLD_STEP));
  }

  installStick() {
    for (const [id, dir] of [['alt-up', 1], ['alt-dn', -1]]) {
      const b = this.hud.root.querySelector('#' + id);
      if (b && !b._wired) { b._wired = true; b.addEventListener('click', (e) => { e.preventDefault(); this.nudgeHold(dir); }); }
    }
    const st = this.hud.stick; if (!st || st._wired) return; st._wired = true;
    const knob = st.querySelector('.knob');
    const set = (ev) => {
      const r = st.getBoundingClientRect(), t = ev.touches ? ev.touches[0] : ev;
      const x = Math.max(-1, Math.min(1, (t.clientX - r.left - r.width / 2) / (r.width / 2)));
      const y = Math.max(-1, Math.min(1, (t.clientY - r.top - r.height / 2) / (r.height / 2)));
      this.stickInput = { x, y }; knob.style.transform = `translate(${x * 34}px, ${y * 34}px)`;
    };
    const end = () => { this.stickInput = { x: 0, y: 0 }; knob.style.transform = ''; };
    st.addEventListener('pointerdown', (e) => { st.setPointerCapture(e.pointerId); set(e); });
    st.addEventListener('pointermove', (e) => { if (e.buttons) set(e); });
    st.addEventListener('pointerup', end); st.addEventListener('pointercancel', end);
  }

  // Ground height under a point, as rendered (exaggeration included), or null without terrain.
  groundAt(lon, lat) {
    try { const h = this.map.queryTerrainElevation([lon, lat]); return Number.isFinite(h) ? h : null; } catch { return null; }
  }
  // This MapLibre build answers 0 m while a terrain tile is still loading, so a 0 is only believed
  // where the ground really is near sea level; otherwise the last known ground stands in.
  groundSafe(lon, lat) {
    const h = this.groundAt(lon, lat);
    if (h && h > 0) { this.lastGround = h; return h; }
    return this.lastGround > 60 ? this.lastGround : Math.max(0, h || 0);
  }

  togglePatrol() {
    if (this.patrol) { this.patrol = null; this.gm.set('patrol', { type: 'FeatureCollection', features: [] }); return; }
    const line = this.nearest && this.nearest.line([this.s.lon, this.s.lat]);
    if (!line) { this.hud.flash('No line loaded near the aircraft yet. Turn on Transmission or Local grid.'); return; }
    const pts = line.coords;
    let k = 0, best = Infinity;
    pts.forEach((p, i) => { const d = haversine([this.s.lon, this.s.lat], p); if (d < best) { best = d; k = i; } });
    this.patrol = { pts, k, label: line.label };
    this.gm.set('patrol', { type: 'FeatureCollection', features: [{ type: 'Feature', geometry: { type: 'LineString', coordinates: pts }, properties: {} }] });
  }

  step(dt) {
    const s = this.s, K = this.keys, inp = this.stickInput;
    let pitchIn = (K.has('s') || K.has('arrowdown') ? 1 : 0) - (K.has('w') || K.has('arrowup') ? 1 : 0) - inp.y;
    let rollIn = (K.has('d') || K.has('arrowright') ? 1 : 0) - (K.has('a') || K.has('arrowleft') ? 1 : 0) + inp.x;
    const yawIn = (K.has('e') ? 1 : 0) - (K.has('q') ? 1 : 0);
    if (K.has('x')) s.thr = Math.min(1, s.thr + 0.5 * dt);
    if (K.has('z')) s.thr = Math.max(0, s.thr - 0.5 * dt);
    const ground = this.groundSafe(s.lon, s.lat);
    // First seconds: terrain tiles arrive; keep the start height above whatever ground they reveal.
    if (performance.now() - this.t0 < 5000 && s.alt < ground + START_AGL * 0.8) { s.alt = ground + START_AGL * 0.8; s.hold = Math.max(s.hold, s.alt); }
    // Altitude hold: no pitch input → fly to the held altitude; any pitch input → hand flying, and the
    // altitude at release becomes the new hold.
    if (Math.abs(pitchIn) > 0.05) { s.manual = true; }
    else if (!this.patrol) {
      if (s.manual) { s.manual = false; s.hold = s.alt; }
      const want = Math.max(-15, Math.min(15, (s.hold - s.alt) / 30));
      pitchIn = Math.max(-1, Math.min(1, (want - s.pitch) / 6));
    }
    if (this.patrol) {
      const { pts } = this.patrol;
      while (this.patrol.k < pts.length - 1 && haversine([s.lon, s.lat], pts[this.patrol.k]) < 0.6) this.patrol.k += 1;
      const tgt = pts[this.patrol.k];
      const brg = bearing([s.lon, s.lat], tgt);
      let dh = ((brg - s.hdg + 540) % 360) - 180;
      rollIn = Math.max(-1, Math.min(1, dh / 25)) - s.roll / 45;
      const wantAlt = ground + 140;
      pitchIn = Math.max(-1, Math.min(1, (s.alt - wantAlt) / 120)) * 0.6 + s.pitch / 20 * 0.3;
      s.thr = 0.3;
      if (this.patrol.k >= pts.length - 1) this.patrol.k = 0;
    }
    s.roll += (rollIn * 70 - (rollIn === 0 ? s.roll * 1.2 : 0)) * dt;
    s.roll = Math.max(-75, Math.min(75, s.roll));
    s.pitch += (pitchIn * 28 - (pitchIn === 0 ? s.pitch * 0.15 : 0)) * dt;
    if (s.hold < ground + 150) s.hold = ground + 150;
    s.pitch = Math.max(-40, Math.min(35, s.pitch));
    const vT = 45 + 230 * s.thr;
    s.v += ((vT - s.v) * 0.6 - 9.81 * Math.sin(s.pitch * D2R) * 2) * dt;
    s.v = Math.max(35, Math.min(320, s.v));
    const turn = (9.81 * Math.tan(s.roll * D2R) / s.v) / D2R;
    s.hdg = (s.hdg + (turn + yawIn * 18) * dt + 360) % 360;
    const vh = s.v * Math.cos(s.pitch * D2R), vz = s.v * Math.sin(s.pitch * D2R);
    s.lat += (vh * Math.cos(s.hdg * D2R) * dt / R) / D2R;
    s.lon += (vh * Math.sin(s.hdg * D2R) * dt / (R * Math.cos(s.lat * D2R))) / D2R;
    s.alt += vz * dt;
    const floor = ground + 60;
    let warn = false;
    if (s.alt < floor) { s.alt = floor; s.pitch = Math.max(s.pitch, 3); warn = true; }
    s.alt = Math.min(s.alt, 60000);
    try {
      const cam = this.map.calculateCameraOptionsFromCameraLngLatAltRotation([s.lon, s.lat], s.alt, s.hdg, 90 + s.pitch - LOOK, s.roll);
      this.map.jumpTo(cam);
    } catch { /* camera outside valid range */ }
    const box = this.map.getContainer && this.map.getContainer();
    this.hud.update({ ...s, agl: s.alt - ground, holdAgl: s.manual ? null : s.hold - ground, warn, patrol: this.patrol && this.patrol.label, look: LOOK, fov: (this.map.getVerticalFieldOfView && this.map.getVerticalFieldOfView()) || 36.87, viewH: (box && box.clientHeight) || globalThis.innerHeight || 0 });
    if (window.CITY_GPS && window.CITY_GPS.publishAircraft) window.CITY_GPS.publishAircraft(s);
  }
}

function bearing(a, b) {
  const la1 = a[1] * D2R, la2 = b[1] * D2R, dl = (b[0] - a[0]) * D2R;
  const y = Math.sin(dl) * Math.cos(la2), x = Math.cos(la1) * Math.sin(la2) - Math.sin(la1) * Math.cos(la2) * Math.cos(dl);
  return (Math.atan2(y, x) / D2R + 360) % 360;
}

/** Glass-cockpit overlay: tapes, horizon ladder, nearest infrastructure. */
export class Hud {
  constructor(root) {
    this.root = root;
    this.el = { hdg: root.querySelector('#hud-hdg'), spd: root.querySelector('#hud-spd'), alt: root.querySelector('#hud-alt'), agl: root.querySelector('#hud-agl'), pos: root.querySelector('#hud-pos'), near: root.querySelector('#hud-near'), hor: root.querySelector('#hud-horizon'), hold: root.querySelector('#hud-hold') };
    this.k = 4; this.f = 1; this.u = 1; // ladder spacing (SVG units per degree), camera focal length (px), SVG units per px
    this.stick = root.querySelector('#stick');
    this.nearText = ''; this.flashUntil = 0; this.frame = 0;
    this.buildHorizon();
  }
  buildHorizon(k = this.k) {
    this.k = k;
    const ns = 'http://www.w3.org/2000/svg', svg = this.el.hor;
    svg.innerHTML = '';
    this.ladder = document.createElementNS(ns, 'g');
    for (let p = -30; p <= 30; p += 10) {
      const y = -p * k, w = p === 0 ? 180 : 60;
      const l = document.createElementNS(ns, 'line');
      Object.entries({ x1: -w, x2: w, y1: y, y2: y, stroke: p === 0 ? '#c1e8ce' : 'rgba(193,232,206,.55)', 'stroke-width': p === 0 ? 1.6 : 1, 'stroke-dasharray': p < 0 ? '6 5' : '' }).forEach(([k, v]) => l.setAttribute(k, v));
      this.ladder.appendChild(l);
      if (p !== 0) {
        const t = document.createElementNS(ns, 'text'); t.setAttribute('x', w + 8); t.setAttribute('y', y + 4); t.setAttribute('fill', 'rgba(193,232,206,.8)'); t.setAttribute('font-size', '10'); t.textContent = String(p); this.ladder.appendChild(t);
      }
    }
    svg.appendChild(this.ladder);
    this.bore = document.createElementNS(ns, 'path'); this.bore.setAttribute('d', 'M-46 0 H-14 L0 10 L14 0 H46'); this.bore.setAttribute('fill', 'none'); this.bore.setAttribute('stroke', '#6edfd4'); this.bore.setAttribute('stroke-width', '2'); svg.appendChild(this.bore);
    this.warn = document.createElementNS(ns, 'text'); this.warn.setAttribute('y', '70'); this.warn.setAttribute('text-anchor', 'middle'); this.warn.setAttribute('fill', '#d87e74'); this.warn.setAttribute('font-size', '14'); this.warn.setAttribute('letter-spacing', '3'); svg.appendChild(this.warn);
  }
  flash(msg) { this.flashMsg = msg; this.flashUntil = performance.now() + 3500; }
  // The camera's own geometry: an angle a above the view centre lands f·tan(a) px up the map canvas, with
  // f = (canvas height / 2) / tan(fov / 2). The ladder is spaced at f px per radian; recomputed when the size changes.
  scale(fov, viewH) {
    const w = this.el.hor.getBoundingClientRect().width || 1, key = `${viewH}x${w}x${fov}`;
    if (key === this._scaleKey) return;
    this._scaleKey = key;
    this.f = (viewH / 2) / Math.tan((fov / 2) * Math.PI / 180);
    this.u = 400 / w;
    this.buildHorizon(this.f * (Math.PI / 180) * this.u);
  }
  // SVG units above the view centre for a direction `deg` degrees above the camera's line of sight.
  up(deg) { return this.f * Math.tan(Math.max(-80, Math.min(80, deg)) * Math.PI / 180) * this.u; }
  update(s) {
    this.frame += 1;
    if (this.frame % 30 === 1 && s.viewH) this.scale(s.fov || 36.87, s.viewH);
    const look = s.look || 0;
    // The camera looks `look` degrees below the flight path: the flight-path marker sits that far above the view
    // centre, and the horizon sits (look - pitch) degrees above it, both placed by the camera's projection.
    this.ladder.setAttribute('transform', `rotate(${-s.roll}) translate(0 ${-this.up(look - s.pitch)})`);
    this.bore.setAttribute('transform', `translate(0 ${-this.up(look)})`);
    this.warn.textContent = s.warn ? 'TERRAIN' : (s.patrol ? `LINE PATROL · ${s.patrol}` : '');
    if (s.patrol && !s.warn) this.warn.setAttribute('fill', '#6edfd4'); else this.warn.setAttribute('fill', '#d87e74');
    if (this.frame % 4) return;
    const ft = 3.28084;
    this.el.hdg.textContent = `HDG ${String(Math.round(s.hdg) % 360).padStart(3, '0')}°`;
    this.el.spd.textContent = `GS ${String(Math.round(s.v * 1.94384)).padStart(3, '0')} kt`;
    this.el.alt.textContent = `ALT ${Math.round(s.alt * ft).toLocaleString()} ft`;
    this.el.agl.textContent = `AGL ${Math.round(s.agl * ft).toLocaleString()} ft`;
    if (this.el.hold) this.el.hold.textContent = s.holdAgl == null ? 'hand flying' : `${(Math.round((s.holdAgl * ft) / 100) * 100).toLocaleString()} ft`;
    this.el.pos.textContent = `${Math.abs(s.lat).toFixed(4)}°${s.lat >= 0 ? 'N' : 'S'} ${Math.abs(s.lon).toFixed(4)}°${s.lon >= 0 ? 'E' : 'W'}`;
    if (this.frame % 24 === 0 && this.nearFn) this.nearText = this.nearFn([s.lon, s.lat]);
    this.el.near.innerHTML = performance.now() < this.flashUntil ? this.flashMsg : this.nearText;
  }
}
