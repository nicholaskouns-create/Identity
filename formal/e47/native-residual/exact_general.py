"""
exact_general.py -- Theorem G, exact side, beyond the two Coq instances.

 1. certified constants for the Coq instances (E47, Cube): rigorous rational enclosures of
    g, delta_k, gamma_K, kappa_K (and the complementary residual) from exact root isolation
    of the certified factors m1, m2 (their product annihilates A: e47_minpoly / cube_minpoly);
    the auditor envelope eps0 and its Davis-Kahan tolerance tau, as exact rationals.
 2. a fresh random instance (disguised direct sum, non-symmetric native matrix, W-self-adjoint
    with integer W) -> Bezout certificate -> emitted as a Coq file checked by the SAME generic
    theorem native_certificate (NativeResidualRandomInstance.v).
 3. the inexact branch: a random integer symmetric matrix whose characteristic polynomial is
    irreducible over Q (no Galois-closed proper part exists, so no exact certificate can exist);
    spectrum enclosed by exact inertia (Sylvester's law, LDL^T over Q with 1x1/2x2 pivots);
    a rational native residual q with certified (eta, gamma, kappa); numerical spot checks.
Writes certified_constants.json and NativeResidualRandomInstance.v.
"""
import sympy as sp, numpy as np, json, hashlib, sys, time
from fractions import Fraction as F
from math import isqrt
import gen_native as gn

z = sp.symbols('z')
def poly_from(coeffs): return sp.Poly(sum(int(c) * z**i for i, c in enumerate(coeffs)), z)
def rat(x): x = sp.Rational(x); return F(int(x.p), int(x.q))

def isolate(coeffs, eps=sp.Rational(1, 10**40)):
    """rigorous isolating intervals [a,b] (exact rationals) for the real roots of an integer poly."""
    out = []
    for (a, b), m in poly_from(coeffs).intervals(eps=eps):
        out.append((rat(a), rat(b), int(m)))
    return out

def idist(I, J):   # lower bound on |x-y|, x in I, y in J
    return max(F(0), J[0] - I[1], I[0] - J[1])
def imaxd(I, J):   # upper bound on |x-y|
    return max(abs(I[1] - J[0]), abs(J[1] - I[0]))

def sqrt_up(S, digits=15):
    """smallest decimal tau = k/10^digits with tau^2 >= S (exact)."""
    D = 10**digits; k = isqrt(int(S * D * D)) 
    while F(k, D)**2 < S: k += 1
    return F(k, D)

def certified_constants(name, m1, m2, frac=40):
    L, R = isolate(m1), isolate(m2)
    assert all(m == 1 for *_, m in L + R), "squarefree factors expected"
    allI = sorted([(a, b, 'L') for a, b, _ in L] + [(a, b, 'R') for a, b, _ in R])
    for (a1, b1, _), (a2, b2, _) in zip(allI, allI[1:]): assert b1 < a2, "intervals overlap"
    clusters, cur = [], []
    for a, b, t in allI:
        if t == 'L': cur.append((a, b))
        elif cur: clusters.append(cur); cur = []
    if cur: clusters.append(cur)
    Li = [(a, b) for a, b, _ in L]; Ri = [(a, b) for a, b, _ in R]
    g_lo = min(idist(I, J) for I in Li for J in Ri)
    deltas = []
    for c in clusters:
        span = (c[0][0], c[-1][1])
        deltas.append(min(idist(span, J) for J in Ri))
    prodlo = lambda I, S: np.prod([idist(I, J) for J in S], dtype=object)
    prodhi = lambda I, S: np.prod([imaxd(I, J) for J in S], dtype=object)
    lead1, lead2 = abs(F(int(m1[-1]))), abs(F(int(m2[-1])))
    gamK = min(prodlo(J, Li) for J in Ri) * lead1; kapK = max(prodhi(J, Li) for J in Ri) * lead1
    gamC = min(prodlo(I, Ri) for I in Li) * lead2; kapC = max(prodhi(I, Ri) for I in Li) * lead2
    eps0 = g_lo / frac
    S = sum((eps0 / (d - eps0))**2 for d in deltas)
    tau = sqrt_up(S)
    f = lambda q: [str(q), float(q)]
    out = dict(name=name, Lam_intervals=[[str(a), str(b)] for a, b in Li],
               rest_intervals=[[str(a), str(b)] for a, b in Ri], clusters=len(clusters),
               g_lower=f(g_lo), delta_lower=[f(d) for d in deltas],
               gamma_K_lower=f(gamK), kappa_K_upper=f(kapK),
               gamma_C_lower=f(gamC), kappa_C_upper=f(kapC),
               eps0=f(eps0), envelope_rule=f"eps0 = g_lower/{frac}",
               tau_DK_upper=f(tau), tau_definition="tau >= sqrt(sum_k (eps0/(delta_k - eps0))^2)")
    print(f"[{name}] g >= {float(g_lo):.12g}  deltas >= {[round(float(d), 9) for d in deltas]}  "
          f"gamma_K >= {float(gamK):.9g}  kappa_K <= {float(kapK):.9g}  eps0 = {float(eps0):.6g}  tau = {float(tau):.9g}")
    return out

# ------------------------------------------------------------------ exact inertia (Sylvester)
def inertia(M):
    """(n+, n-, n0) of a symmetric rational matrix by LDL^T over Q with 1x1 / 2x2 pivots."""
    A = [list(r) for r in M]; idx = list(range(len(A))); pos = neg = zer = 0
    while idx:
        k = next((i for i in idx if A[i][i] != 0), None)
        if k is not None:
            p = A[k][k]; pos += p > 0; neg += p < 0
            rest = [i for i in idx if i != k]; rk = [A[k][j] for j in rest]
            for ii, i in enumerate(rest):
                if rk[ii] != 0:
                    fct = rk[ii] / p; Ai = A[i]
                    for jj, j in enumerate(rest):
                        if rk[jj] != 0: Ai[j] -= fct * rk[jj]
            idx = rest; continue
        pr = next(((i, j) for i in idx for j in idx if i < j and A[i][j] != 0), None)
        if pr is None: zer += len(idx); break
        i0, j0 = pr; a = A[i0][j0]; pos += 1; neg += 1
        rest = [i for i in idx if i not in (i0, j0)]
        ci = [A[r][i0] for r in rest]; cj = [A[r][j0] for r in rest]
        for x, r in enumerate(rest):
            for y, c in enumerate(rest):
                A[r][c] -= (ci[x] * cj[y] + cj[x] * ci[y]) / a
        idx = rest
    return pos, neg, zer

def count_below(Aq, sigma):
    n = len(Aq)
    M = [[Aq[i][j] - (sigma if i == j else 0) for j in range(n)] for i in range(n)]
    p, m, z0 = inertia(M)
    assert z0 == 0, "sigma hit an eigenvalue; move it"
    return m

# ------------------------------------------------------------------ part 2: fresh random instance
def random_instance(seed=7, n1=8, n2=12):
    rng = np.random.default_rng(seed)
    def rsym(k):
        X = rng.integers(-2, 3, (k, k)); return (X + X.T) // 1
    for attempt in range(200):
        A1, A2 = rsym(n1), rsym(n2)
        c1 = sp.Matrix(A1.tolist()).charpoly(z).as_expr(); c2 = sp.Matrix(A2.tolist()).charpoly(z).as_expr()
        if sp.degree(sp.gcd(c1, c2), z) == 0 and sp.degree(sp.gcd(c1, sp.diff(c1, z)), z) == 0 \
           and sp.degree(sp.gcd(c2, sp.diff(c2, z)), z) == 0: break
        rng = np.random.default_rng(seed + attempt + 1)
    n = n1 + n2
    D = np.zeros((n, n), dtype=object); D[:n1, :n1] = A1; D[n1:, n1:] = A2
    U = np.eye(n, dtype=object)
    for _ in range(3 * n):                                   # unimodular disguise
        i, j = rng.choice(n, 2, replace=False); s = int(rng.choice([-1, 1]))
        E = np.eye(n, dtype=object); E[i, j] = s; U = U.dot(E)
    Ui = np.array(sp.Matrix(U.tolist()).inv().tolist(), dtype=object)
    assert all(int(x) == x for x in Ui.flat)
    A = U.dot(D).dot(Ui); W = Ui.T.dot(Ui)                   # A is W-self-adjoint, W integer SPD
    assert (W.dot(A) == (W.dot(A)).T).all()
    A = [[int(x) for x in r] for r in A.tolist()]; W = [[int(x) for x in r] for r in W.tolist()]
    return A, W, sp.expand(c1), sp.expand(c2), n1, n2

def coq_list(v): return "[" + ";".join(f"({x})" if x < 0 else str(x) for x in v) + "]"
def coq_mat(M): return "[" + ";\n   ".join(coq_list(r) for r in M) + "]"

def emit_random_coq(inst, path="NativeResidualRandomInstance.v"):
    n, r = inst['n'], inst['r']
    txt = f"""(* NativeResidualRandomInstance.v -- generated by exact_general.py; do not edit.

   A FRESH instance of the generic theorem NativeResidual.native_certificate:
   a random disguised direct sum A = U (A1 (+) A2) U^-1 (U unimodular), n = {n}.
   A is not symmetric in its native basis; it is self-adjoint for the integer SPD weight
   W = U^-T U^-1.  m1 = charpoly(A1) (degree {inst['deg1']}), m2 = charpoly(A2) (degree {inst['deg2']}).
   The selected eigenvalues are the {r} real roots of m1, interlaced with those of m2. *)
From Coq Require Import List ZArith.
Import ListNotations.
From NR Require Import NativeResidualCertificate.
Import NativeResidual.
Open Scope Z_scope.

Definition rnd_A : Mat :=
  {coq_mat(inst['A'])}.
Definition rnd_m1 : list Z := {coq_list(inst['m1'])}.
Definition rnd_m2 : list Z := {coq_list(inst['m2'])}.
Definition rnd_u : list Z := {coq_list(inst['u'])}.
Definition rnd_v : list Z := {coq_list(inst['v'])}.
Definition rnd_d : Z := {inst['d']}.
Definition rnd_beta : Z := {inst['beta']}.
Definition rnd_piv : list nat := {coq_list(inst['piv'])}%nat.
Definition rnd_B : Mat :=
  {coq_mat(inst['B'])}.
Definition rnd_K : Mat := Eval vm_compute in hpoly {n} rnd_A rnd_m1.
Definition rnd_R : Mat := Eval vm_compute in hpoly {n} rnd_A rnd_u.
Definition rnd_P : Mat := Eval vm_compute in mmul (hpoly {n} rnd_A rnd_v) (hpoly {n} rnd_A rnd_m2).
Lemma rnd_K_def : rnd_K = hpoly {n} rnd_A rnd_m1. Proof. vm_compute. reflexivity. Qed.
Lemma rnd_minpoly : meqb (mmul rnd_K (hpoly {n} rnd_A rnd_m2)) (zmat {n} {n}) = true.
Proof. vm_compute. reflexivity. Qed.
Lemma rnd_check : check {n} rnd_K rnd_R rnd_P rnd_B rnd_piv rnd_d rnd_beta = true.
Proof. vm_compute. reflexivity. Qed.
Lemma rnd_rank : length rnd_piv = {r}%nat. Proof. reflexivity. Qed.

Theorem rnd_kernel_dimension :
  let K := hpoly {n} rnd_A rnd_m1 in
  (forall y, length y = {r}%nat -> mv K (mv rnd_B y) = repeat 0 {n}) /\\
  (forall y, length y = {r}%nat -> mv rnd_B y = repeat 0 {n} -> y = repeat 0 {r}) /\\
  (forall x, length x = {n}%nat -> mv K x = repeat 0 {n} ->
     exists y, length y = {r}%nat /\\ vscale (rnd_beta * rnd_d) x = mv rnd_B y).
Proof.
  rewrite <- rnd_K_def, <- rnd_rank.
  exact (native_certificate {n} rnd_K rnd_R rnd_P rnd_B rnd_piv rnd_d rnd_beta rnd_check).
Qed.

Print Assumptions rnd_minpoly.
Print Assumptions rnd_kernel_dimension.
"""
    open(path, "w").write(txt)

# ------------------------------------------------------------------ part 3: inexact branch
def inexact_demo(seed=11, n=24, top=2, rho_bits=30, est_bits=36):
    rng = np.random.default_rng(seed)
    X = rng.integers(-3, 4, (n, n)); A0 = (X + X.T)
    chi = sp.Matrix(A0.tolist()).charpoly(z).as_expr()
    fl = sp.factor_list(chi)[1]
    irreducible = (len(fl) == 1 and fl[0][1] == 1)
    w = np.linalg.eigvalsh(A0.astype(float))
    est = [F(int(round(x * 2**est_bits)), 2**est_bits) for x in w]
    rho = F(1, 2**rho_bits)
    Aq = [[F(int(v)) for v in r] for r in A0.tolist()]
    t0 = time.time()
    counts = [(count_below(Aq, e - rho), count_below(Aq, e + rho)) for e in est]
    one_each = all(hi - lo == 1 for lo, hi in counts)
    covered = sum(hi - lo for lo, hi in counts) == n
    Lam = list(range(n - top, n)); rest = list(range(n - top))
    eta = max(rho * np.prod([abs(est[i] - est[j]) + rho for j in Lam if j != i], dtype=object) for i in Lam)
    gam = min(np.prod([abs(est[k] - est[j]) - rho for j in Lam], dtype=object) for k in rest)
    kap = max(np.prod([abs(est[k] - est[j]) + rho for j in Lam], dtype=object) for k in rest)
    g_lo = min(abs(est[i] - est[k]) for i in Lam for k in rest) - 2 * rho
    # numerical spot checks of  gamma |(I-P)x| <= |Kx|,  |Kx|^2 <= eta^2 |Px|^2 + kappa^2 |(I-P)x|^2
    A = A0.astype(float); wv, V = np.linalg.eigh(A); P = V[:, -top:] @ V[:, -top:].T
    K = np.eye(n)
    for j in Lam: K = K @ (A - float(est[j]) * np.eye(n))
    worst_lo, worst_hi = 0.0, 0.0
    for _ in range(2000):
        x = rng.standard_normal(n); Px = P @ x; Qx = x - Px; Kx = np.linalg.norm(K @ x)
        worst_lo = max(worst_lo, float(gam) * np.linalg.norm(Qx) / Kx)
        worst_hi = max(worst_hi, Kx**2 / (float(eta)**2 * (Px @ Px) + float(kap)**2 * (Qx @ Qx)))
    res = dict(n=n, seed=seed, charpoly_irreducible_over_Q=irreducible,
               charpoly_degree=int(sp.degree(chi, z)),
               inertia_enclosures_one_eigenvalue_each=one_each, all_eigenvalues_enclosed=covered,
               inertia_seconds=round(time.time() - t0, 2), rho=str(rho),
               Lam="top %d eigenvalues" % top, g_lower=float(g_lo), eta_upper=float(eta),
               gamma_lower=float(gam), kappa_upper=float(kap), eta_over_gamma=float(eta / gam),
               spotcheck_max_ratio_lower=worst_lo, spotcheck_max_ratio_upper=worst_hi)
    print("[inexact]", res)
    return res

if __name__ == "__main__":
    raw = open("native_instances.json", "rb").read()
    sha = hashlib.sha256(raw).hexdigest()
    J = json.loads(raw)
    consts = {}
    for inst in J["instances"]:
        consts[inst["name"]] = certified_constants(inst["name"], inst["m1"], inst["m2"])
    # part 2
    A, W, c1, c2, n1, n2 = random_instance()
    t0 = time.time()
    cert = gn.certify("Random-disguised-direct-sum", A, c1, c2)
    cert.update(deg1=n1, deg2=n2, W=W)
    emit_random_coq(cert)
    Lr = isolate(cert['m1']); Rr = isolate(cert['m2'])
    g_rnd = min(idist((a, b), (c, d)) for a, b, _ in Lr for c, d, _ in Rr)
    print(f"[random] n={cert['n']} r={cert['r']} d has {len(str(cert['d']))} digits, beta={cert['beta']}, "
          f"real roots m1/m2 = {len(Lr)}/{len(Rr)}, g >= {float(g_rnd):.6g}  ({time.time()-t0:.1f}s)")
    consts["Random-disguised-direct-sum"] = dict(n=cert['n'], r=cert['r'], d_digits=len(str(cert['d'])),
                                                 beta=cert['beta'], g_lower=[str(g_rnd), float(g_rnd)])
    json.dump(dict(instances=J["instances"] + [cert]), open("random_instance.json", "w"))
    # part 3
    inex = inexact_demo()
    json.dump(dict(native_instances_sha256=sha, constants=consts, inexact_branch=inex),
              open("certified_constants.json", "w"), indent=1)
    print("certified_constants.json sha256", hashlib.sha256(open("certified_constants.json", "rb").read()).hexdigest())
