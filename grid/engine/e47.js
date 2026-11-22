// E47 reference instantiation, computed in the browser from first principles:
// H = V2 ⊗ V2 ⊗ V2 (dim 125, packing s = 25 a1 + 5 a2 + a3), total Casimir C,
// K = (C − 6I)(C − 30I), ker K of dimension 47, Γ = I − K²/99144, rate 15/17.

const N = 125, SPEC = [0, 2, 6, 12, 20, 30, 42];

function matmul(A, B) {
  const C = new Float64Array(N * N);
  for (let i = 0; i < N; i++) for (let k = 0; k < N; k++) {
    const a = A[i * N + k]; if (a === 0) continue;
    const o = k * N, r = i * N;
    for (let j = 0; j < N; j++) C[r + j] += a * B[o + j];
  }
  return C;
}
const shift = (A, mu) => { const B = Float64Array.from(A); for (let i = 0; i < N; i++) B[i * N + i] -= mu; return B; };
const trace = (A) => { let t = 0; for (let i = 0; i < N; i++) t += A[i * N + i]; return t; };
const matvec = (A, x) => { const y = new Float64Array(N); for (let i = 0; i < N; i++) { let s = 0; for (let j = 0; j < N; j++) s += A[i * N + j] * x[j]; y[i] = s; } return y; };
const nrm = (x) => Math.sqrt(x.reduce((s, v) => s + v * v, 0));

export function casimir() {
  const m = [2, 1, 0, -1, -2];
  const jp = (a) => (a === 0 ? 0 : Math.sqrt(6 - m[a] * (m[a] + 1)));   // <m+1|J+|m>, j = 2
  const Jp = new Float64Array(N * N), M = new Float64Array(N);
  for (let a1 = 0; a1 < 5; a1++) for (let a2 = 0; a2 < 5; a2++) for (let a3 = 0; a3 < 5; a3++) {
    const s = 25 * a1 + 5 * a2 + a3;
    M[s] = m[a1] + m[a2] + m[a3];
    if (a1 > 0) Jp[(s - 25) * N + s] += jp(a1);
    if (a2 > 0) Jp[(s - 5) * N + s] += jp(a2);
    if (a3 > 0) Jp[(s - 1) * N + s] += jp(a3);
  }
  const C = new Float64Array(N * N);              // C = J− J+ + Jz² + Jz, J− = J+ᵀ
  for (let i = 0; i < N; i++) for (let k = 0; k < N; k++) {
    const a = Jp[k * N + i]; if (a === 0) continue;
    for (let j = 0; j < N; j++) C[i * N + j] += a * Jp[k * N + j];
  }
  for (let i = 0; i < N; i++) C[i * N + i] += M[i] * M[i] + M[i];
  return C;
}

function lagrange(C, lam) {
  let P = null;
  for (const mu of SPEC) {
    if (mu === lam) continue;
    const F = shift(C, mu); for (let k = 0; k < N * N; k++) F[k] /= (lam - mu);
    P = P ? matmul(P, F) : F;
  }
  return P;
}

export function runE47({ seed = 47 } = {}) {
  const t0 = performance.now();
  const C = casimir();
  let sym = 0; for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) sym = Math.max(sym, Math.abs(C[i * N + j] - C[j * N + i]));
  // multiplicities from traces of powers of C (Vandermonde in the known spectrum)
  const traces = [N]; let Pk = C;
  for (let k = 1; k < SPEC.length; k++) { traces.push(trace(Pk)); if (k < SPEC.length - 1) Pk = matmul(Pk, C); }
  const V = SPEC.map((_, k) => SPEC.map((l) => l ** k));
  const mult = solve(V, traces);
  const P6 = lagrange(C, 6), P30 = lagrange(C, 30), P42 = lagrange(C, 42);
  const P = new Float64Array(N * N); for (let k = 0; k < N * N; k++) P[k] = P6[k] + P30[k];
  const K = matmul(shift(C, 6), shift(C, 30));
  const Q = matmul(K, K);
  const PP = matmul(P, P); let idem = 0; for (let k = 0; k < N * N; k++) idem = Math.max(idem, Math.abs(PP[k] - P[k]));
  const KP = matmul(K, P); let kp = 0; for (let k = 0; k < N * N; k++) kp = Math.max(kp, Math.abs(KP[k]));
  const qspec = SPEC.map((l) => ((l - 6) * (l - 30)) ** 2);
  const gamma = qspec.map((q) => 1 - q / 99144);
  const rate = Math.max(...gamma.filter((_, i) => SPEC[i] !== 6 && SPEC[i] !== 30).map(Math.abs));
  const G = new Float64Array(N * N); for (let k = 0; k < N * N; k++) G[k] = (k % (N + 1) === 0 ? 1 : 0) - Q[k] / 99144;
  // contraction on a seeded vector and on the extremal vector x* = P v + P42 v
  let s = seed >>> 0; const rnd = () => { s = (Math.imul(s, 1664525) + 1013904223) >>> 0; return s / 4294967296 - 0.5; };
  const v = Float64Array.from({ length: N }, rnd);
  const curves = { random: [], extremal: [], bound: [] };
  for (const [name, x0] of [['random', v], ['extremal', (() => { const a = matvec(P, v), b = matvec(P42, v); return a.map((t, i) => t + b[i]); })()]]) {
    const px = matvec(P, x0); const e0 = nrm(x0.map((t, i) => t - px[i]));
    let x = x0;
    for (let k = 0; k <= 60; k++) {
      curves[name].push(nrm(x.map((t, i) => t - px[i])) / e0);
      x = matvec(G, x);
    }
  }
  for (let k = 0; k <= 60; k++) curves.bound.push((15 / 17) ** k);
  return {
    symmetryDefect: sym,
    spectrum: SPEC,
    multiplicities: mult.map((m) => Math.round(m)),
    multiplicityDefect: Math.max(...mult.map((m) => Math.abs(m - Math.round(m)))),
    traceP: trace(P), idempotencyDefect: idem, kernelDefect: kp,
    qSpectrum: qspec, qGap: Math.min(...qspec.filter((q) => q > 0)), qMax: Math.max(...qspec),
    epsilonStar: '1/99144', rate, rateExact: '15/17', omega: trace(P) / N,
    curves, ms: performance.now() - t0,
  };
}

function solve(Ain, b) {
  const n = b.length, A = Ain.map((r, i) => [...r, b[i]]);
  for (let k = 0; k < n; k++) {
    let p = k; for (let i = k + 1; i < n; i++) if (Math.abs(A[i][k]) > Math.abs(A[p][k])) p = i;
    [A[k], A[p]] = [A[p], A[k]];
    for (let i = k + 1; i < n; i++) { const f = A[i][k] / A[k][k]; for (let j = k; j <= n; j++) A[i][j] -= f * A[k][j]; }
  }
  const x = new Array(n).fill(0);
  for (let i = n - 1; i >= 0; i--) { let s = A[i][n]; for (let j = i + 1; j < n; j++) s -= A[i][j] * x[j]; x[i] = s / A[i][i]; }
  return x;
}

// Canonical values of the E47 lock contract (E47-Kartekeya/interfaces/shared/e47-lock.js),
// used only when that module cannot be loaded from this origin.
export const E47_LOCK_FALLBACK = Object.freeze({
  canonical: {
    casimir_spectrum: [0, 2, 6, 12, 20, 30, 42], sector_dimensions: [1, 9, 25, 28, 27, 22, 13],
    carrier_dimension: 125, kernel_dimension: 47, coherence_fraction: '47/125',
    q_gap: 11664, q_max: 186624, epsilon_star: '1/99144', rho_star: '15/17',
  },
});
