"""
Exact certificate generator for the E47 kernel theorem.

Mirrors the integer sl2 model of formal/e47/E47MatrixProjector.v exactly:
  per factor (index k = 0..4, m = 2-k):
    Jz e_k = (2-k) e_k,  Jm e_k = e_{k+1},  Jp e_k = k(5-k) e_{k-1}
  three-fold Kronecker sums, global index 25*k1 + 5*k2 + k3,
  C = Jz^2 + Jz + Jm*Jp.

Emits, for each Casimir level c_i and for ker K, a basis in REDUCED form:
  B[P, :] = beta * I   (P = pivot rows = free variables of the RREF)
so that injectivity is a pivot check and spanning is the single identity
  beta * E = B * E[P, :]   for the scaled spectral idempotent E.

Everything is exact (integers / Fractions). Standard library only.
"""
from fractions import Fraction
from math import lcm, prod
import json, hashlib, sys, os

N = 125
NODES = [0, 2, 6, 12, 20, 30, 42]
DD = 479001600            # 12! -- the Dd of E47MatrixProjector.v

# ---------------------------------------------------------------- model
def zeros(r, c): return [[0]*c for _ in range(r)]
def eye(n): return [[1 if i == j else 0 for j in range(n)] for i in range(n)]

def kron(A, B):
    ra, ca, rb, cb = len(A), len(A[0]), len(B), len(B[0])
    return [[A[i//rb][j//cb] * B[i % rb][j % cb] for j in range(ca*cb)] for i in range(ra*rb)]

def madd(A, B): return [[a+b for a, b in zip(r, s)] for r, s in zip(A, B)]
def mscale(k, A): return [[k*a for a in r] for r in A]
def mmul(A, B):
    Bt = list(zip(*B))
    return [[sum(a*b for a, b in zip(r, c)) for c in Bt] for r in A]

Jz5 = [[2,0,0,0,0],[0,1,0,0,0],[0,0,0,0,0],[0,0,0,-1,0],[0,0,0,0,-2]]
Jp5 = [[0,4,0,0,0],[0,0,6,0,0],[0,0,0,6,0],[0,0,0,0,4],[0,0,0,0,0]]
Jm5 = [[0,0,0,0,0],[1,0,0,0,0],[0,1,0,0,0],[0,0,1,0,0],[0,0,0,1,0]]
I5 = eye(5)
def Jtot(a):
    return madd(madd(kron(kron(a, I5), I5), kron(kron(I5, a), I5)), kron(kron(I5, I5), a))

Jz, Jp, Jm = Jtot(Jz5), Jtot(Jp5), Jtot(Jm5)
C = madd(madd(mmul(Jz, Jz), Jz), mmul(Jm, Jp))
I = eye(N)

def poly_at(roots):
    R = I
    for r in roots:
        R = mmul(R, madd(C, mscale(-r, I)))
    return R

K = poly_at([6, 30])
others = lambda i: [c for l, c in enumerate(NODES) if l != i]
dcoef = [prod(NODES[i] - c for c in others(i)) for i in range(7)]
assert dcoef == [3628800, -1612800, 1741824, -3110400, 8870400, -43545600, 479001600]
assert all(DD % d == 0 for d in dcoef)
E = [mscale(DD // dcoef[i], poly_at(others(i))) for i in range(7)]

# weight of each global index (block structure)
def weight(g):
    k1, k2, k3 = g // 25, (g // 5) % 5, g % 5
    return (2 - k1) + (2 - k2) + (2 - k3)
blocks = {}
for g in range(N):
    blocks.setdefault(weight(g), []).append(g)

# ---------------------------------------------------------------- exact RREF null space
def null_basis_reduced(M, idx):
    """Null space of M restricted to the coordinate block idx (M preserves the block).
    Returns (pivot_free_list, basis_vectors) with basis[f][free_g] = delta."""
    n = len(idx)
    A = [[Fraction(M[r][c]) for c in idx] for r in idx]
    piv_cols, row = [], 0
    for col in range(n):
        p = next((r for r in range(row, n) if A[r][col] != 0), None)
        if p is None: continue
        A[row], A[p] = A[p], A[row]
        inv = 1 / A[row][col]
        A[row] = [v * inv for v in A[row]]
        for r in range(n):
            if r != row and A[r][col] != 0:
                f = A[r][col]
                A[r] = [a - f*b for a, b in zip(A[r], A[row])]
        piv_cols.append(col); row += 1
        if row == n: break
    free = [c for c in range(n) if c not in piv_cols]
    basis = []
    for f in free:
        v = [Fraction(0)]*n
        v[f] = Fraction(1)
        for r, pc in enumerate(piv_cols):
            v[pc] = -A[r][f]
        basis.append(v)
    return [idx[f] for f in free], [(idx, v) for v in basis]

def reduced_certificate(M):
    """Global reduced basis of ker M: columns supported in one weight block each."""
    pivots, cols = [], []
    for w in sorted(blocks, reverse=True):
        fr, bs = null_basis_reduced(M, blocks[w])
        pivots += fr
        for idx, v in bs:
            col = [Fraction(0)]*N
            for g, val in zip(idx, v): col[g] = val
            cols.append(col)
    beta = lcm(*[x.denominator for col in cols for x in col]) if cols else 1
    B = [[int(cols[c][g] * beta) for c in range(len(cols))] for g in range(N)]
    return pivots, beta, B

def check_certificate(Mop, Eproj, pivots, beta, B):
    k = len(pivots)
    # (c1) Mop * B = 0
    assert all(v == 0 for row in mmul(Mop, B) for v in row), "c1"
    # (c2) B[P,:] = beta * I
    for a, p in enumerate(pivots):
        assert B[p] == [beta if b == a else 0 for b in range(k)], "c2"
    # (c3) beta * E = B * E[P,:]
    EP = [Eproj[p] for p in pivots]
    assert mscale(beta, Eproj) == mmul(B, EP), "c3"
    return True

levels = []
for i, c in enumerate(NODES):
    Mi = madd(C, mscale(-c, I))
    piv, beta, B = reduced_certificate(Mi)
    check_certificate(Mi, E[i], piv, beta, B)
    levels.append(dict(level=i, casimir=c, dim=len(piv), beta=beta, pivots=piv, B=B))
    print(f"level {i} (C={c:2d}): dim {len(piv):2d}  beta = {beta}  "
          f"max|B| = {max(abs(v) for r in B for v in r)}", file=sys.stderr)

EK = madd(E[2], E[5])
pivK, betaK, BK = reduced_certificate(K)
check_certificate(K, EK, pivK, betaK, BK)
print(f"ker K: dim {len(pivK)}  beta = {betaK}  max|B| = {max(abs(v) for r in BK for v in r)}",
      file=sys.stderr)

# the five off-kernel factor checks E_j K = k_j E_j
kvals = [(c - 6) * (c - 30) for c in NODES]
for j in [0, 1, 3, 4, 6]:
    assert mmul(E[j], K) == mscale(kvals[j], E[j])
print("E_j K = k_j E_j for j in {0,1,3,4,6}:", [kvals[j] for j in [0,1,3,4,6]], file=sys.stderr)
print("dims:", [l['dim'] for l in levels], "sum", sum(l['dim'] for l in levels), file=sys.stderr)
print("max |E| entry:", max(abs(v) for Ei in E for r in Ei for v in r), file=sys.stderr)

out = dict(levels=[{k: v for k, v in l.items()} for l in levels],
           kernel=dict(dim=len(pivK), beta=betaK, pivots=pivK, B=BK))
blob = json.dumps(out, sort_keys=True).encode()
open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "certificate.json"), "wb").write(blob)
print("sha256(certificate.json) =", hashlib.sha256(blob).hexdigest(), file=sys.stderr)
