// Flight mode physics without a browser: start height, terrain tiles arriving late, altitude hold,
// ▲ / ▼ nudges, hand flying and the terrain floor. MapLibre is replaced by a stub with a controllable ground.
// Usage: node tools/grid/test_grid_fly.mjs
import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath, pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));
const tmp = mkdtempSync(join(tmpdir(), 'grid-fly-'));
writeFileSync(join(tmp, 'fly.mjs'), readFileSync(join(here, '..', '..', 'grid', 'map', 'fly.js'), 'utf8').replace("from './map.js'", "from './map.mjs'"));
writeFileSync(join(tmp, 'map.mjs'), "export const haversine = (a, b) => { const R = 6371.0088, d = Math.PI / 180, x = Math.sin((b[1] - a[1]) * d / 2) ** 2 + Math.cos(a[1] * d) * Math.cos(b[1] * d) * Math.sin((b[0] - a[0]) * d / 2) ** 2; return 2 * R * Math.asin(Math.sqrt(x)); };\n");
globalThis.window = { addEventListener() {}, removeEventListener() {} };
globalThis.requestAnimationFrame = () => 1; globalThis.cancelAnimationFrame = () => {};
const { Flight, Hud } = await import(pathToFileURL(join(tmp, 'fly.mjs')).href);

let ground = 0; // what the stub map reports (exaggeration included); 0 = tile not loaded yet
const map = {
  queryTerrainElevation: () => ground, setTerrain() {}, setMaxPitch() {}, jumpTo() {}, easeTo() {},
  calculateCameraOptionsFromCameraLngLatAltRotation: (ll, alt, brg, pitch) => { cam.push(pitch); return {}; },
  getVerticalFieldOfView: () => 36.87,
  getContainer: () => ({ clientHeight: 748, querySelector: () => null }),
};
const cam = [];
const hud = { root: { hidden: true, querySelector: () => null }, stick: null, last: null, update(s) { this.last = s; }, flash() {} };
const gm = { map, flying: false, set() {} };
const f = new Flight(gm, { hud });
const run = (sec) => { for (let i = 0; i < sec * 20; i++) f.step(0.05); return hud.last; };
const ft = (m) => Math.round(m * 3.28084);
let n = 0; const ok = (m) => { n++; console.log('  ok', m); };

// 1. Tiles not loaded at take-off (the map answers 0 m): start from the device's altitude, scaled like the terrain.
f.start({ lat: 36.1699, lon: -115.1398, altitude_m: 610 });
let s = run(0.05);
assert.ok(Math.abs(s.alt - (610 * 1.2 + 4000)) < 5, `start alt ${s.alt}`);
assert.ok(Math.abs(s.agl - 4000) < 5, `start AGL ${s.agl}`);
assert.ok(cam.at(-1) > 76 && cam.at(-1) < 80, `camera looks ~12° below the flight path (pitch ${cam.at(-1)})`);
ok(`take-off with no terrain tiles: ${ft(s.alt).toLocaleString()} ft, ${ft(s.agl).toLocaleString()} ft above the ground (was 900 m above sea level)`);

// 2. Tiles arrive showing much higher ground (a mountain town): the first seconds lift the aircraft clear.
ground = 2400;
s = run(0.5);
assert.ok(s.agl >= 4000 * 0.8 - 1, `AGL after high ground appears: ${s.agl}`);
ok(`terrain tiles reveal 2,400 m ground: lifted to ${ft(s.agl).toLocaleString()} ft above it`);

// 3. Altitude hold, after the take-off window: no input → it holds.
f.t0 = -1e9; ground = 732;
f.s.alt = f.s.hold = 732 + 4000; f.s.pitch = 0; f.s.manual = false;
s = run(60);
assert.ok(Math.abs(s.alt - f.s.hold) < 40, `holds: ${s.alt} vs ${f.s.hold}`);
ok('no input for a minute: holds altitude within 40 m');

// 4. ▲ twice: the held altitude rises 4,000 ft and the autopilot climbs to it.
const before = f.s.hold;
f.nudgeHold(1); f.nudgeHold(1);
assert.ok(Math.abs(f.s.hold - before - 2 * 610) < 1);
s = run(90);
assert.ok(Math.abs(s.alt - f.s.hold) < 60, `climbed: ${s.alt} vs ${f.s.hold}`);
ok(`▲ ▲ climbs ${ft(2 * 610).toLocaleString()} ft to ${ft(s.alt).toLocaleString()} ft within 90 s`);
f.nudgeHold(-1); f.nudgeHold(-1); f.nudgeHold(-1);
s = run(120);
assert.ok(Math.abs(s.alt - f.s.hold) < 60, `descended: ${s.alt} vs ${f.s.hold}`);
ok('▼ ▼ ▼ descends to the new hold');

// 5. Hand flying: pull up for 4 s, let go — the altitude at release becomes the hold.
f.stickInput = { x: 0, y: -1 };
const startAlt = f.s.alt;
run(4);
assert.ok(f.s.alt > startAlt + 50, 'pulling up climbs');
assert.equal(hud.last.holdAgl, null, 'HUD shows hand flying');
f.stickInput = { x: 0, y: 0 };
run(0.05);
const released = f.s.hold;
s = run(45);
assert.ok(Math.abs(s.alt - released) < 80, `holds where released: ${s.alt} vs ${released}`);
ok('hand flying: let go of the stick and it holds where you are');

// 6. The hold can never be set into the ground, and the floor still stops a dive into rising terrain.
for (let i = 0; i < 30; i++) f.nudgeHold(-1);
assert.ok(f.s.hold >= 732 + 150, `hold floor ${f.s.hold}`);
ground = f.s.alt + 500; // a ridge higher than the aircraft
s = run(0.05);
assert.ok(s.alt >= ground + 60 - 1 && s.warn, 'terrain floor and TERRAIN warning');
ok('the held height never goes below 150 m above ground; rising terrain triggers the floor and the warning');

// 7. A tile reporting 0 m mid-flight (still loading) does not erase the known ground.
ground = 1800; run(0.05); ground = 0;
s = run(0.05);
assert.ok(s.agl < s.alt - 1000, `kept the last known ground: AGL ${s.agl} at ALT ${s.alt}`);
ok('a terrain tile still loading (0 m) does not read as sea level');

// 8. HUD geometry: the horizon line and flight-path marker land where the camera projects them. Phone canvas
// 748 px tall, MapLibre's 36.87° field of view, HUD drawn 273 px wide: the camera's centre is 374 px down the
// canvas and the true horizon in level flight 238.5 px above it (f·tan 12°, f = 374 / tan 18.43°).
const el = () => ({ setAttribute(k, v) { this[k] = v; }, appendChild() {}, set innerHTML(v) {}, getBoundingClientRect: () => ({ width: 273 }), querySelector: () => null });
globalThis.document = { createElementNS: () => el() };
const svg = el();
const H = new Hud({ querySelector: (q) => (q === '#hud-horizon' ? svg : el()) });
H.scale(36.87, 748);
const px = (u) => u / H.u;
assert.ok(Math.abs(px(H.up(12)) - 238.5) < 1, `horizon ${px(H.up(12)).toFixed(1)} px above centre`);
H.update({ pitch: 0, roll: 0, look: 12, fov: 36.87, viewH: 748, v: 100, alt: 4000, agl: 4000, lat: 36, lon: -115, hdg: 30 });
const ty = (tr) => Number(/translate\(0 (-?[\d.]+)\)/.exec(tr)[1]);
assert.ok(Math.abs(px(-ty(H.ladder.transform)) - 238.5) < 1 && Math.abs(px(-ty(H.bore.transform)) - 238.5) < 1, 'level: horizon and flight-path marker together, 12° up');
H.update({ pitch: 12, roll: 0, look: 12, fov: 36.87, viewH: 748, v: 100, alt: 4000, agl: 4000, lat: 36, lon: -115, hdg: 30 });
assert.ok(Math.abs(ty(H.ladder.transform)) < 0.01, 'nose 12° up: horizon at the view centre');
ok('HUD horizon and flight-path marker sit where the camera projects them');

console.log(`flight: ${n} checks passed`);
