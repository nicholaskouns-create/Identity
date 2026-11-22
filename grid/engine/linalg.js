// KKP-GRID dense linear algebra (float64, row-major Float64Array, square n×n).
// Three independent symmetric eigensolvers so the replicas do not share code:
//   jacobiEigen   cyclic Jacobi rotations                       (replica R1)
//   tredTql       Householder tridiagonalisation + implicit QL  (replica R2, reference pipelines)
//   lanczosEigen  Lanczos with full reorthogonalisation         (replica R5)
// plus LU, Cholesky, matrix sign iteration and orthonormalisation for R3/R4.

export const eye = (n) => { const I = new Float64Array(n * n); for (let i = 0; i < n; i++) I[i * n + i] = 1; return I; };

export function matvec(A, n, x) {
  const y = new Float64Array(n);
  for (let i = 0; i < n; i++) { let s = 0; const o = i * n; for (let j = 0; j < n; j++) s += A[o + j] * x[j]; y[i] = s; }
  return y;
}

export function norm2(x) { let s = 0; for (let i = 0; i < x.length; i++) s += x[i] * x[i]; return Math.sqrt(s); }
export function sub(a, b) { const c = new Float64Array(a.length); for (let i = 0; i < a.length; i++) c[i] = a[i] - b[i]; return c; }
export function dist(a, b) { let s = 0; for (let i = 0; i < a.length; i++) { const d = a[i] - b[i]; s += d * d; } return Math.sqrt(s); }

export function norm1(A, n) {
  let m = 0;
  for (let j = 0; j < n; j++) { let s = 0; for (let i = 0; i < n; i++) s += Math.abs(A[i * n + j]); if (s > m) m = s; }
  return m;
}

function sortEig(w, V, n) {
  const idx = Array.from(w, (_, i) => i).sort((a, b) => w[a] - w[b]);
  const w2 = new Float64Array(n), V2 = new Float64Array(n * n);
  idx.forEach((k, c) => { w2[c] = w[k]; for (let i = 0; i < n; i++) V2[i * n + c] = V[i * n + k]; });
  return { w: w2, V: V2 };
}

// ---------------------------------------------------------------- R1: Jacobi
export function jacobiEigen(A0, n, maxSweeps = 60) {
  const A = Float64Array.from(A0), V = eye(n);
  let fro = 0; for (let k = 0; k < n * n; k++) fro += A[k] * A[k];
  for (let sweep = 0; sweep < maxSweeps; sweep++) {
    let off = 0;
    for (let p = 0; p < n - 1; p++) for (let q = p + 1; q < n; q++) off += A[p * n + q] * A[p * n + q];
    if (off <= 1e-32 * fro) break;
    for (let p = 0; p < n - 1; p++) {
      for (let q = p + 1; q < n; q++) {
        const apq = A[p * n + q];
        if (Math.abs(apq) < 1e-300) continue;
        const theta = (A[q * n + q] - A[p * n + p]) / (2 * apq);
        const t = (theta >= 0 ? 1 : -1) / (Math.abs(theta) + Math.sqrt(theta * theta + 1));
        const c = 1 / Math.sqrt(t * t + 1), s = t * c;
        for (let k = 0; k < n; k++) {
          const akp = A[k * n + p], akq = A[k * n + q];
          A[k * n + p] = c * akp - s * akq; A[k * n + q] = s * akp + c * akq;
        }
        for (let k = 0; k < n; k++) {
          const apk = A[p * n + k], aqk = A[q * n + k];
          A[p * n + k] = c * apk - s * aqk; A[q * n + k] = s * apk + c * aqk;
        }
        for (let k = 0; k < n; k++) {
          const vkp = V[k * n + p], vkq = V[k * n + q];
          V[k * n + p] = c * vkp - s * vkq; V[k * n + q] = s * vkp + c * vkq;
        }
      }
    }
  }
  const w = new Float64Array(n); for (let i = 0; i < n; i++) w[i] = A[i * n + i];
  return sortEig(w, V, n);
}

// ------------------------------------------------- R2: Householder + implicit QL (JAMA lineage)
function tred2(V, d, e, n, accumulate = true) {
  for (let j = 0; j < n; j++) d[j] = V[(n - 1) * n + j];
  for (let i = n - 1; i > 0; i--) {
    let scale = 0, h = 0;
    for (let k = 0; k < i; k++) scale += Math.abs(d[k]);
    if (scale === 0) {
      e[i] = d[i - 1];
      for (let j = 0; j < i; j++) { d[j] = V[(i - 1) * n + j]; V[i * n + j] = 0; V[j * n + i] = 0; }
    } else {
      for (let k = 0; k < i; k++) { d[k] /= scale; h += d[k] * d[k]; }
      let f = d[i - 1];
      let g = Math.sqrt(h);
      if (f > 0) g = -g;
      e[i] = scale * g;
      h -= f * g;
      d[i - 1] = f - g;
      for (let j = 0; j < i; j++) e[j] = 0;
      for (let j = 0; j < i; j++) {
        f = d[j];
        V[j * n + i] = f;
        g = e[j] + V[j * n + j] * f;
        for (let k = j + 1; k <= i - 1; k++) { g += V[k * n + j] * d[k]; e[k] += V[k * n + j] * f; }
        e[j] = g;
      }
      f = 0;
      for (let j = 0; j < i; j++) { e[j] /= h; f += e[j] * d[j]; }
      const hh = f / (h + h);
      for (let j = 0; j < i; j++) e[j] -= hh * d[j];
      for (let j = 0; j < i; j++) {
        f = d[j]; g = e[j];
        for (let k = j; k <= i - 1; k++) V[k * n + j] -= (f * e[k] + g * d[k]);
        d[j] = V[(i - 1) * n + j];
        V[i * n + j] = 0;
      }
    }
    d[i] = h;
  }
  if (!accumulate) { for (let i = 0; i < n; i++) d[i] = V[i * n + i]; e[0] = 0; return; }
  for (let i = 0; i < n - 1; i++) {
    V[(n - 1) * n + i] = V[i * n + i];
    V[i * n + i] = 1;
    const h = d[i + 1];
    if (h !== 0) {
      for (let k = 0; k <= i; k++) d[k] = V[k * n + i + 1] / h;
      for (let j = 0; j <= i; j++) {
        let g = 0;
        for (let k = 0; k <= i; k++) g += V[k * n + i + 1] * V[k * n + j];
        for (let k = 0; k <= i; k++) V[k * n + j] -= g * d[k];
      }
    }
    for (let k = 0; k <= i; k++) V[k * n + i + 1] = 0;
  }
  for (let j = 0; j < n; j++) { d[j] = V[(n - 1) * n + j]; V[(n - 1) * n + j] = 0; }
  V[(n - 1) * n + n - 1] = 1;
  e[0] = 0;
}

function tql2(V, d, e, n) {
  for (let i = 1; i < n; i++) e[i - 1] = e[i];
  e[n - 1] = 0;
  let f = 0, tst1 = 0;
  const eps = Math.pow(2, -52);
  for (let l = 0; l < n; l++) {
    tst1 = Math.max(tst1, Math.abs(d[l]) + Math.abs(e[l]));
    let m = l;
    while (m < n) { if (Math.abs(e[m]) <= eps * tst1) break; m++; }
    if (m > l) {
      let iter = 0;
      do {
        iter++;
        let g = d[l];
        let p = (d[l + 1] - g) / (2 * e[l]);
        let r = Math.hypot(p, 1);
        if (p < 0) r = -r;
        d[l] = e[l] / (p + r);
        d[l + 1] = e[l] * (p + r);
        const dl1 = d[l + 1];
        let h = g - d[l];
        for (let i = l + 2; i < n; i++) d[i] -= h;
        f += h;
        p = d[m];
        let c = 1, c2 = c, c3 = c;
        const el1 = e[l + 1];
        let s = 0, s2 = 0;
        for (let i = m - 1; i >= l; i--) {
          c3 = c2; c2 = c; s2 = s;
          g = c * e[i];
          h = c * p;
          r = Math.hypot(p, e[i]);
          e[i + 1] = s * r;
          s = e[i] / r;
          c = p / r;
          p = c * d[i] - s * g;
          d[i + 1] = h + s * (c * g + s * d[i]);
          if (V) for (let k = 0; k < n; k++) {
            h = V[k * n + i + 1];
            V[k * n + i + 1] = s * V[k * n + i] + c * h;
            V[k * n + i] = c * V[k * n + i] - s * h;
          }
        }
        p = -s * s2 * c3 * el1 * e[l] / dl1;
        e[l] = s * p;
        d[l] = c * p;
      } while (Math.abs(e[l]) > eps * tst1 && iter < 80);
    }
    d[l] += f;
    e[l] = 0;
  }
}

export function tredTql(A0, n) {
  const V = Float64Array.from(A0), d = new Float64Array(n), e = new Float64Array(n);
  tred2(V, d, e, n);
  tql2(V, d, e, n);
  return sortEig(d, V, n);
}

export function eigvalsSym(A0, n) {
  const V = Float64Array.from(A0), d = new Float64Array(n), e = new Float64Array(n);
  tred2(V, d, e, n, false);
  tql2(null, d, e, n);
  return Float64Array.from(d).sort();
}

export function spectralNormSym(A, n) { const w = eigvalsSym(A, n); return Math.max(Math.abs(w[0]), Math.abs(w[n - 1])); }

// ------------------------------------------- R5: Lanczos with full reorthogonalisation
export function lanczosEigen(A, n, v0) {
  const Q = new Float64Array(n * n);
  const alpha = new Float64Array(n), beta = new Float64Array(n);
  let q = Float64Array.from(v0);
  let nq = norm2(q); for (let i = 0; i < n; i++) q[i] /= nq;
  const scaleA = norm1(A, n) || 1;
  for (let k = 0; k < n; k++) {
    for (let i = 0; i < n; i++) Q[i * n + k] = q[i];
    const w = matvec(A, n, q);
    let a = 0; for (let i = 0; i < n; i++) a += q[i] * w[i];
    alpha[k] = a;
    for (let pass = 0; pass < 2; pass++) {
      for (let j = 0; j <= k; j++) {
        let c = 0; for (let i = 0; i < n; i++) c += Q[i * n + j] * w[i];
        for (let i = 0; i < n; i++) w[i] -= c * Q[i * n + j];
      }
    }
    if (k === n - 1) break;
    let b = norm2(w);
    if (b < 1e-12 * scaleA) {
      // invariant subspace found: continue with a fresh direction orthogonal to Q
      w.fill(0); w[(7 * k + 3) % n] = 1; w[(11 * k + 5) % n] += 0.5;
      for (let pass = 0; pass < 2; pass++) for (let j = 0; j <= k; j++) {
        let c = 0; for (let i = 0; i < n; i++) c += Q[i * n + j] * w[i];
        for (let i = 0; i < n; i++) w[i] -= c * Q[i * n + j];
      }
      const nb = norm2(w); for (let i = 0; i < n; i++) w[i] /= nb;
      beta[k] = 0;
    } else {
      for (let i = 0; i < n; i++) w[i] /= b;
      beta[k] = b;
    }
    q = w;
  }
  // T = tridiag(beta, alpha, beta): project alpha back onto exact Rayleigh quotients with Q
  const S = eye(n), d = Float64Array.from(alpha), e = new Float64Array(n);
  for (let i = 1; i < n; i++) e[i] = beta[i - 1];
  tql2(S, d, e, n);
  const { w, V: Ss } = sortEig(d, S, n);
  const X = new Float64Array(n * n);
  for (let i = 0; i < n; i++) for (let c = 0; c < n; c++) {
    let s = 0; for (let k = 0; k < n; k++) s += Q[i * n + k] * Ss[k * n + c]; X[i * n + c] = s;
  }
  return { w, V: X };
}

// ------------------------------------------------------------------ LU and friends
export function luFactor(A0, n) {
  const A = Float64Array.from(A0), piv = new Int32Array(n);
  for (let i = 0; i < n; i++) piv[i] = i;
  let logdet = 0;
  for (let k = 0; k < n; k++) {
    let p = k, max = Math.abs(A[k * n + k]);
    for (let i = k + 1; i < n; i++) { const v = Math.abs(A[i * n + k]); if (v > max) { max = v; p = i; } }
    if (p !== k) {
      for (let j = 0; j < n; j++) { const t = A[k * n + j]; A[k * n + j] = A[p * n + j]; A[p * n + j] = t; }
      const t = piv[k]; piv[k] = piv[p]; piv[p] = t;
    }
    const akk = A[k * n + k];
    logdet += Math.log(Math.abs(akk));
    if (akk === 0) continue;
    for (let i = k + 1; i < n; i++) {
      const f = (A[i * n + k] /= akk);
      if (f !== 0) for (let j = k + 1; j < n; j++) A[i * n + j] -= f * A[k * n + j];
    }
  }
  return { LU: A, piv, logdet, n };
}

export function luSolve(F, b) {
  const { LU, piv, n } = F, x = new Float64Array(n);
  for (let i = 0; i < n; i++) { let s = b[piv[i]]; for (let j = 0; j < i; j++) s -= LU[i * n + j] * x[j]; x[i] = s; }
  for (let i = n - 1; i >= 0; i--) { let s = x[i]; for (let j = i + 1; j < n; j++) s -= LU[i * n + j] * x[j]; x[i] = s / LU[i * n + i]; }
  return x;
}

export function inverseFromLU(F) {
  const n = F.n, X = new Float64Array(n * n), e = new Float64Array(n);
  for (let j = 0; j < n; j++) {
    e.fill(0); e[j] = 1;
    const c = luSolve(F, e);
    for (let i = 0; i < n; i++) X[i * n + j] = c[i];
  }
  return X;
}

// Scaled Newton iteration for the matrix sign function (R3 and the independent reference).
export function signNewton(M, n, maxIter = 40) {
  let X = Float64Array.from(M);
  for (let it = 0; it < maxIter; it++) {
    const F = luFactor(X, n);
    const mu = Number.isFinite(F.logdet) ? Math.exp(-F.logdet / n) : 1;
    const Xi = inverseFromLU(F);
    const Xn = new Float64Array(n * n);
    for (let k = 0; k < n * n; k++) Xn[k] = 0.5 * (mu * X[k] + Xi[k] / mu);
    const D = new Float64Array(n * n); for (let k = 0; k < n * n; k++) D[k] = Xn[k] - X[k];
    X = Xn;
    if (norm1(D, n) <= 1e-14 * norm1(Xn, n)) break;
  }
  return X;
}

export function cholSolve(A, n, b) {
  const L = new Float64Array(n * n);
  for (let j = 0; j < n; j++) {
    let s = A[j * n + j];
    for (let k = 0; k < j; k++) s -= L[j * n + k] * L[j * n + k];
    if (s <= 0) throw new Error('matrix not positive definite');
    const ljj = Math.sqrt(s); L[j * n + j] = ljj;
    for (let i = j + 1; i < n; i++) {
      let t = A[i * n + j];
      for (let k = 0; k < j; k++) t -= L[i * n + k] * L[j * n + k];
      L[i * n + j] = t / ljj;
    }
  }
  const y = new Float64Array(n);
  for (let i = 0; i < n; i++) { let s = b[i]; for (let k = 0; k < i; k++) s -= L[i * n + k] * y[k]; y[i] = s / L[i * n + i]; }
  for (let i = n - 1; i >= 0; i--) { let s = y[i]; for (let k = i + 1; k < n; k++) s -= L[k * n + i] * y[k]; y[i] = s / L[i * n + i]; }
  return y;
}

// Orthonormalise the r columns of V (n×r, row-major) by modified Gram–Schmidt, twice.
export function orthonormalize(V, n, r) {
  for (let pass = 0; pass < 2; pass++) {
    for (let c = 0; c < r; c++) {
      for (let p = 0; p < c; p++) {
        let d = 0; for (let i = 0; i < n; i++) d += V[i * r + c] * V[i * r + p];
        for (let i = 0; i < n; i++) V[i * r + c] -= d * V[i * r + p];
      }
      let s = 0; for (let i = 0; i < n; i++) s += V[i * r + c] * V[i * r + c];
      s = Math.sqrt(s); for (let i = 0; i < n; i++) V[i * r + c] /= s;
    }
  }
  return V;
}

// y = U (U^T x) for an n×r orthonormal basis U.
export function projectBasis(U, n, r, x) {
  const c = new Float64Array(r);
  for (let k = 0; k < r; k++) { let s = 0; for (let i = 0; i < n; i++) s += U[i * r + k] * x[i]; c[k] = s; }
  const y = new Float64Array(n);
  for (let i = 0; i < n; i++) { let s = 0; for (let k = 0; k < r; k++) s += U[i * r + k] * c[k]; y[i] = s; }
  return y;
}

// Columns cols of an n×n eigenvector matrix as an n×r basis.
export function pickColumns(V, n, cols) {
  const r = cols.length, U = new Float64Array(n * r);
  for (let i = 0; i < n; i++) cols.forEach((c, k) => { U[i * r + k] = V[i * n + c]; });
  return U;
}
