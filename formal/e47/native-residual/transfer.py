r"""
transfer.py -- Theorem G, analytic half: open-substrate transfer bounds for a spectral gap.

Frame. A is self-adjoint in an orthonormal frame (for the E47 carrier this is the W^(1/2) frame,
H = W^(1/2) C W^(-1/2); norms there are W-norms in native coordinates).
Lam  = a nonempty proper subset of the distinct eigenvalues, P = 1_Lam(A), r = rank P,
g    = min |lam - mu|, lam in Lam, mu in spec(A) \ Lam                 (separation)
cluster k = maximal run of Lam-eigenvalues with no spec\Lam point between them, span [a_k, b_k];
delta_k   = dist(spec\Lam, [a_k, b_k])  (>= g).

For eps = ||A_hat - A|| < g/2:
 (i)   occupancy  -- exactly r eigenvalues of A_hat in the window W = {z : dist(z, Lam) < g/2}
       (self-adjoint A_hat: Weyl; any A_hat, A normal: Bauer-Fike + continuity, counted
        with algebraic multiplicity in the complex plane);
 (ii)  subspace   -- self-adjoint A_hat:  ||P_hat - P|| <= sqrt( sum_k (eps/(delta_k-eps))^2 )
                     (Sylvester-equation Davis-Kahan per cluster, combined in l2);
                     any A_hat, Riesz projector:  ||P_hat - P|| <= |Lam| * eps/(g/2 - eps);
 (iii) flow window-- s polynomial, eta = max{|s(t)| : dist(t,Lam) <= eps},
                     gamma = min{|s(t)| : dist(t, spec\Lam) <= eps} > 0:
                     ||exp(-t s(A_hat)^2) - P_hat|| <= max(1 - exp(-t eta^2), exp(-t gamma^2));
 (iv)  buoy residual -- p = sum_k a_k (z-c)^k, R0 = ||A - c||:
                     ||p(A_hat) - p(A)|| <= eps * sum_k |a_k| sum_{j<k} (R0+eps)^j R0^(k-1-j)
                     (telescoping; the scalar Lipschitz constant of p is not an operator bound).
"""
import numpy as np
from numpy.polynomial import Polynomial as Poly
from scipy.linalg import schur, solve_sylvester

def opnorm(M):
    return float(np.linalg.norm(M, 2))

def distinct(vals, tol):
    out = []
    for x in sorted(vals):
        if not out or abs(x - out[-1]) > tol: out.append(float(x))
    return np.array(out)

# ---------------------------------------------------------------- polynomial helpers
def poly_abs_range(s, lo, hi):
    """(min |s|, max |s|) on [lo, hi] for a real polynomial s (endpoints + critical points)."""
    cand = [lo, hi]
    if s.degree() >= 2:
        for c in s.deriv().roots():
            if abs(c.imag) < 1e-12 and lo <= c.real <= hi: cand.append(c.real)
    vals = np.abs(s(np.array(cand)))
    mn = float(vals.min())
    for z0 in s.roots():                      # a sign change / root inside forces min = 0
        if abs(z0.imag) < 1e-12 and lo <= z0.real <= hi: mn = 0.0
    return mn, float(vals.max())

def recentre(p, c):
    """coefficients a_k of p in powers of (z - c)."""
    q = p(Poly([c, 1]))                       # p(c + w)
    return np.array(q.coef, float)

def telescoping_bound(p, c, R0, eps):
    a = recentre(p, c); R1 = R0 + eps
    return float(eps * sum(abs(a[k]) * sum(R1**j * R0**(k - 1 - j) for j in range(k))
                           for k in range(1, len(a))))

# ---------------------------------------------------------------- the gapped operator
class Gap:
    def __init__(self, A, lam, tol=1e-7):
        A = np.asarray(A, float)
        if not np.allclose(A, A.T, atol=1e-9 * max(1.0, np.abs(A).max())):
            raise ValueError("A must be self-adjoint in this frame")
        self.A = (A + A.T) / 2
        self.n = A.shape[0]
        w, V = np.linalg.eigh(self.A)
        self.w, self.V = w, V
        d = distinct(w, tol)
        lam = np.array(sorted(lam), float)
        self.lam = np.array([x for x in d if np.min(np.abs(lam - x)) <= 1e-6 * max(1, abs(x))])
        if len(self.lam) != len(lam): raise ValueError("every Lam value must be an eigenvalue")
        self.rest = np.array([x for x in d if np.min(np.abs(self.lam - x)) > 1e-6 * max(1, abs(x))])
        sel = np.array([np.min(np.abs(self.lam - x)) <= 1e-6 * max(1, abs(x)) for x in w])
        self.sel = sel
        self.P = V[:, sel] @ V[:, sel].T
        self.r = int(sel.sum())
        self.g = float(np.min(np.abs(self.lam[:, None] - self.rest[None, :])))
        groups, cur = [], [self.lam[0]]
        for x in self.lam[1:]:
            if any(cur[-1] < m < x for m in self.rest): groups.append(cur); cur = [x]
            else: cur.append(x)
        groups.append(cur)
        self.clusters = [(c[0], c[-1]) for c in groups]
        self.deltas = [float(min((a - m) if m < a else (m - b) for m in self.rest))
                       for a, b in self.clusters]
        self.Pk = []
        for a, b in self.clusters:
            sk = np.array([(a - 1e-6 * max(1, abs(a))) <= x <= (b + 1e-6 * max(1, abs(b))) for x in w])
            self.Pk.append(V[:, sk] @ V[:, sk].T)

    # (i)
    def in_window(self, z):
        z = np.atleast_1d(z)
        return np.min(np.abs(z[:, None] - self.lam[None, :]), axis=1) < self.g / 2
    def occupancy(self, Ah):
        Ah = np.asarray(Ah)
        if np.allclose(Ah, Ah.T, atol=0):
            return int(self.in_window(np.linalg.eigvalsh(Ah)).sum())
        return int(self.in_window(np.linalg.eigvals(Ah)).sum())

    # (ii)
    def dk_bound(self, eps):
        if eps >= self.g / 2: return np.inf
        return min(1.0, float(np.sqrt(sum((eps / (d - eps))**2 for d in self.deltas))))
    def dk_bound_l1(self, eps):
        if eps >= self.g / 2: return np.inf
        return min(1.0, float(sum(eps / (d - eps) for d in self.deltas)))
    def riesz_bound(self, eps):
        if eps >= self.g / 2: return np.inf
        return float(len(self.lam) * eps / (self.g / 2 - eps))
    def window_projector(self, Ah):
        w, V = np.linalg.eigh((Ah + Ah.T) / 2)
        s = self.in_window(w)
        return V[:, s] @ V[:, s].T, w, V, s
    def riesz_projector(self, Ah):
        T, Q, k = schur(np.asarray(Ah, complex), output='complex',
                        sort=lambda z: bool(self.in_window(np.array([z]))[0]))
        n = T.shape[0]
        if k in (0, n):
            Pt = np.eye(n) if k == n else np.zeros((n, n))
        else:
            Y = solve_sylvester(T[:k, :k], -T[k:, k:], T[:k, k:])
            Pt = np.zeros((n, n), complex); Pt[:k, :k] = np.eye(k); Pt[:k, k:] = Y
        return Q @ Pt @ Q.conj().T, k

    # (iii)
    def selector(self):
        return Poly.fromroots(self.lam)
    def eta_gamma(self, s, eps):
        eta = max(poly_abs_range(s, l - eps, l + eps)[1] for l in self.lam)
        gam = min(poly_abs_range(s, m - eps, m + eps)[0] for m in self.rest)
        return eta, gam
    @staticmethod
    def flow_bound(eta, gam, t):
        return max(1 - np.exp(-t * eta**2), np.exp(-t * gam**2))
    @staticmethod
    def best_time(eta, gam):
        """t minimising max(1-exp(-t eta^2), exp(-t gam^2)) (bisection on the crossing)."""
        if gam <= eta: return None
        f = lambda t: (1 - np.exp(-t * eta**2)) - np.exp(-t * gam**2)
        lo, hi = 0.0, 1.0
        while f(hi) < 0: hi *= 2
        for _ in range(200):
            mid = (lo + hi) / 2
            if f(mid) < 0: lo = mid
            else: hi = mid
        return hi
    def flow_operator(self, Ah, s, t):
        w, V = np.linalg.eigh((Ah + Ah.T) / 2)
        return (V * np.exp(-t * s(w)**2)) @ V.T

    # (iv)
    def spectral_radius_about(self, c):
        return float(np.max(np.abs(self.w - c)))

# ---------------------------------------------------------------- operator families
def kron3_sum(a):
    I = np.eye(a.shape[0])
    return np.kron(np.kron(a, I), I) + np.kron(np.kron(I, a), I) + np.kron(np.kron(I, I), a)

def e47_native():
    """Integer sl2 model (E47MatrixProjector.v): C = Jz^2 + Jz + Jm Jp, W = W1^(x3)."""
    Jz5 = np.diag([2., 1, 0, -1, -2])
    Jp5 = np.zeros((5, 5)); Jm5 = np.zeros((5, 5))
    for k in range(1, 5): Jp5[k - 1, k] = k * (5 - k)
    for k in range(4): Jm5[k + 1, k] = 1
    Jz, Jp, Jm = kron3_sum(Jz5), kron3_sum(Jp5), kron3_sum(Jm5)
    C = Jz @ Jz + Jz + Jm @ Jp
    w1 = np.array([1., 4, 24, 144, 576])
    W = np.kron(np.kron(w1, w1), w1)
    return C, W

def to_frame(C, W):
    S = np.sqrt(W)
    H = (S[:, None] * C) / S[None, :]
    return (H + H.T) / 2, S

def cube_laplacian():
    L5 = 2 * np.eye(5) - np.roll(np.eye(5), 1, 0) - np.roll(np.eye(5), -1, 0)
    return kron3_sum(L5)

def heisenberg_ring(n=8):
    sx = np.array([[0, 1], [1, 0]]) / 2; sy = np.array([[0, -1j], [1j, 0]]) / 2; sz = np.diag([1., -1]) / 2
    def site(op, i):
        M = np.array([[1.0 + 0j]])
        for k in range(n): M = np.kron(M, op if k == i else np.eye(2))
        return M
    H = sum(site(s, i) @ site(s, (i + 1) % n) for i in range(n) for s in (sx, sy, sz))
    H = H.real
    return (H + H.T) / 2

def planted(rng, n, nclusters, spread=0.0):
    """random self-adjoint matrix with planted clustered spectrum (exact eigenvalues known)."""
    centres = np.sort(rng.uniform(-10, 10, nclusters))
    mult = rng.multinomial(n - nclusters, np.ones(nclusters) / nclusters) + 1
    vals = np.concatenate([c + spread * rng.uniform(-1, 1, m) for c, m in zip(centres, mult)])
    Q, _ = np.linalg.qr(rng.standard_normal((n, n)))
    return (Q * vals) @ Q.T, vals, centres, mult
