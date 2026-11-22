// Grid flight mode: the City flight-simulator control scheme driving MapLibre's
// camera from aircraft position and attitude, over live terrain and the grid.
// W/S pitch · A/D roll · Q/E yaw · Z/X throttle · P line patrol · Esc exit.
import { haversine } from './map.js';

const R = 6371008.8, D2R = Math.PI / 180;

export class Flight {
  constructor(gridMap, { hud, onExit, nearest } = {}) {
    this.gm = gridMap; this.map = gridMap.map; this.hud = hud; this.onExit = onExit; this.nearest = nearest;
    this.keys = new Set(); this.active = false; this.stickInput = { x: 0, y: 0 };
    this.s = null; this.patrol = null; this.last = 0;
    this._key = (e) => this.onKey(e);
    this._keyup = (e) => this.keys.delete(e.key.toLowerCase());
  }

  start(origin) {
    const lat = origin?.lat ?? 36.1699, lon = origin?.lon ?? -115.1398;
    const ground = this.groundAt(lon, lat) ?? (origin?.altitude_m || 600);
    this.s = { lon, lat, alt: ground + 900, hdg: 30, pitch: -4, roll: 0, v: 95, thr: 0.45 };
    this.active = true; this.gm.flying = true;
    this.map.setTerrain({ source: 'dem-terrain', exaggeration: 1.2 });
    this.map.setMaxPitch(110);
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
    if ('wsadqezx'.includes(k) || k.startsWith('arrow')) { this.keys.add(k); e.preventDefault(); }
  }

  installStick() {
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

  groundAt(lon, lat) {
    try { const h = this.map.queryTerrainElevation([lon, lat]); return Number.isFinite(h) ? h : null; } catch { return null; }
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
    const ground = this.groundAt(s.lon, s.lat) ?? 0;
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
    const floor = ground + 35;
    let warn = false;
    if (s.alt < floor) { s.alt = floor; s.pitch = Math.max(s.pitch, 3); warn = true; }
    s.alt = Math.min(s.alt, 60000);
    try {
      const cam = this.map.calculateCameraOptionsFromCameraLngLatAltRotation([s.lon, s.lat], s.alt, s.hdg, 90 + s.pitch, s.roll);
      this.map.jumpTo(cam);
    } catch { /* camera outside valid range */ }
    this.hud.update({ ...s, agl: s.alt - ground, warn, patrol: this.patrol && this.patrol.label });
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
    this.el = { hdg: root.querySelector('#hud-hdg'), spd: root.querySelector('#hud-spd'), alt: root.querySelector('#hud-alt'), agl: root.querySelector('#hud-agl'), pos: root.querySelector('#hud-pos'), near: root.querySelector('#hud-near'), hor: root.querySelector('#hud-horizon') };
    this.stick = root.querySelector('#stick');
    this.nearText = ''; this.flashUntil = 0; this.frame = 0;
    this.buildHorizon();
  }
  buildHorizon() {
    const ns = 'http://www.w3.org/2000/svg', svg = this.el.hor;
    svg.innerHTML = '';
    this.ladder = document.createElementNS(ns, 'g');
    for (let p = -30; p <= 30; p += 10) {
      const y = -p * 4, w = p === 0 ? 180 : 60;
      const l = document.createElementNS(ns, 'line');
      Object.entries({ x1: -w, x2: w, y1: y, y2: y, stroke: p === 0 ? '#c1e8ce' : 'rgba(193,232,206,.55)', 'stroke-width': p === 0 ? 1.6 : 1, 'stroke-dasharray': p < 0 ? '6 5' : '' }).forEach(([k, v]) => l.setAttribute(k, v));
      this.ladder.appendChild(l);
      if (p !== 0) {
        const t = document.createElementNS(ns, 'text'); t.setAttribute('x', w + 8); t.setAttribute('y', y + 4); t.setAttribute('fill', 'rgba(193,232,206,.8)'); t.setAttribute('font-size', '10'); t.textContent = String(p); this.ladder.appendChild(t);
      }
    }
    svg.appendChild(this.ladder);
    const bore = document.createElementNS(ns, 'path'); bore.setAttribute('d', 'M-46 0 H-14 L0 10 L14 0 H46'); bore.setAttribute('fill', 'none'); bore.setAttribute('stroke', '#6edfd4'); bore.setAttribute('stroke-width', '2'); svg.appendChild(bore);
    this.warn = document.createElementNS(ns, 'text'); this.warn.setAttribute('y', '70'); this.warn.setAttribute('text-anchor', 'middle'); this.warn.setAttribute('fill', '#d87e74'); this.warn.setAttribute('font-size', '14'); this.warn.setAttribute('letter-spacing', '3'); svg.appendChild(this.warn);
  }
  flash(msg) { this.flashMsg = msg; this.flashUntil = performance.now() + 3500; }
  update(s) {
    this.frame += 1;
    this.ladder.setAttribute('transform', `rotate(${-s.roll}) translate(0 ${s.pitch * 4})`);
    this.warn.textContent = s.warn ? 'TERRAIN' : (s.patrol ? `LINE PATROL · ${s.patrol}` : '');
    if (s.patrol && !s.warn) this.warn.setAttribute('fill', '#6edfd4'); else this.warn.setAttribute('fill', '#d87e74');
    if (this.frame % 4) return;
    const ft = 3.28084;
    this.el.hdg.textContent = `HDG ${String(Math.round(s.hdg) % 360).padStart(3, '0')}°`;
    this.el.spd.textContent = `GS ${String(Math.round(s.v * 1.94384)).padStart(3, '0')} kt`;
    this.el.alt.textContent = `ALT ${Math.round(s.alt * ft).toLocaleString()} ft`;
    this.el.agl.textContent = `AGL ${Math.round(s.agl * ft).toLocaleString()} ft`;
    this.el.pos.textContent = `${Math.abs(s.lat).toFixed(4)}°${s.lat >= 0 ? 'N' : 'S'} ${Math.abs(s.lon).toFixed(4)}°${s.lon >= 0 ? 'E' : 'W'}`;
    if (this.frame % 24 === 0 && this.nearFn) this.nearText = this.nearFn([s.lon, s.lat]);
    this.el.near.innerHTML = performance.now() < this.flashUntil ? this.flashMsg : this.nearText;
  }
}
