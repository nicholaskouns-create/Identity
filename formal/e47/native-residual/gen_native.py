r"""
Native-basis residual certificates for an arbitrary integer operator.

Input : an integer matrix A (the operator in its native basis) and a factorisation of an
        annihilating polynomial  M = m1 * m2  over Z[z]  with gcd(m1, m2) = 1.
Output: K = m1(A), the Bezout data  u*m1 + v*m2 = d  (u, v in Z[z], d in Z \ {0}),
        R = u(A), P = v(A) m2(A), and a reduced basis (B, piv, beta) of ker K.
Checks (exact): M(A) = 0, d*I = R K + P, K B = 0, B[piv,:] = beta*I, beta*P = B P[piv,:].
These are exactly the hypotheses of the generic Coq theorem native_certificate.
"""
from fractions import Fraction
from math import lcm
import sympy as sp, json, sys, hashlib

z = sp.symbols('z')

def mat_mul(A, B):
    Bt = list(zip(*B))
    return [[sum(a*b for a, b in zip(r, c)) for c in Bt] for r in A]
def eye(n): return [[1 if i == j else 0 for j in range(n)] for i in range(n)]
def madd(A, B): return [[a+b for a, b in zip(r, s)] for r, s in zip(A, B)]
def mscale(k, A): return [[k*a for a in r] for r in A]

def horner(A, coeffs):          # coeffs low -> high
    n = len(A); R = mscale(coeffs[-1], eye(n))
    for c in reversed(coeffs[:-1]):
        R = madd(mat_mul(A, R), mscale(c, eye(n)))
    return R

def zcoeffs(p):                  # sympy poly -> integer coeff list low->high
    P = sp.Poly(p, z); cs = P.all_coeffs()[::-1]
    assert all(sp.Integer(c) == c for c in cs), p
    return [int(c) for c in cs]

def bezout(m1, m2):
    s, t, g = sp.gcdex(sp.Poly(m1, z, domain='QQ'), sp.Poly(m2, z, domain='QQ'))
    assert g.as_expr() == 1
    den = lcm(*[int(sp.Rational(c).q) for c in s.all_coeffs() + t.all_coeffs()])
    u = sp.expand(s.as_expr() * den); v = sp.expand(t.as_expr() * den)
    assert sp.expand(u*m1 + v*m2 - den) == 0
    return u, v, den

def null_reduced(M):
    n = len(M); A = [[Fraction(x) for x in r] for r in M]
    piv, row = [], 0
    for col in range(n):
        p = next((r for r in range(row, n) if A[r][col] != 0), None)
        if p is None: continue
        A[row], A[p] = A[p], A[row]; inv = 1 / A[row][col]
        A[row] = [x*inv for x in A[row]]
        for r in range(n):
            if r != row and A[r][col] != 0:
                f = A[r][col]; A[r] = [a - f*b for a, b in zip(A[r], A[row])]
        piv.append(col); row += 1
        if row == n: break
    free = [c for c in range(n) if c not in piv]
    cols = []
    for f in free:
        v = [Fraction(0)]*n; v[f] = Fraction(1)
        for r, pc in enumerate(piv): v[pc] = -A[r][f]
        cols.append(v)
    beta = lcm(*[x.denominator for c in cols for x in c]) if cols else 1
    B = [[int(cols[c][g]*beta) for c in range(len(cols))] for g in range(n)]
    return free, beta, B

def certify(name, A, m1, m2):
    n = len(A)
    M = sp.expand(m1*m2)
    assert all(v == 0 for r in horner(A, zcoeffs(M)) for v in r), "M(A) != 0"
    u, v, d = bezout(m1, m2)
    K = horner(A, zcoeffs(m1)); R = horner(A, zcoeffs(u))
    P = mat_mul(horner(A, zcoeffs(v)), horner(A, zcoeffs(m2)))
    assert madd(mat_mul(R, K), P) == mscale(d, eye(n)), "Bezout"
    piv, beta, B = null_reduced(K)
    r = len(piv)
    assert all(x == 0 for row in mat_mul(K, B) for x in row), "KB"
    for a, p in enumerate(piv): assert B[p] == [beta if b == a else 0 for b in range(r)], "piv"
    assert mscale(beta, P) == mat_mul(B, [P[p] for p in piv]), "span"
    mx = lambda X: max(abs(x) for row in X for x in row)
    print(f"[{name}] n={n} dim ker m1(A) = {r}  d={d}  beta={beta}  "
          f"max|K|={mx(K)} max|R|={mx(R)} max|P|={mx(P)} max|B|={mx(B)}", file=sys.stderr)
    return dict(name=name, n=n, A=A, m1=zcoeffs(m1), u=zcoeffs(u), v=zcoeffs(v), m2=zcoeffs(m2),
                d=d, r=r, piv=piv, beta=beta, B=B)

def main():
    # ---------------- instance 1: E47 (integer sl2 model, as in E47MatrixProjector.v) ------------
    def kron(A, B):
        ra, ca, rb, cb = len(A), len(A[0]), len(B), len(B[0])
        return [[A[i//rb][j//cb]*B[i % rb][j % cb] for j in range(ca*cb)] for i in range(ra*rb)]
    I5 = eye(5)
    Jz5 = [[2,0,0,0,0],[0,1,0,0,0],[0,0,0,0,0],[0,0,0,-1,0],[0,0,0,0,-2]]
    Jp5 = [[0,4,0,0,0],[0,0,6,0,0],[0,0,0,6,0],[0,0,0,0,4],[0,0,0,0,0]]
    Jm5 = [[0,0,0,0,0],[1,0,0,0,0],[0,1,0,0,0],[0,0,1,0,0],[0,0,0,1,0]]
    tot = lambda a: madd(madd(kron(kron(a, I5), I5), kron(kron(I5, a), I5)), kron(kron(I5, I5), a))
    Jz, Jp, Jm = tot(Jz5), tot(Jp5), tot(Jm5)
    C = madd(madd(mat_mul(Jz, Jz), Jz), mat_mul(Jm, Jp))
    e47 = certify("E47-Casimir", C, (z-6)*(z-30), z*(z-2)*(z-12)*(z-20)*(z-42))

    # ---------------- instance 2: the Professor's Cube, 5x5x5 torus Laplacian ------------------
    L5 = [[2 if i == j else (-1 if (i-j) % 5 in (1, 4) else 0) for j in range(5)] for i in range(5)]
    Lcube = madd(madd(kron(kron(L5, I5), I5), kron(kron(I5, L5), I5)), kron(kron(I5, I5), L5))
    golden = z**2 - 5*z + 5                                   # roots (5 -+ sqrt5)/2 = 1 + phi^(-+2)
    rest = z*(z-5)*(z**2-10*z+20)*(z**2-15*z+45)*(z**2-15*z+55)
    cube = certify("Cube-torus-golden", Lcube, golden, rest)

    json.dump(dict(instances=[e47, cube]), open("native_instances.json", "w"))
    print("sha256", hashlib.sha256(open("native_instances.json","rb").read()).hexdigest(), file=sys.stderr)

if __name__ == '__main__':
    main()
