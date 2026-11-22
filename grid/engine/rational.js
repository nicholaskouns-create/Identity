// Exact rationals over BigInt and exact inertia counts (Sylvester) for the
// general-branch certificate. Twin of count_below in tools/grid/build_grid_data.py.

const babs = (a) => (a < 0n ? -a : a);
function gcd(a, b) { a = babs(a); b = babs(b); while (b) { const t = a % b; a = b; b = t; } return a; }

export class Q {
  constructor(n, d = 1n) {
    if (d === 0n) throw new Error('zero denominator');
    if (d < 0n) { n = -n; d = -d; }
    const g = gcd(n, d);
    this.n = g > 1n ? n / g : n;
    this.d = g > 1n ? d / g : d;
  }
  static of(v) { return v instanceof Q ? v : Q.parse(String(v)); }
  static parse(s) {
    s = String(s).trim();
    if (s.includes('/')) { const [a, b] = s.split('/'); return new Q(BigInt(a.trim()), BigInt(b.trim())); }
    let neg = false;
    if (s[0] === '-') { neg = true; s = s.slice(1); } else if (s[0] === '+') s = s.slice(1);
    let exp = 0;
    const e = s.search(/[eE]/);
    if (e >= 0) { exp = parseInt(s.slice(e + 1), 10); s = s.slice(0, e); }
    const [ip, fp = ''] = s.split('.');
    let num = BigInt((ip || '0') + fp);
    let den = 10n ** BigInt(fp.length);
    if (exp > 0) num *= 10n ** BigInt(exp); else if (exp < 0) den *= 10n ** BigInt(-exp);
    return new Q(neg ? -num : num, den);
  }
  add(o) { return new Q(this.n * o.d + o.n * this.d, this.d * o.d); }
  sub(o) { return new Q(this.n * o.d - o.n * this.d, this.d * o.d); }
  mul(o) { return new Q(this.n * o.n, this.d * o.d); }
  div(o) { return new Q(this.n * o.d, this.d * o.n); }
  neg() { return new Q(-this.n, this.d); }
  sign() { return this.n > 0n ? 1 : this.n < 0n ? -1 : 0; }
  isZero() { return this.n === 0n; }
  cmp(o) { const a = this.n * o.d, b = o.n * this.d; return a > b ? 1 : a < b ? -1 : 0; }
  eq(o) { return this.n === o.n && this.d === o.d; }
  toString() { return this.d === 1n ? `${this.n}` : `${this.n}/${this.d}`; }
  toNumber() { return Number(this.n) / Number(this.d); }
}

export const ZERO = new Q(0n), ONE = new Q(1n);
export const minQ = (a, b) => (a.cmp(b) <= 0 ? a : b);

/** Exact sparse operator from a topology model: rows of Map<col, Q>. */
export function exactOperator(topo) {
  const idx = new Map(topo.buses.map((b, i) => [b[0], i]));
  const n = topo.buses.length;
  const A = Array.from({ length: n }, () => new Map());
  const addTo = (i, j, v) => { A[i].set(j, (A[i].get(j) || ZERO).add(v)); };
  for (const [f, t, x, tap, st] of topo.branches) {
    if (st === 0) continue;
    const tq = Q.parse(tap);
    const tau = tq.isZero() ? ONE : tq;
    const b = ONE.div(Q.parse(x).mul(tau));
    const i = idx.get(f), j = idx.get(t);
    addTo(i, i, b); addTo(j, j, b); addTo(i, j, b.neg()); addTo(j, i, b.neg());
  }
  return { A, n };
}

export function rowSumsZero(A) { return A.every((row) => [...row.values()].reduce((s, v) => s.add(v), ZERO).isZero()); }

/** Number of eigenvalues strictly below sigma (null on a zero pivot). */
export function countBelow(A, n, sigma, order) {
  const pos = new Int32Array(n); order.forEach((v, k) => { pos[v] = k; });
  let M = Array.from({ length: n }, () => new Map());
  for (let i = 0; i < n; i++) for (const [j, v] of A[i]) M[pos[i]].set(pos[j], v);
  for (let i = 0; i < n; i++) M[pos[i]].set(pos[i], (M[pos[i]].get(pos[i]) || ZERO).sub(sigma));
  let neg = 0;
  for (let k = 0; k < n; k++) {
    const d = M[k].get(k) || ZERO;
    if (d.isZero()) return null;
    if (d.sign() < 0) neg += 1;
    const row = [];
    for (const [j, v] of M[k]) if (j > k) row.push([j, v]);
    for (const [i, aik] of row) {
      const f = aik.div(d), Mi = M[i];
      for (const [j, akj] of row) {
        if (j < i) continue;
        const nv = (Mi.get(j) || ZERO).sub(f.mul(akj));
        Mi.set(j, nv);
        if (j !== i) M[j].set(i, nv);
      }
    }
    M[k] = null;
  }
  return neg;
}
