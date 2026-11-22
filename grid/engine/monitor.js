// KKP-GRID certified spectral monitor · protocol KKP-GRID-ACCEPTANCE-1.0
// Browser twin of tools/grid/acceptance.py. Same random stream, same draw order,
// independent eigensolvers. Five replicas, five pipelines, one auditor that reads
// the pinned certificate rather than the runtime topology file.

import { Stream, fmix32, trialSeed } from './prng.js';
import * as L from './linalg.js';

export const CLASSES = ['L0', 'CM2', 'H1', 'E1', 'CM6'];
export const CLASS_INFO = {
  L0: { name: 'Legitimate', detail: 'Shared substrate perturbation up to 0.8 ε₀ plus per-replica jitter up to 0.1 ε₀. No fault.' },
  CM2: { name: 'One topology entry altered', detail: 'A branch status is flipped in the shared runtime topology file. Each replica is independently untouched with probability 0.15 (it built Â from the pre-alteration copy).' },
  H1: { name: 'Shared helper defect', detail: 'The window-selection helper shared by R1, R2 and R5 selects the next r modes. R3 and R4 do not use it.' },
  E1: { name: 'Envelope breach', detail: 'Shared substrate drift of 2 ε₀ to 6 ε₀, beyond the declared envelope but inside g/2.' },
  CM6: { name: 'Input integrity', detail: 'The state vector itself is spoofed with a component inside the window. Every pipeline certifies the input it receives; this is the stated limit.' },
};
export const PIPES = ['voting', 'validated_residual', 'independent_reference', 'anomaly_detector', 'certified_auditor'];
export const PIPE_LABEL = {
  voting: 'Majority vote', validated_residual: 'Validated residual', independent_reference: 'Independent reference',
  anomaly_detector: 'Anomaly detector', certified_auditor: 'Certified auditor',
};
export const PROTOCOL = Object.freeze({ pUntouched: 0.15, sigmaPmu: 0.002, spoof: 0.25, r4Iters: 60 });

const fracToFloat = (s) => { const [a, b] = String(s).split('/'); return b === undefined ? Number(a) : Number(a) / Number(b); };

export class GridSystem {
  constructor(key, topo, cert) {
    this.key = key; this.topo = topo; this.cert = cert;
    this.n = topo.buses.length;
    this.idx = new Map(topo.buses.map((b, i) => [b[0], i]));
    this.ref = topo.buses.findIndex((b) => b[1] === 3);
    this.g = fracToFloat(cert.gap.g);
    this.eps0 = fracToFloat(cert.envelope.eps0);
    this.tol = fracToFloat(cert.envelope.tolerance);
    this.r = cert.window.r;
    this.loI = cert.window.indices[0];
    this.lamLo = fracToFloat(cert.window.enclosure.lo);
    this.lamHi = fracToFloat(cert.window.enclosure.hi);
    this.winLo = this.lamLo - this.g / 2;
    this.winHi = this.lamHi + this.g / 2;
    this.mu = (this.lamLo + this.lamHi) / 2;
    const n = this.n, r = this.r;
    this.U = new Float64Array(n * r);
    cert.basis.U.forEach((row, i) => row.forEach((v, k) => { this.U[i * r + k] = v; }));
    this.A = this.operator(topo.branches);
    this.nonisland = [];
    for (let k = 0; k < topo.branches.length; k++) {
      const w = L.eigvalsSym(this.operator(this.flipped(k)), n);
      if (w[1] > 1e-9) this.nonisland.push(k);
    }
    const st = new Stream(0x5EED0000 + n);
    this.V0 = new Float64Array(n * r);
    for (let i = 0; i < n; i++) for (let k = 0; k < r; k++) this.V0[i * r + k] = st.normal();
    const sl = new Stream(0x1A2C3000 + n);
    this.lanczosStart = Float64Array.from({ length: n }, () => sl.normal());
    this.theta1 = this.solveState(1);
  }

  operator(branches) {
    const n = this.n, A = new Float64Array(n * n);
    for (const [f, t, x, tap, s] of branches) {
      if (s === 0) continue;
      const tau = Number(tap) !== 0 ? Number(tap) : 1;
      const b = 1 / (Number(x) * tau);
      const i = this.idx.get(f), j = this.idx.get(t);
      A[i * n + i] += b; A[j * n + j] += b; A[i * n + j] -= b; A[j * n + i] -= b;
    }
    return A;
  }

  flipped(k) { return this.topo.branches.map((b, i) => (i === k ? [b[0], b[1], b[2], b[3], 1 - b[4]] : b)); }

  solveState(scale) {
    const n = this.n, P = new Float64Array(n), base = this.topo.baseMVA;
    for (const b of this.topo.buses) P[this.idx.get(b[0])] -= b[2] * scale / base;
    for (const [bus, pg, on] of this.topo.gens) if (on) P[this.idx.get(bus)] += pg * scale / base;
    const keep = []; for (let i = 0; i < n; i++) if (i !== this.ref) keep.push(i);
    const m = keep.length, Ar = new Float64Array(m * m), Pr = new Float64Array(m);
    keep.forEach((i, a) => { Pr[a] = P[i]; keep.forEach((j, b) => { Ar[a * m + b] = this.A[i * n + j]; }); });
    const th = L.cholSolve(Ar, m, Pr), out = new Float64Array(n);
    keep.forEach((i, a) => { out[i] = th[a]; });
    return out;
  }

  state(scale) { return this.theta1.map((v) => v * scale); }

  helper(w, V, defect) {
    const n = this.n;
    let cols;
    if (defect) { const k = this.loI + 1; cols = Array.from({ length: this.r }, (_, c) => k + c); }
    else { cols = []; for (let i = 0; i < n; i++) if (w[i] >= this.winLo && w[i] <= this.winHi) cols.push(i); }
    return { U: L.pickColumns(V, n, cols), r: cols.length };
  }

  projEig(A, solver, defect) {
    const n = this.n;
    const E = solver === 'jacobi' ? L.jacobiEigen(A, n) : solver === 'lanczos' ? L.lanczosEigen(A, n, this.lanczosStart) : L.tredTql(A, n);
    return { ...this.helper(E.w, E.V, defect), w: E.w };
  }

  projSign(A) {
    const n = this.n, M1 = new Float64Array(n * n), M2 = new Float64Array(n * n);
    for (let k = 0; k < n * n; k++) { M1[k] = -A[k]; M2[k] = A[k]; }
    for (let i = 0; i < n; i++) { M1[i * n + i] += this.winHi; M2[i * n + i] -= this.winLo; }
    const M = new Float64Array(n * n);
    for (let i = 0; i < n; i++) for (let k = 0; k < n; k++) {
      const a = M1[i * n + k]; if (a === 0) continue;
      for (let j = 0; j < n; j++) M[i * n + j] += a * M2[k * n + j];
    }
    const S = L.signNewton(M, n);
    for (let k = 0; k < n * n; k++) S[k] *= 0.5;
    for (let i = 0; i < n; i++) S[i * n + i] += 0.5;
    return S;
  }

  projResolvent(A) {
    const n = this.n, r = this.r, M = Float64Array.from(A);
    for (let i = 0; i < n; i++) M[i * n + i] -= this.mu;
    const F = L.luFactor(M, n);
    let V = Float64Array.from(this.V0);
    const col = new Float64Array(n);
    for (let it = 0; it < PROTOCOL.r4Iters; it++) {
      const W = new Float64Array(n * r);
      for (let c = 0; c < r; c++) {
        for (let i = 0; i < n; i++) col[i] = V[i * r + c];
        const s = L.luSolve(F, col);
        for (let i = 0; i < n; i++) W[i * r + c] = s[i];
      }
      V = L.orthonormalize(W, n, r);
    }
    return { U: V, r };
  }

  pd(x) { return L.projectBasis(this.U, this.n, this.r, x); }
}

function symNoise(st, n) {
  const S = new Float64Array(n * n);
  for (let i = 0; i < n; i++) for (let j = i; j < n; j++) { const v = st.normal(); S[i * n + j] = v; S[j * n + i] = v; }
  return S;
}

function vote(ys, xnorm, tol) {
  let best = null;
  for (let i = 0; i < ys.length; i++) {
    const group = [];
    for (let j = 0; j < ys.length; j++) if (L.dist(ys[j], ys[i]) / xnorm <= tol) group.push(j);
    if (best === null || group.length > best.length) best = group;
  }
  if (best.length >= 3) {
    const n = ys[0].length, y = new Float64Array(n);
    for (const j of best) for (let i = 0; i < n; i++) y[i] += ys[j][i] / best.length;
    return { y, group: best };
  }
  return { y: null, group: best };
}

const applyBasis = (sys, B, x) => L.projectBasis(B.U, sys.n, B.r, x);

/**
 * One trial of the protocol. `st` is the trial's random stream. `live` may override
 * the load scale, the flipped branch and the untouched flags (draws still happen,
 * so the stream stays aligned with the acceptance protocol).
 */
export function runTrial(sys, cls, st, cache, live = {}) {
  const n = sys.n, tol = sys.tol;
  const u = st.uniform();
  const scale = live.scale ?? (0.85 + 0.30 * u);
  const xTrue = sys.state(scale);
  const xMeas = new Float64Array(n);
  for (let i = 0; i < n; i++) xMeas[i] = xTrue[i] + st.normal() * PROTOCOL.sigmaPmu;
  let runtime = sys.topo.branches, untouched = [false, false, false, false, false], flippedBranch = null;
  if (cls === 'CM2') {
    let k = sys.nonisland[st.intBelow(sys.nonisland.length)];
    if (live.flipBranch != null) k = live.flipBranch;
    runtime = sys.flipped(k); flippedBranch = k;
    untouched = untouched.map(() => st.uniform() < PROTOCOL.pUntouched);
    if (live.untouched) untouched = live.untouched;
  }
  let xRec = xMeas;
  if (cls === 'CM6') {
    const c = new Float64Array(sys.r); for (let k = 0; k < sys.r; k++) c[k] = st.normal();
    const nc = L.norm2(c); for (let k = 0; k < sys.r; k++) c[k] /= nc;
    const nm = L.norm2(xMeas);
    xRec = Float64Array.from(xMeas);
    for (let i = 0; i < n; i++) { let s = 0; for (let k = 0; k < sys.r; k++) s += sys.U[i * sys.r + k] * c[k]; xRec[i] += PROTOCOL.spoof * nm * s; }
  }
  const Art = cls === 'CM2' ? sys.operator(runtime) : sys.A;
  const S = symNoise(st, n);
  const u2 = st.uniform();
  const mag = cls === 'E1' ? (2 + 4 * u2) * sys.eps0 : 0.8 * sys.eps0 * u2;
  const sS = mag / L.spectralNormSym(S, n);
  const Ej = [];
  for (let k = 0; k < 5; k++) {
    const J = symNoise(st, n); const v = st.uniform();
    const sJ = 0.1 * sys.eps0 * v / L.spectralNormSym(J, n);
    for (let q = 0; q < n * n; q++) J[q] *= sJ;
    Ej.push(J);
  }
  const defect = cls === 'H1';
  const Ahat = Ej.map((J, k) => {
    const base = untouched[k] ? sys.A : Art, M = new Float64Array(n * n);
    for (let q = 0; q < n * n; q++) M[q] = base[q] + S[q] * sS + J[q];
    return M;
  });
  const b1 = sys.projEig(Ahat[0], 'jacobi', defect);
  const b2 = sys.projEig(Ahat[1], 'tql', defect);
  const P3 = sys.projSign(Ahat[2]);
  const b4 = sys.projResolvent(Ahat[3]);
  const b5 = sys.projEig(Ahat[4], 'lanczos', defect);
  const ys = [applyBasis(sys, b1, xRec), applyBasis(sys, b2, xRec), L.matvec(P3, n, xRec), applyBasis(sys, b4, xRec), applyBasis(sys, b5, xRec)];
  const xr = L.norm2(xRec), pdx = sys.pd(xRec);
  const dev = ys.map((y) => L.dist(y, pdx) / xr);
  const yTrue = sys.pd(xMeas), xm = L.norm2(xMeas);
  const harm = (y) => L.dist(y, yTrue) / xm > tol;
  const { y: yv, group } = vote(ys, xr, tol);

  const key = `${cls}|${flippedBranch}`;
  if (!cache.has(key)) {
    const brt = sys.projEig(Art, 'tql', defect);
    cache.set(key, { brt, Pref: sys.projSign(Art) });
  }
  const { brt, Pref } = cache.get(key);
  const res = {};
  res.voting = yv ? ['deliver', harm(yv)] : ['refuse', false];
  if (!yv) {
    res.validated_residual = ['refuse', false]; res.independent_reference = ['refuse', false]; res.anomaly_detector = ['refuse', false];
  } else {
    const dRt = L.dist(yv, applyBasis(sys, brt, xRec)) / xr;
    res.validated_residual = dRt <= tol ? ['deliver', harm(yv)] : ['refuse', false];
    const dRef = L.dist(yv, L.matvec(Pref, n, xRec)) / xr;
    res.independent_reference = dRef <= tol ? ['deliver', harm(yv)] : ['refuse', false];
    const ratio = L.norm2(yv) / xr; const [muR, sdR] = cache.get('anomaly');
    res.anomaly_detector = Math.abs(ratio - muR) <= 4 * sdR ? ['deliver', harm(yv)] : ['refuse', false];
  }
  const dv = yv ? L.dist(yv, pdx) / xr : null;
  let auditor, delivered = null;
  if (dv !== null && dv <= tol) { res.certified_auditor = ['deliver', harm(yv)]; auditor = 'deliver'; delivered = yv; }
  else {
    const sel = dev.findIndex((d) => d <= tol);
    if (sel < 0) { res.certified_auditor = ['refuse', false]; auditor = 'refuse'; }
    else { res.certified_auditor = ['deliver', harm(ys[sel])]; auditor = `select_R${sel + 1}`; delivered = ys[sel]; }
  }
  return {
    cls, scale, dev, group, vote: !!yv, voteDev: dv, auditor, pipelines: res, truthHarmVote: yv ? harm(yv) : null,
    flippedBranch, untouched, mag, xRec, xMeas, ys, yv, delivered, pdx,
    replicaRanks: [b1.r, b2.r, 'sign', b4.r, b5.r], spectra: [b1.w, b2.w, null, null, b5.w],
  };
}

export function calibrateAnomaly(sys, seed, m = 50) {
  const ratios = [];
  for (let t = 0; t < m; t++) {
    const st = new Stream(fmix32((seed ^ 0xA5A5A5A5 ^ t) >>> 0));
    const scale = 0.85 + 0.30 * st.uniform();
    const x = sys.state(scale);
    for (let i = 0; i < sys.n; i++) x[i] += st.normal() * PROTOCOL.sigmaPmu;
    ratios.push(L.norm2(sys.pd(x)) / L.norm2(x));
  }
  const mean = ratios.reduce((a, b) => a + b, 0) / m;
  const sd = Math.sqrt(ratios.reduce((a, b) => a + (b - mean) * (b - mean), 0) / m) + 1e-12;
  return [mean, sd];
}

export function newCache(sys, seed) { const c = new Map(); c.set('anomaly', calibrateAnomaly(sys, seed)); return c; }

export function emptyTable() {
  const t = {};
  for (const cls of CLASSES) {
    t[cls] = { trials: 0, voted_output_harmful: 0, auditor_selected: 0, auditor_refused: 0, pipelines: {} };
    for (const p of PIPES) t[cls].pipelines[p] = { delivered: 0, harmful_passed: 0, refused: 0 };
    if (cls === 'L0') { t[cls].auditor_false_alarms = 0; t[cls].largest_legitimate_dev = 0; }
  }
  return t;
}

export function accumulate(table, o, log, t) {
  const row = table[o.cls];
  row.trials += 1;
  for (const p of PIPES) {
    const [d, h] = o.pipelines[p];
    if (d === 'deliver') { row.pipelines[p].delivered += 1; row.pipelines[p].harmful_passed += h ? 1 : 0; }
    else row.pipelines[p].refused += 1;
  }
  if (o.auditor.startsWith('select')) row.auditor_selected += 1;
  if (o.auditor === 'refuse') row.auditor_refused += 1;
  if (o.truthHarmVote) row.voted_output_harmful += 1;
  if (o.cls === 'L0') {
    if (o.auditor !== 'deliver') row.auditor_false_alarms += 1;
    row.largest_legitimate_dev = Math.max(row.largest_legitimate_dev, ...o.dev, o.voteDev ?? 0);
  }
  if (log) log.push([o.cls, t, o.auditor, ...PIPES.map((p) => (o.pipelines[p][0] === 'deliver' ? 1 : 0))]);
}

export async function sha256Hex(text) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return Array.from(new Uint8Array(buf), (b) => b.toString(16).padStart(2, '0')).join('');
}

/** Run the acceptance protocol for one system. onProgress(done, total, table). */
export async function runAcceptance(sys, trials, seed, onProgress, shouldStop) {
  const cache = newCache(sys, seed), table = emptyTable(), log = [];
  const total = trials * CLASSES.length;
  let done = 0;
  for (let ci = 0; ci < CLASSES.length; ci++) {
    for (let t = 0; t < trials; t++) {
      if (shouldStop && shouldStop()) return { table, log, stopped: true };
      const o = runTrial(sys, CLASSES[ci], new Stream(trialSeed(seed, ci, t)), cache);
      accumulate(table, o, log, t);
      done += 1;
      if (onProgress && (done % 4 === 0 || done === total)) onProgress(done, total, table);
      if (done % 8 === 0) await new Promise((r) => setTimeout(r, 0));
    }
  }
  const decisionsSha256 = await sha256Hex(JSON.stringify(log));
  return { table, log, decisionsSha256, stopped: false };
}
