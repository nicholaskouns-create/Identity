// Re-verification of a pinned KKP-GRID certificate inside the browser.
// Pins first (SHA-256 of the exact bytes served), then exact arithmetic:
// every inertia count of A - sigma I is recomputed over Q with BigInt.

import { Q, ZERO, exactOperator, rowSumsZero, countBelow, minQ } from './rational.js';

export async function sha256Bytes(buf) {
  const h = await crypto.subtle.digest('SHA-256', buf);
  return Array.from(new Uint8Array(h), (b) => b.toString(16).padStart(2, '0')).join('');
}

export const CRITICAL_ROLES = ['floor', 'lambda-lower', 'lambda-upper', 'next-lower'];

/**
 * @param {object} p  { key, topoBytes:ArrayBuffer, certBytes:ArrayBuffer, pins, scope:'critical'|'all', onStep }
 * @returns report { ok, checks:[{id,label,ok,detail}], counts, ms }
 */
export async function verifyCertificate({ key, topoBytes, certBytes, pins, scope = 'critical', onStep }) {
  const t0 = performance.now();
  const checks = [];
  const add = (id, label, ok, detail = '') => { checks.push({ id, label, ok: !!ok, detail }); if (onStep) onStep(checks.at(-1)); return ok; };
  const topoHash = await sha256Bytes(topoBytes);
  const certHash = await sha256Bytes(certBytes);
  const certPinOk = add('pin-cert', 'Certificate file matches its SHA-256 pin', certHash === pins[`certificate-${key}.json`], certHash);
  const topoPinOk = add('pin-topo', 'Topology model matches its SHA-256 pin', topoHash === pins[`topology-${key}.json`], topoHash);
  if (!certPinOk) return { ok: false, checks, ms: performance.now() - t0, refused: 'certificate pin mismatch' };
  const cert = JSON.parse(new TextDecoder().decode(certBytes));
  const topo = JSON.parse(new TextDecoder().decode(topoBytes));
  add('cert-topo', 'Certificate names this topology model by hash', cert.topology.sha256 === topoHash, cert.topology.sha256);
  const { A, n } = exactOperator(topo);
  add('null', 'Exact null vector: every row of A sums to 0 over Q', rowSumsZero(A), `n = ${n}`);
  const order = cert.elimination_order;
  const seps = scope === 'all' ? cert.separators : cert.separators.filter((s) => CRITICAL_ROLES.includes(s.role));
  let exact = 0;
  for (const s of seps) {
    const sigma = Q.parse(s.sigma);
    const got = countBelow(A, n, sigma, order);
    const ok = got === s.below;
    exact += ok ? 1 : 0;
    add(`inertia-${s.role}-${s.sigma}`, `#{λ < ${s.sigma}} = ${s.below}`, ok, `exact LDLᵀ over Q gives ${got}`);
    await new Promise((r) => setTimeout(r, 0));
  }
  const byRole = (role) => Q.parse(cert.separators.find((s) => s.role === role).sigma);
  const Lq = byRole('lambda-lower'), Uq = byRole('lambda-upper'), Vq = byRole('next-lower');
  const gBelow = Lq.sub(ZERO), gAbove = Vq.sub(Uq), g = minQ(gBelow, gAbove);
  add('gap', `Certified gap g = min(${gBelow}, ${gAbove})`, g.eq(Q.parse(cert.gap.g)), `g = ${g} ≈ ${g.toNumber().toPrecision(8)}`);
  const eps0 = g.mul(new Q(1n, 40n));
  const s = eps0.div(g.sub(eps0));
  const tol = s.add(new Q(1n, 200n));
  add('envelope', 'ε₀ = g/40, s(ε₀) = ε₀/(g − ε₀), τ = s(ε₀) + 1/200', eps0.eq(Q.parse(cert.envelope.eps0)) && s.eq(Q.parse(cert.envelope.s_eps0)) && tol.eq(Q.parse(cert.envelope.tolerance)), `τ = ${tol} ≈ ${tol.toNumber().toFixed(6)}`);
  const sorted = [...cert.separators].sort((a, b) => Q.parse(a.sigma).cmp(Q.parse(b.sigma)));
  let mono = true; for (let i = 1; i < sorted.length; i++) if (sorted[i].below < sorted[i - 1].below) mono = false;
  add('monotone', 'Counts are monotone in σ and close at n', mono && sorted.at(-1).below === n && sorted[0].below === 0, `${cert.intervals.length} enclosing intervals`);
  // Float check of the stored basis against A.
  const Af = new Float64Array(n * n); A.forEach((row, i) => row.forEach((v, j) => { Af[i * n + j] = v.toNumber(); }));
  const U = cert.basis.U, r = cert.window.r;
  let orth = 0, resid = 0; const rq = [];
  for (let a = 0; a < r; a++) {
    for (let b = 0; b < r; b++) { let d = 0; for (let i = 0; i < n; i++) d += U[i][a] * U[i][b]; orth = Math.max(orth, Math.abs(d - (a === b ? 1 : 0))); }
    let lam = 0; const Au = new Float64Array(n);
    for (let i = 0; i < n; i++) { let t = 0; for (let j = 0; j < n; j++) t += Af[i * n + j] * U[j][a]; Au[i] = t; lam += U[i][a] * t; }
    rq.push(lam);
    for (let i = 0; i < n; i++) resid = Math.max(resid, Math.abs(Au[i] - lam * U[i][a]));
  }
  const inside = rq.every((l) => l >= Lq.toNumber() && l <= Uq.toNumber());
  add('basis', 'Stored basis is orthonormal and spans the window eigenspace', orth < 1e-12 && resid < 1e-9 && inside, `‖UᵀU − I‖ = ${orth.toExponential(1)}, residual ${resid.toExponential(1)}`);
  const ok = checks.every((c) => c.ok);
  return { ok, checks, exactCounts: exact, totalCounts: seps.length, scope, ms: performance.now() - t0, cert, topo, topoHash, certHash, tol: tol.toNumber(), g: g.toNumber() };
}
