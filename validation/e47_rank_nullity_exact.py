"""
E47-CORE-002 :: derive 47 and 78 from the spectrum, do not assume them.

Numerical companion to formal/e47/unified/RankNullity47.{lean,v}.
Those two files prove rank + nullity = carrier symbolically from the
coupling.  This file does the matrix statement they do not: it builds the
actual 125x125 Casimir, forms K = (C - 6I)(C - 30I), conjugates it to a
DENSE integer matrix, and recovers rank 78 by exact rational elimination.
Exits nonzero on any disagreement.

INPUTS (the only things asserted):
  - spin content j = 0..6 with multiplicities m = (1,9,25,28,27,22,13)
  - the annihilating polynomial p(x) = (x - 6)(x - 30)

OUTPUTS (computed, never written down in advance):
  - carrier dimension N
  - dim ker K
  - rank K
"""
from fractions import Fraction
import random

# ---- INPUT 1: the coupling 2 (x) 2 (x) 2 -----------------------------------
# Same construction as formal/e47/E47Spectral.py/.lean/.v -- the multiplicity
# vector is NOT written down, it is produced by Clebsch-Gordan.
def couple(j1, j2):
    return list(range(abs(j1 - j2), j1 + j2 + 1))

threeSpin2 = [j for k in couple(2, 2) for j in couple(k, 2)]
MULT = {j: threeSpin2.count(j) * (2 * j + 1) for j in sorted(set(threeSpin2))}
casimir = lambda j: j * (j + 1)           # su(2) Casimir eigenvalue on spin j

# ---- INPUT 2: annihilating polynomial --------------------------------------
ROOTS = (6, 30)
p = lambda x: (x - ROOTS[0]) * (x - ROOTS[1])

# ---- build the carrier -----------------------------------------------------
spectrum = []                              # one eigenvalue per basis vector
for j in sorted(MULT):
    spectrum += [casimir(j)] * MULT[j]
N = len(spectrum)                          # <-- carrier dimension, COMPUTED

C = [[0] * N for _ in range(N)]
for i, lam in enumerate(spectrum):
    C[i][i] = lam

# ---- K = p(C) = (C - 6I)(C - 30I) ------------------------------------------
def matmul(A, B):
    n = len(A)
    Bt = list(zip(*B))
    return [[sum(a * b for a, b in zip(row, col)) for col in Bt] for row in A]

def shift(M, s):
    return [[M[i][k] - (s if i == k else 0) for k in range(len(M))] for i in range(len(M))]

K = matmul(shift(C, ROOTS[0]), shift(C, ROOTS[1]))

# ---- conjugate by a unimodular U so K is DENSE, not diagonal ----------------
# rank is a similarity invariant; this makes the elimination do real work.
random.seed(47)
U  = [[1 if i == k else 0 for k in range(N)] for i in range(N)]
Ui = [[1 if i == k else 0 for k in range(N)] for i in range(N)]
for _ in range(4 * N):                     # random elementary row ops, det = 1
    i, k = random.sample(range(N), 2)
    c = random.choice([-1, 1])
    for col in range(N):
        U[i][col]  += c * U[k][col]        # U  <- E U
        Ui[col][k] -= c * Ui[col][i]       # Ui <- Ui E^-1
Kd = matmul(matmul(U, K), Ui)              # similar to K, dense

assert matmul(U, Ui) == [[1 if i == k else 0 for k in range(N)] for i in range(N)], "U not unimodular"
density = sum(1 for r in Kd for v in r if v) / (N * N)

# ---- exact rank by fraction-free Gaussian elimination ----------------------
def exact_rank(M):
    A = [[Fraction(v) for v in row] for row in M]
    rows, cols = len(A), len(A[0])
    r = 0
    for c in range(cols):
        piv = next((i for i in range(r, rows) if A[i][c] != 0), None)
        if piv is None:
            continue
        A[r], A[piv] = A[piv], A[r]
        inv = A[r][c]
        A[r] = [v / inv for v in A[r]]
        for i in range(rows):
            if i != r and A[i][c] != 0:
                f = A[i][c]
                A[i] = [a - f * b for a, b in zip(A[i], A[r])]
        r += 1
        if r == rows:
            break
    return r

rank_K    = exact_rank(Kd)                 # <-- COMPUTED
nullity_K = N - rank_K                     # <-- COMPUTED

# ---- independent cross-check: nullity by spectrum ---------------------------
nullity_spec = sum(m for j, m in MULT.items() if p(casimir(j)) == 0)
annihilated  = [j for j in sorted(MULT) if p(casimir(j)) == 0]

print(f"carrier dimension N            = {N}   (= sum of multiplicities)")
print(f"K = p(C) conjugated, density   = {density:6.1%} nonzero entries")
print(f"rank K   (exact elimination)   = {rank_K}")
print(f"dim ker K = N - rank K         = {nullity_K}")
print(f"rank + nullity                 = {rank_K + nullity_K}  ==  N : {rank_K + nullity_K == N}")
print()
print(f"annihilated spins              = {annihilated}  -> Casimir {[casimir(j) for j in annihilated]}")
print(f"nullity from spectrum          = {' + '.join(str(MULT[j]) for j in annihilated)} = {nullity_spec}")
print(f"matches elimination            : {nullity_spec == nullity_K}")
print()
print(f"VERDICT  rank {rank_K} + ker {nullity_K} = {N}   [47 and 78 derived, not defined]")

import sys
ok = (N == 125 and rank_K == 78 and nullity_K == 47
      and nullity_spec == nullity_K and rank_K + nullity_K == N)
if not ok:
    print("FAILED: a derived value disagrees with the matrix.")
sys.exit(0 if ok else 1)
