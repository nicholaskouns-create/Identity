#!/usr/bin/env python3
"""Exact-integer cross-check of formal/e47/E47MatrixProjector.v (and .lean).

Builds the integer sl2 model of three spin-2 particles (unnormalized ladder
basis, no square roots), the 125x125 Casimir C = Jz^2 + Jz + Jm*Jp, and checks
with Python ints (numpy dtype=object, no floating point) the same identities
the Coq file proves by vm_compute:
  sl2 relations, 2C symmetric form, weight counts, M(C) = 0,
  A = pr(C): A*A = 1814400*A, trace A = 47*1814400, K*A = 0,
  power traces vs the weight-algebra multiplicities, spectral idempotents
  (and, beyond the Coq file, N_i*N_l = 0 for i != l).
The only floating-point step is the optional eigenvalue sanity print at the end.
Run: python3 simulation/e47_tqgnn/matrix_projector_check.py
"""
from math import lcm
import numpy as np

O = object
def mat(rows):
    return np.array(rows, dtype=O)

Jz5 = np.zeros((5, 5), dtype=O)
Jp5 = np.zeros((5, 5), dtype=O)
Jm5 = np.zeros((5, 5), dtype=O)
for k in range(5):
    Jz5[k, k] = 2 - k
    if k >= 1:
        Jp5[k - 1, k] = k * (5 - k)      # (j-m)(j+m+1) with m = 2-k
    if k <= 3:
        Jm5[k + 1, k] = 1
I5 = mat([[int(i == j) for j in range(5)] for i in range(5)])

def kron(a, b):
    return np.array(np.kron(a, b), dtype=O)

def tot(a):
    return kron(kron(a, I5), I5) + kron(kron(I5, a), I5) + kron(kron(I5, I5), a)

Jz, Jp, Jm = tot(Jz5), tot(Jp5), tot(Jm5)
I = mat([[int(i == j) for j in range(125)] for i in range(125)])
Z0 = I * 0

def mm(a, b):
    return a.dot(b)

def comm(x, y):
    return mm(x, y) - mm(y, x)

def tr(a):
    return sum(a[i, i] for i in range(125))

def prod_poly(C, roots):
    R = I
    for r in roots:
        R = mm(R, C - r * I)
    return R

def is_zero(a):
    return not a.any()

checks = {}
C = mm(Jz, Jz) + Jz + mm(Jm, Jp)
checks["dimensions 125x125"] = all(m.shape == (125, 125) for m in (Jz, Jp, Jm, C))
checks["[Jz,Jp]=Jp"] = (comm(Jz, Jp) == Jp).all()
checks["[Jz,Jm]=-Jm"] = (comm(Jz, Jm) == -Jm).all()
checks["[Jp,Jm]=2Jz"] = (comm(Jp, Jm) == 2 * Jz).all()
checks["2C = 2Jz^2 + JpJm + JmJp"] = (2 * C == 2 * mm(Jz, Jz) + mm(Jp, Jm) + mm(Jm, Jp)).all()

diag = [Jz[i, i] for i in range(125)]
checks["Jz is diagonal"] = (Jz == np.diag(diag).astype(O)).all()
w = {m: diag.count(m) for m in range(-6, 7)}
checks["weight counts 19,18,15,10,6,3,1"] = [w[m] for m in range(7)] == [19, 18, 15, 10, 6, 3, 1]
mult = [w[j] - w[j + 1] if j < 6 else w[6] for j in range(7)]
checks["multiplicities 1,3,5,4,3,2,1"] = mult == [1, 3, 5, 4, 3, 2, 1]

nodes = [0, 2, 6, 12, 20, 30, 42]
checks["M(C)=0"] = is_zero(prod_poly(C, nodes))

A = prod_poly(C, [0, 2, 12, 20, 31, 42])
K = prod_poly(C, [6, 30])
checks["A*A = 1814400 A"] = (mm(A, A) == 1814400 * A).all()
checks["trace A = 47*1814400"] = tr(A) == 47 * 1814400
checks["K*A = 0"] = is_zero(mm(K, A))

pw = [I]
for _ in range(6):
    pw.append(mm(pw[-1], C))
coeffs = [1, -107, 4088, -66940, 430848, -624960, 0]
Aexp = sum(c * pw[6 - i] for i, c in enumerate(coeffs))
checks["A = expanded polynomial"] = (A == Aexp).all()
dims = [mult[j] * (2 * j + 1) for j in range(7)]
checks["power traces k=0..6"] = all(
    tr(pw[k]) == sum(dims[j] * (j * (j + 1)) ** k for j in range(7)) for k in range(7))

d = []
N = []
for i, c in enumerate(nodes):
    others = [x for l, x in enumerate(nodes) if l != i]
    p = 1
    for x in others:
        p *= c - x
    d.append(p)
    N.append(prod_poly(C, others))
Dd = lcm(*[abs(x) for x in d])
checks["Dd = 12!"] = Dd == 479001600
checks["N_i^2 = d_i N_i"] = all((mm(N[i], N[i]) == d[i] * N[i]).all() for i in range(7))
checks["trace N_i = d_i * dim_i"] = all(tr(N[i]) == d[i] * dims[i] for i in range(7))
checks["dims 1,9,25,28,27,22,13"] = dims == [1, 9, 25, 28, 27, 22, 13]
checks["sum (Dd/d_i) N_i = Dd I"] = all(Dd % d[i] == 0 for i in range(7)) and (
    sum((Dd // d[i]) * N[i] for i in range(7)) == Dd * I).all()
checks["d2 d5 A = 1814400 (d5 N2 + d2 N5)"] = (
    d[2] * d[5] * A == 1814400 * (d[5] * N[2] + d[2] * N[5])).all()
checks["N_i N_l = 0 (i != l)"] = all(
    is_zero(mm(N[i], N[l])) for i in range(7) for l in range(7) if i != l)

for name, ok in checks.items():
    print(("PASS " if ok else "FAIL ") + name)
assert all(checks.values()), "matrix projector check failed"
ev = np.sort(np.linalg.eigvals(C.astype(float)).real)
vals, cnts = np.unique(np.rint(ev).astype(int), return_counts=True)
print("float sanity: eigenvalue counts", {int(v): int(c) for v, c in zip(vals, cnts)})
print("MATRIX_PROJECTOR_PASS", len(checks), "/", len(checks))
