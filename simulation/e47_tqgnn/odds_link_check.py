#!/usr/bin/env python3
"""Exact-integer cross-check of formal/e47/E47OddsLink.v.

Stdlib only (Python ints and, where a ratio is needed, fractions.Fraction).
Builds the same integer 125x125 sl2 model as E47MatrixProjector.v (per factor
Jz = diag(2,1,0,-1,-2), Jm e_k = e_{k+1}, Jp e_k = k(5-k) e_{k-1}, Kronecker sums,
C = Jz^2 + Jz + Jm*Jp) and checks the facts the Coq file proves, then runs the
odds bound on explicit integer vectors:

  * W = w1 (x) w1 (x) w1 with w1 = (1, 4, 24, 144, 576), w_{k+1} = (k+1)(4-k) w_k,
    is a positive integer diagonal weight; Jz is W-self-adjoint, Jp and Jm are
    W-adjoint to each other, hence C and every polynomial in C is W-self-adjoint
    (W*M symmetric).
  * Ehat_i = (Dd/d_i) N_i  (Dd = 12!)  satisfy Ehat_i^2 = Dd*Ehat_i, Ehat_i*Ehat_j = 0,
    sum Ehat_i = Dd*I, and W*Ehat_i is symmetric.
  * mass_i(x) = <Ehat_i x, Ehat_i x>_W >= 0 (= Dd^2 * squared W-norm of the level-i
    component), masses are W-orthogonal, sum_i mass_i(x) = Dd^2 <x,x>_W, and with
    G = D*I - K^2 (D = 99144, K = (C-6)(C-30)):  mass_i(G x) = num(c_i)^2 mass_i(x).
  * in(x) = mass_{6} + mass_{30}, out(x) = mass at 0,2,12,20,42:
    in(Gx) = D^2 in(x);  289*out(Gx)*in(x) <= 225*out(x)*in(Gx), and the k-step form
    289^k out(G^k x) in(x) <= 225^k out(x) in(G^k x) for k = 1..6; equality when all
    off-kernel mass sits at level 12 (or 42); and the naive bound on R fails.
Run: python3 simulation/e47_tqgnn/odds_link_check.py
"""
import random
from fractions import Fraction
from math import lcm

N = 125
NODES = [0, 2, 6, 12, 20, 30, 42]
D = 99144

# ---------- the integer sl2 model (same as E47MatrixProjector.v) ----------
def apply5(kind, v5):
    out = [0] * 5
    for k, a in enumerate(v5):
        if a == 0:
            continue
        if kind == "z":
            out[k] += (2 - k) * a
        elif kind == "m":              # Jm e_k = e_{k+1}
            if k <= 3:
                out[k + 1] += a
        elif kind == "p":              # Jp e_k = k(5-k) e_{k-1}
            if k >= 1:
                out[k - 1] += k * (5 - k) * a
    return out

def total(kind, v):
    """Kronecker sum a(x)1(x)1 + 1(x)a(x)1 + 1(x)1(x)a applied to v (length 125)."""
    out = [0] * N
    for pos in range(3):
        stride = (25, 5, 1)[pos]
        for base in range(N):
            if (base // stride) % 5 != 0:
                continue
            idx = [base + stride * t for t in range(5)]
            seg = apply5(kind, [v[i] for i in idx])
            for t, i in enumerate(idx):
                out[i] += seg[t]
    return out

def Jz(v): return total("z", v)
def Jp(v): return total("p", v)
def Jm(v): return total("m", v)
def add(u, v): return [a + b for a, b in zip(u, v)]
def sub(u, v): return [a - b for a, b in zip(u, v)]
def scal(k, v): return [k * a for a in v]
def Cop(v):
    z = Jz(v)
    return add(add(Jz(z), z), Jm(Jp(v)))

def unit(a):
    e = [0] * N
    e[a] = 1
    return e

def columns(op):
    return [op(unit(a)) for a in range(N)]

def to_rows(cols):
    return [[cols[j][i] for j in range(N)] for i in range(N)]

# ---------- weights ----------
w1 = [1]
for k in range(4):
    w1.append((k + 1) * (4 - k) * w1[-1])
assert w1 == [1, 4, 24, 144, 576]
ws = [w1[i] * w1[j] * w1[k] for i in range(5) for j in range(5) for k in range(5)]

def wb(u, v):
    return sum(w * a * b for w, a, b in zip(ws, u, v))

def symmetric_W(op):
    """W*M symmetric  <=>  M is W-self-adjoint, for M given as an operator on vectors."""
    cols = columns(op)
    return all(ws[i] * cols[j][i] == ws[j] * cols[i][j] for i in range(N) for j in range(N))

checks = {}
checks["w_{k+1} = (k+1)(4-k) w_k, all > 0"] = all(w > 0 for w in ws) and len(ws) == 125
# W Jm = (W Jp)^T : <e_i, Jm e_j>_W = <Jp e_i, e_j>_W
cm, cp = columns(Jm), columns(Jp)
checks["Jm, Jp are W-adjoint: W*Jm = (W*Jp)^T"] = all(
    ws[i] * cm[j][i] == ws[j] * cp[i][j] for i in range(N) for j in range(N))
checks["W*Jz symmetric"] = symmetric_W(Jz)
checks["W*C symmetric (C W-self-adjoint)"] = symmetric_W(Cop)

# ---------- spectral idempotents and the filter ----------
def poly(op, roots, v):
    for r in roots:
        v = sub(op(v), scal(r, v))
    return v

d = []
for i, c in enumerate(NODES):
    p = 1
    for l, c2 in enumerate(NODES):
        if l != i:
            p *= c - c2
    d.append(p)
Dd = lcm(*[abs(x) for x in d])
assert Dd == 479001600
mult_f = [Dd // d[i] for i in range(7)]
assert all(Dd % d[i] == 0 for i in range(7))

def Ehat(i, v):
    return scal(mult_f[i], poly(Cop, [c for l, c in enumerate(NODES) if l != i], v))

def Kop(v): return poly(Cop, [6, 30], v)
def Gop(v): return sub(scal(D, v), Kop(Kop(v)))
def num(c):
    k = (c - 6) * (c - 30)
    return D - k * k
nums = [num(c) for c in NODES]
assert nums == [66744, 86600, D, 87480, 79544, D, -87480]

Ecols = [columns(lambda v, i=i: Ehat(i, v)) for i in range(7)]
checks["Ehat_i^2 = Dd Ehat_i"] = all(
    Ehat(i, Ecols[i][a]) == scal(Dd, Ecols[i][a]) for i in range(7) for a in range(N))
checks["Ehat_i Ehat_j = 0 (i != j)"] = all(
    all(x == 0 for x in Ehat(i, Ecols[j][a]))
    for i in range(7) for j in range(7) if i != j for a in range(0, N, 1))
checks["sum Ehat_i = Dd I"] = all(
    [sum(Ecols[i][a][r] for i in range(7)) for r in range(N)] == scal(Dd, unit(a)) for a in range(N))
checks["W*Ehat_i symmetric (W-self-adjoint), i=0..6"] = all(
    ws[r] * Ecols[i][c][r] == ws[c] * Ecols[i][r][c]
    for i in range(7) for r in range(N) for c in range(N))
checks["Ehat_i * G = num(c_i) Ehat_i, i=0..6"] = all(
    Ehat(i, Gop(unit(a))) == scal(nums[i], Ecols[i][a]) for i in range(7) for a in range(N))
checks["G * Ehat_i = num(c_i) Ehat_i, i=0..6"] = all(
    Gop(Ecols[i][a]) == scal(nums[i], Ecols[i][a]) for i in range(7) for a in range(N))

# ---------- masses and the odds bound ----------
def masses(x):
    return [wb(Ehat(i, x), Ehat(i, x)) for i in range(7)]

IN, OUT = (2, 5), (0, 1, 3, 4, 6)
def inm(m): return m[2] + m[5]
def outm(m): return sum(m[i] for i in OUT)

def odds_checks(x, name, kmax=6):
    m = masses(x)
    ok = all(v >= 0 for v in m)
    # additivity and orthogonality
    ok &= sum(m) == Dd * Dd * wb(x, x)
    for i in range(7):
        for j in range(i + 1, 7):
            ok &= wb(Ehat(i, x), Ehat(j, x)) == 0
    y = x
    ms = [m]
    for k in range(1, kmax + 1):
        y = Gop(y)
        ms.append(masses(y))
    for k in range(1, kmax + 1):
        mk = ms[k]
        ok &= all(mk[i] == nums[i] ** 2 * ms[k - 1][i] for i in range(7))      # Gamma action
        ok &= inm(mk) == D * D * inm(ms[k - 1])                                  # in(Gx) = D^2 in(x)
        ok &= 289 * outm(mk) * inm(ms[k - 1]) <= 225 * outm(ms[k - 1]) * inm(mk)  # one step
        ok &= 289 ** k * outm(mk) * inm(m) <= 225 ** k * outm(m) * inm(mk)         # k steps
    return ok, ms

random.seed(47)
vectors = {
    "all ones": [1] * N,
    "e_0 (top weight)": unit(0),
    "e_62 (middle)": unit(62),
    "ramp 1..125": list(range(1, N + 1)),
}
for t in range(4):
    vectors["random ints #%d" % t] = [random.randint(-9, 9) for _ in range(N)]
for name, x in vectors.items():
    ok, _ = odds_checks(x, name)
    checks["odds bound k=1..6, masses, orthogonality, additivity: " + name] = ok

# equality case: kernel part + mass only at Casimir level 12 (resp. 42)
def level_vec(i, a=None):
    """First nonzero column of Ehat_i (an integer vector lying in the level-i block)."""
    if a is not None:
        return Ecols[i][a]
    return next(c for c in Ecols[i] if any(c))
for lvl, nm in ((3, 12), (6, 42)):
    x = add(level_vec(2), level_vec(lvl))
    ok, ms = odds_checks(x, "eq%d" % nm)
    m0, m1 = ms[0], ms[1]
    eq = (m0[2] > 0 and m0[lvl] > 0 and
          all(m0[i] == 0 for i in OUT if i != lvl) and
          289 * outm(m1) == 225 * D * D * outm(m0))
    checks["equality case, all off-kernel mass at Casimir %d (k=1)" % nm] = ok and eq

# the naive bound R_1 <= (225/289) R_0 fails on that state (the odds bound holds)
x = add(level_vec(2), level_vec(3))
m0 = masses(x); m1 = masses(Gop(x))
R0 = Fraction(outm(m0), inm(m0) + outm(m0)); R1 = Fraction(outm(m1), inm(m1) + outm(m1))
checks["naive bound R1 <= (225/289) R0 FAILS on a concrete integer vector"] = R1 > Fraction(225, 289) * R0
odds0 = Fraction(outm(m0), inm(m0)); odds1 = Fraction(outm(m1), inm(m1))
checks["odds bound holds there: odds1 <= (225/289) odds0"] = odds1 <= Fraction(225, 289) * odds0

for name, ok in checks.items():
    print(("PASS " if ok else "FAIL ") + name)
bad = [n for n, ok in checks.items() if not ok]
print("ODDS_LINK_%s %d / %d" % ("PASS" if not bad else "FAIL", len(checks) - len(bad), len(checks)))
assert not bad, "odds link check failed"
