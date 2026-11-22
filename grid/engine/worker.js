// KKP-GRID compute worker. Two instances run: one for the live monitor,
// certificate checks and the E47 engine; one for acceptance benchmarks.
import { GridSystem, runTrial, newCache, runAcceptance, CLASSES } from './monitor.js';
import { verifyCertificate } from './certificate.js';
import { runE47 } from './e47.js';
import { Stream } from './prng.js';
import { PINS } from './pins.js';

const systems = new Map(), caches = new Map(), raw = new Map();
let stopFlag = false, liveCounter = 0;

const pack = (o) => ({
  cls: o.cls, scale: o.scale, dev: o.dev, group: o.group, vote: o.vote, voteDev: o.voteDev, auditor: o.auditor,
  pipelines: o.pipelines, truthHarmVote: o.truthHarmVote, flippedBranch: o.flippedBranch, untouched: o.untouched,
  mag: o.mag, replicaRanks: o.replicaRanks,
  xRec: Array.from(o.xRec), ys: o.ys.map((y) => Array.from(y)), pdx: Array.from(o.pdx),
  delivered: o.delivered ? Array.from(o.delivered) : null,
  spectra: o.spectra.map((w) => (w ? Array.from(w).slice(0, 8) : null)),
});

self.onmessage = async (ev) => {
  const m = ev.data;
  try {
    if (m.type === 'init') {
      raw.set(m.key, { topo: m.topoBytes, cert: m.certBytes });
      const topo = JSON.parse(new TextDecoder().decode(m.topoBytes));
      const cert = JSON.parse(new TextDecoder().decode(m.certBytes));
      const sys = new GridSystem(m.key, topo, cert);
      systems.set(m.key, sys);
      caches.set(m.key, newCache(sys, 47));
      self.postMessage({ type: 'ready', id: m.id, key: m.key, n: sys.n, tol: sys.tol, g: sys.g, eps0: sys.eps0, nonisland: sys.nonisland, branches: topo.branches, buses: topo.buses });
    } else if (m.type === 'verify') {
      const r = raw.get(m.key);
      const rep = await verifyCertificate({
        key: m.key, topoBytes: r.topo, certBytes: m.tamper ? tamper(r.cert) : r.cert, pins: PINS, scope: m.scope || 'critical',
        onStep: (c) => self.postMessage({ type: 'verify-step', id: m.id, key: m.key, check: c }),
      });
      delete rep.cert; delete rep.topo;
      self.postMessage({ type: 'verified', id: m.id, key: m.key, report: rep });
    } else if (m.type === 'tick') {
      const sys = systems.get(m.key);
      const st = new Stream((m.seed ?? (Date.now() ^ (++liveCounter * 2654435761))) >>> 0);
      const o = runTrial(sys, m.cls || 'L0', st, caches.get(m.key), { scale: m.scale, flipBranch: m.flipBranch, untouched: m.untouched });
      self.postMessage({ type: 'tick', id: m.id, key: m.key, outcome: pack(o) });
    } else if (m.type === 'acceptance') {
      stopFlag = false;
      const sys = systems.get(m.key);
      const res = await runAcceptance(sys, m.trials, m.seed, (done, total, table) => {
        self.postMessage({ type: 'progress', id: m.id, key: m.key, done, total, table });
      }, () => stopFlag);
      self.postMessage({ type: 'acceptance', id: m.id, key: m.key, trials: m.trials, seed: m.seed, ...res, log: undefined, logLength: res.log.length, classes: CLASSES });
    } else if (m.type === 'stop') {
      stopFlag = true;
    } else if (m.type === 'e47') {
      const r = runE47({ seed: m.seed || 47 });
      self.postMessage({ type: 'e47', id: m.id, result: r });
    }
  } catch (err) {
    self.postMessage({ type: 'error', id: m.id, error: String(err && err.stack || err) });
  }
};

function tamper(buf) { const b = new Uint8Array(buf.slice(0)); b[Math.min(120, b.length - 1)] ^= 1; return b.buffer; }
