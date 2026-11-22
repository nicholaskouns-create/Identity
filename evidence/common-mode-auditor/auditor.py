"""
auditor.py -- the certified residual auditor (Theorem G(e), exact branch).

Its reference is NOT the deployment's configuration, operator file or numerical libraries.
It is rebuilt, at load, from the certificate data that NativeResidualCertificate.v checks:
the integer native operator A and the integer polynomials m1, m2, u, v with u m1 + v m2 = d.
    K = m1(A),  P = v(A) m2(A),   d I = u(A) K + P,   K P = 0,   W A = (W A)^T
so P/d is exactly the W-orthogonal spectral projector 1_Lam(A).  The file is refused unless its
SHA-256 equals the pinned value, and the identities above are re-verified in exact integer
arithmetic before the first audit.

Audit of a claimed component y of an input x (float64 vectors, native coordinates):
    dev(x, y)^2 = || y - P x / d ||_W^2 / || x ||_W^2        computed EXACTLY (floats are dyadic
                                                             rationals; all arithmetic in Z)
    accept  <=>  dev <= tau + rho      (rational threshold; tau from Theorem G(ii) at eps0)
Soundness : an accepted y is within tau + rho of the exact spectral component (no rounding slack).
Completeness: any substrate within eps0 of A whose replica errs by at most rho is accepted
              (Theorem G(ii) + the declared allowance rho).
"""
import json, hashlib
from fractions import Fraction as F
from operator import mul
import numpy as np

PINNED_SHA256 = {"native_instances.json": "299b4ceac497933854dbf9d7ace5bf8946eed9708a1ed60a8dcce3de22ce1970"}

class CertificateRefused(Exception):
    pass

def _mm(A, B):
    Bt = list(zip(*B))
    return [[sum(map(mul, r, c)) for c in Bt] for r in A]

def _horner(A, cs):
    n = len(A); R = [[cs[-1] if i == j else 0 for j in range(n)] for i in range(n)]
    for c in reversed(cs[:-1]):
        R = _mm(A, R)
        for i in range(n): R[i][i] += c
    return R

def _to_int(v):
    """float64 vector -> (list of ints X, T) with v = X / 2^T exactly; None if non-finite."""
    v = np.asarray(v, dtype=np.float64)
    if not np.all(np.isfinite(v)): return None
    pairs = [float(t).as_integer_ratio() for t in v]
    T = max(q.bit_length() - 1 for _, q in pairs)
    return [p << (T - (q.bit_length() - 1)) for p, q in pairs], T

class CertifiedAuditor:
    def __init__(self, path, name, weights, tau, rho, pinned=PINNED_SHA256):
        raw = open(path, "rb").read()
        key = path.replace("\\", "/").split("/")[-1]
        if hashlib.sha256(raw).hexdigest() != pinned.get(key):
            raise CertificateRefused(f"{key}: SHA-256 mismatch -- certificate refused")
        inst = next(i for i in json.loads(raw)["instances"] if i["name"] == name)
        A = inst["A"]; n = len(A); d = int(inst["d"])
        K = _horner(A, inst["m1"]); R = _horner(A, inst["u"])
        P = _mm(_horner(A, inst["v"]), _horner(A, inst["m2"]))
        RK = _mm(R, K)
        if any(RK[i][j] + P[i][j] != (d if i == j else 0) for i in range(n) for j in range(n)):
            raise CertificateRefused("Bezout identity fails")
        if any(x != 0 for row in _mm(K, P) for x in row):
            raise CertificateRefused("K P != 0 (annihilating identity fails)")
        w = [int(t) for t in weights]
        if any(w[i] * A[i][j] != w[j] * A[j][i] for i in range(n) for j in range(n)):
            raise CertificateRefused("A is not W-self-adjoint for the declared weights")
        self.name, self.n, self.d, self.P, self.w = name, n, d, P, w
        self.r = int(inst["r"])
        self.thr = F(tau) + F(rho)
        self.sha256 = hashlib.sha256(raw).hexdigest()

    def dev2(self, x, y):
        """exact rational dev(x, y)^2 (None if an input is non-finite)."""
        a, b = _to_int(x), _to_int(y)
        if a is None or b is None: return None
        X, Tx = a; Y, Ty = b
        PX = [sum(map(mul, row, X)) for row in self.P]
        T = max(Tx, Ty)                           # y - PX/(d 2^Tx) = (d Y 2^(T-Ty) - PX 2^(T-Tx)) / (d 2^T)
        r = [(self.d * yi << (T - Ty)) - (pi << (T - Tx)) for yi, pi in zip(Y, PX)]
        num = sum(wi * ri * ri for wi, ri in zip(self.w, r))
        den = sum(wi * xi * xi for wi, xi in zip(self.w, X))
        if den == 0: return None
        return F(num, den * self.d * self.d) * F(1 << (2 * Tx), 1 << (2 * T))

    def accept(self, x, y):
        e2 = self.dev2(x, y)
        return e2 is not None and e2 <= self.thr * self.thr

    def deviation(self, x, y):
        e2 = self.dev2(x, y)
        return float("inf") if e2 is None else float(e2) ** 0.5
