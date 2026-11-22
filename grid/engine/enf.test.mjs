// Outlet frequency meter: drive the AudioWorklet with synthetic hum and check the estimate.
// Run: node grid/engine/enf.test.mjs
import assert from 'node:assert/strict';
import { estimateEnf } from '../live/enf.js';

let Cls = null;
async function worklet() {
  if (Cls) return Cls;
  globalThis.AudioWorkletProcessor = class { constructor() { this.port = { postMessage: (m) => globalThis.__enfMsgs.push(m) }; } };
  globalThis.registerProcessor = (_n, c) => { Cls = c; };
  globalThis.sampleRate = 48000; globalThis.currentTime = 0;
  await import('../live/enf-worklet.js');
  return Cls;
}

async function run(fs, f0, opts = {}) {
  const msgs = (globalThis.__enfMsgs = []);
  globalThis.sampleRate = fs;
  const p = new (await worklet())();
  const secs = opts.secs || 6, n = Math.round(secs * fs), q = 128;
  let seed = 12345; const rnd = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296);
  const gauss = () => Math.sqrt(-2 * Math.log(rnd() + 1e-12)) * Math.cos(2 * Math.PI * rnd());
  const hum = opts.hum || [[1, 0.02], [2, 0.012], [3, 0.008]];
  for (let s = 0; s < n; s += q) {
    const buf = new Float32Array(q);
    for (let i = 0; i < q; i++) {
      const t = (s + i) / fs; let v = (opts.noise ?? 0.03) * gauss();
      for (const [k, a] of hum) v += a * Math.sin(2 * Math.PI * k * f0 * t + k * 0.7);
      if (opts.beep && (t % 1) < 0.2) v += 0.3 * Math.sin(2 * Math.PI * 440 * t);
      buf[i] = v;
    }
    p.process([[buf]]);
  }
  return estimateEnf(msgs);
}

const cases = [[48000, 60.012], [44100, 59.987], [48000, 60.0], [96000, 60.031]];
for (const [fs, f0] of cases) {
  const r = await run(fs, f0);
  assert.ok(r.ok, `estimate at ${fs} Hz sampling`);
  const err = Math.abs(r.f - f0);
  console.log(`fs ${fs}  true ${f0.toFixed(4)} Hz  estimate ${r.f.toFixed(5)} ± ${(r.sd * 1000).toFixed(2)} mHz  error ${(err * 1000).toFixed(3)} mHz  harmonics ${r.used.join('/')}`);
  assert.ok(err < 0.0015, `within 1.5 mHz (got ${(err * 1000).toFixed(3)} mHz)`);
}
// Phone microphones often cut 60 Hz: the 120/180 Hz components alone must still give the answer.
const hp = await run(48000, 59.994, { hum: [[2, 0.01], [3, 0.006]] });
assert.ok(hp.ok && Math.abs(hp.f - 59.994) < 0.0015 && !hp.used.includes(60), 'harmonics-only case');
console.log(`harmonics only: estimate ${hp.f.toFixed(5)} Hz from ${hp.used.join('/')} Hz`);
// A beep (440 Hz, on 0.2 s of every second) must not produce a reading; hum under the beep still must.
const beep = await run(48000, 60, { hum: [], noise: 0.005, beep: true });
assert.ok(!beep.ok, 'beeps are not hum');
const humBeep = await run(48000, 60.008, { beep: true });
assert.ok(humBeep.ok && Math.abs(humBeep.f - 60.008) < 0.002, 'hum under beeps');
console.log(`beeps alone: no reading; hum under beeps: ${humBeep.f.toFixed(5)} Hz`);
// Pure noise must not produce a reading.
const none = await run(48000, 60, { hum: [], noise: 0.05 });
assert.ok(!none.ok, 'no hum, no reading');
console.log('no hum: no reading, as required');
