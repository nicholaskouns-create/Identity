"""
bench.py -- controlled heterogeneous benchmark: does the certified residual auditor stop
common-mode failures that existing formal and empirical monitors let through?

System under test (per operator family): 5 diverse replicas compute the Lam-spectral component
y = P x of an input state x on an open substrate (the operator they physically realise differs
from the nominal one), in native coordinates.
  R1 eigh64   dense symmetric eigensolver, float64, W^(1/2) frame        \
  R2 eigh32   same, float32                                               > share select_window()
  R5 eigh64r  same, in a randomly rotated orthonormal basis               /
  R3 sign     Newton matrix-sign spectral slicing, cuts midway between nodes (no eigensolver)
  R4 flow     exp(-t s(H)^2) at the Theorem G(iii) optimal time (Pade expm, no eigensolver)
Deployment configuration (shared): operator file, Lam, spectrum nodes, eps0.

Pipelines (each sees the replica outputs, the input as received, its own reference data):
  vote        5-way majority vote with a calibrated tolerance (N-version programming)
  +validated  vote, then the SAME exact-tolerance residual test as the auditor but with the
              reference built from the runtime configuration and operator file (validated numerics)
  +anomaly    vote, then learned assertions (rank) + IsolationForest on output statistics
  +reference  vote, then an independently coded float64 reference (own operator construction,
              Lam from the shared configuration), empirically calibrated threshold
  +auditor    vote, then the certified residual auditor (certificate data, exact arithmetic)
  auditor-select   no vote: deliver the first replica output the auditor accepts
Ground truth: a delivered output is HARMFUL iff its exact deviation from the spectral component of
the TRUE input exceeds the specification tolerance tau + rho (Theorem G(ii) at eps0 + allowance).
"""
import numpy as np, json, time, sys, os, hashlib
from fractions import Fraction as F
import scipy.linalg as sl
HERE = os.path.dirname(os.path.abspath(__file__))
GEN = os.path.join(HERE, "..", "..", "formal", "e47", "native-residual")
sys.path.insert(0, GEN); sys.path.insert(0, HERE)
from transfer import e47_native, cube_laplacian, Gap, opnorm, Poly, poly_abs_range
from auditor import CertifiedAuditor, CertificateRefused, PINNED_SHA256
from sklearn.ensemble import IsolationForest

CERT = os.path.join(GEN, "native_instances.json")
CONSTS = json.load(open(os.path.join(GEN, "certified_constants.json")))["constants"]
RHO = F(1, 200)                       # declared allowance: flow-window truncation + float32 rounding

# ----------------------------------------------------------------------------- families
def family(name):
    if name == "E47":
        C, W = e47_native()
        nodes = [0., 2., 6., 12., 20., 30., 42.]
        f = dict(name="E47", cert="E47-Casimir", C=C, W=W, nodes=nodes, Lam=[6., 30.],
                 cm1a=[6., 20.], cm1b=[2., 6., 42.])
    else:
        C = cube_laplacian(); W = np.ones(125)
        nodes = sorted({round(float(v), 9) for v in np.linalg.eigvalsh(C)})
        r5 = 5 ** .5
        nodes = [0., (5 - r5) / 2, 5 - r5, (5 + r5) / 2, (15 - 3 * r5) / 2, 5., (15 - r5) / 2,
                 5 + r5, (15 + r5) / 2, (15 + 3 * r5) / 2]
        f = dict(name="Cube", cert="Cube-torus-golden", C=C, W=W, nodes=nodes, Lam=[(5 - r5) / 2, (5 + r5) / 2],
                 cm1a=[(5 - r5) / 2, 5 - r5], cm1b=[5 - r5])
    k = CONSTS[f["cert"]]
    f["eps0"] = float(F(k["eps0"][0])); f["tau"] = F(k["tau_DK_upper"][0]); f["g"] = k["g_lower"][1]
    f["S"] = np.sqrt(f["W"]); f["n"] = 125
    H = (f["S"][:, None] * f["C"]) / f["S"][None, :]
    f["H"] = (H + H.T) / 2
    G = Gap(f["H"], f["Lam"]); f["Gap"] = G; f["r"] = G.r
    rng = np.random.default_rng(99)
    f["rot"] = np.linalg.qr(rng.standard_normal((125, 125)))[0]
    return f

def wnorm(f, v): return float(np.sqrt(np.sum(f["W"] * v * v)))

# ----------------------------------------------------------------------------- configuration
def config(f, Lam=None, C=None):
    Lam = list(f["Lam"] if Lam is None else Lam)
    nodes = f["nodes"]; rest = [m for m in nodes if min(abs(m - l) for l in Lam) > 1e-9]
    half = min(abs(l - m) for l in Lam for m in rest) / 2
    s = Poly.fromroots(Lam); e0 = f["eps0"]
    eta = max(poly_abs_range(s, l - e0, l + e0)[1] for l in Lam)
    gam = min(poly_abs_range(s, m - e0, m + e0)[0] for m in rest)
    t = Gap.best_time(eta, gam) if gam > eta else 1.0 / (gam * gam + 1e-300)
    return dict(Lam=Lam, rest=rest, nodes=nodes, half=half, t=t, C=(f["C"] if C is None else C))

# ----------------------------------------------------------------------------- replicas
def select_window(w, Lam, half, defect=False):
    idx = [i for i in range(len(w)) if min(abs(w[i] - l) for l in Lam) < half]
    return idx[1:] if (defect and idx) else idx            # CM3: off-by-one in the shared helper

def frame(f, Cn): return (f["S"][:, None] * Cn) / f["S"][None, :]

def R_eigh(f, cfg, Cn, x, dtype, rot=None, defect=False):
    S = f["S"]; H = frame(f, Cn); H = (H + H.T) / 2
    if rot is not None: H = rot.T @ H @ rot
    w, V = np.linalg.eigh(H.astype(dtype))
    idx = select_window(w.astype(np.float64), cfg["Lam"], cfg["half"], defect)
    Vs = V[:, idx]
    if rot is not None: Vs = (rot.astype(dtype) @ Vs)
    xh = (S * x).astype(dtype)
    yh = Vs @ (Vs.T @ xh)
    return (yh.astype(np.float64) / S), len(idx)

def lagrange(Cn, Lam, nodes, dtype=np.float64):
    n = Cn.shape[0]; I = np.eye(n, dtype=dtype); M = np.zeros((n, n), dtype=dtype); Cn = Cn.astype(dtype)
    for l in Lam:
        T = I.copy()
        for m in nodes:
            if abs(m - l) > 1e-9: T = T @ ((Cn - m * I) / (l - m))
        M = M + T
    return M

def msign(X, dtype, tol):
    """Newton iteration for the matrix sign function with Frobenius-norm scaling (no eigensolver)."""
    X = X.astype(dtype)
    for k in range(100):
        Xi = np.linalg.inv(X)
        mu = np.sqrt(np.linalg.norm(Xi) / np.linalg.norm(X)) if k < 6 else 1.0
        Xn = 0.5 * (mu * X + Xi / mu)
        done = np.linalg.norm(Xn - X) <= tol * np.linalg.norm(Xn)
        X = Xn
        if done or not np.all(np.isfinite(X)): break
    return X

def cuts(cfg):
    """spectral slicing windows: each Lam value gets (a, b) with cuts at midpoints to neighbouring nodes."""
    nodes = sorted(cfg["nodes"]); out = []
    for l in cfg["Lam"]:
        lo = [m for m in nodes if m < l - 1e-9]; hi = [m for m in nodes if m > l + 1e-9]
        out.append(((l + lo[-1]) / 2 if lo else None, (l + hi[0]) / 2 if hi else None))
    return out

def R_sign(f, cfg, Cn, x, dtype=np.float64):
    """R3: Newton matrix-sign spectral slicing  P = sum_k (sign(H - a_k) - sign(H - b_k)) / 2."""
    S = f["S"]; Hn = frame(f, Cn); n = Hn.shape[0]; I = np.eye(n)
    tol = 1e-13 if dtype == np.float64 else 1e-6
    M = np.zeros((n, n))
    for a, b in cuts(cfg):
        sa = msign(Hn - a * I, dtype, tol).astype(np.float64) if a is not None else I
        sb = msign(Hn - b * I, dtype, tol).astype(np.float64) if b is not None else -I
        M = M + 0.5 * (sa - sb)
    yh = M.astype(dtype) @ (S * x).astype(dtype)
    ok = np.all(np.isfinite(M))
    return (yh.astype(np.float64) / S), (int(round(float(np.trace(M)))) if ok else -1)

def R_flow(f, cfg, Cn, x, dtype=np.float64):
    S = f["S"]; Hn = frame(f, Cn).astype(dtype); n = Hn.shape[0]
    Sm = np.eye(n, dtype=dtype)
    for l in cfg["Lam"]: Sm = Sm @ (Hn - l * np.eye(n, dtype=dtype))
    Fm = sl.expm(-cfg["t"] * (Sm @ Sm))
    yh = Fm @ (S * x).astype(dtype)
    return (yh.astype(np.float64) / S), int(round(float(np.real(np.trace(Fm)))))

def run_replicas(f, cfg, Csub, x, defect=False, dtype=np.float64, out_round=None):
    """Csub: list of 5 substrate-realised native operators (one per replica)."""
    lo = np.float32 if dtype == np.float32 else np.float64
    outs = [R_eigh(f, cfg, Csub[0], x, np.float64 if dtype == np.float64 else np.float32, None, defect),
            R_eigh(f, cfg, Csub[1], x, np.float32, None, defect),
            R_sign(f, cfg, Csub[2], x, lo),
            R_flow(f, cfg, Csub[3], x, lo),
            R_eigh(f, cfg, Csub[4], x, lo, f["rot"], defect)]
    if out_round is not None: outs = [(out_round(y), k) for y, k in outs]
    return outs

# ----------------------------------------------------------------------------- substrate
def sym_unit(rng, n):
    E = rng.standard_normal((n, n)); E = (E + E.T) / 2; return E / opnorm(E)

def frame_perturbation(f, rng, size, kind):
    G = f["Gap"]; n = 125
    if kind == "goe": return size * sym_unit(rng, n)
    lam = G.lam[rng.integers(len(G.lam))]
    m = G.rest[np.argmin(np.abs(G.rest - lam))]
    iL = np.where(np.abs(G.w - lam) < 1e-6)[0]; iM = np.where(np.abs(G.w - m) < 1e-6)[0]
    u = G.V[:, iL] @ rng.standard_normal(len(iL)); u /= np.linalg.norm(u)
    v = G.V[:, iM] @ rng.standard_normal(len(iM)); v /= np.linalg.norm(v)
    if kind == "rotate": return size * (np.outer(u, v) + np.outer(v, u))
    if kind == "close":
        PM = G.V[:, iM] @ G.V[:, iM].T
        return -size * np.sign(m - lam) * PM
    raise ValueError(kind)

def to_native(f, Eh): return (Eh / f["S"][:, None]) * f["S"][None, :]

def substrate(f, rng, shared_size, shared_kind, jitter):
    Es = frame_perturbation(f, rng, shared_size, shared_kind)
    return [to_native(f, Es + rng.uniform(0, 1) * jitter * sym_unit(rng, 125)) for _ in range(5)]

def bf16(a):
    b = np.asarray(a, np.float32).view(np.uint32)
    b = ((b + np.uint32(0x7FFF) + ((b >> np.uint32(16)) & np.uint32(1))) & np.uint32(0xFFFF0000))
    return b.view(np.float32).astype(np.float64)

def fp8_e4m3(a):
    a = np.asarray(a, np.float64); s = np.sign(a); m = np.abs(a)
    with np.errstate(divide="ignore"):
        e = np.floor(np.log2(np.where(m > 0, m, 1.0)))
    e = np.clip(e, -6, 8)                                  # normal range 2^-6 .. 448; subnormals below
    q = np.round(m / 2.0 ** (e - 3)) * 2.0 ** (e - 3)
    return np.clip(s * q, -448, 448)

# ----------------------------------------------------------------------------- voting & monitors
def pairwise(f, outs, x):
    nx = wnorm(f, x); k = len(outs); D = np.zeros((k, k))
    for i in range(k):
        for j in range(i + 1, k):
            v = outs[i][0] - outs[j][0]
            D[i, j] = D[j, i] = (wnorm(f, v) / nx) if np.all(np.isfinite(v)) else np.inf
    return D

def vote(D, tol):
    k = D.shape[0]; best, bi = -1, None
    for i in range(k):
        c = int(np.sum(D[i] <= tol)) - 0          # includes itself (D[i,i] = 0)
        if c > best: best, bi = c, i
    return (bi if best >= 3 else None), best

class Pipeline:
    def __init__(self, f, auditor):
        self.f, self.aud = f, auditor
        self.ref_P = lagrange(f["C"] if f["name"] == "Cube" else e47_native()[0], f["Lam"], f["nodes"])
        self.tol_vote = None; self.ref_thr = None; self.iso = None; self.iso_thr = None; self.legit_ranks = set()
        self._val_cache = {}

    # ---- the validated residual monitor: exact tolerance tau+rho, reference from runtime data
    def validated_dev(self, cfg, x, y):
        key = (tuple(cfg["Lam"]), id(cfg["C"]))
        if key not in self._val_cache:
            self._val_cache = {key: lagrange(cfg["C"], cfg["Lam"], cfg["nodes"])}
        Pc = self._val_cache[key]
        if not (np.all(np.isfinite(y)) and np.all(np.isfinite(Pc))): return np.inf
        return wnorm(self.f, y - Pc @ x) / wnorm(self.f, x)

    def ref_dev(self, cfg, x, y):
        Pr = self.ref_P if list(cfg["Lam"]) == list(self.f["Lam"]) else lagrange(
            self.f["C"] if self.f["name"] == "Cube" else e47_native()[0], cfg["Lam"], cfg["nodes"])
        if not np.all(np.isfinite(y)): return np.inf
        return wnorm(self.f, y - Pr @ x) / wnorm(self.f, x)

    def features(self, outs, D, bi, x):
        y, rk = outs[bi]
        mass = wnorm(self.f, y) ** 2 / wnorm(self.f, x) ** 2 if np.all(np.isfinite(y)) else 1e9
        spread = np.max(D[np.isfinite(D)]) if np.any(np.isfinite(D)) else 1e9
        return [mass, np.log10(spread + 1e-16)], rk

def wilson(k, n, z=1.96):
    if n == 0: return (0.0, 0.0, 1.0)
    p = k / n; den = 1 + z * z / n; c = (p + z * z / (2 * n)) / den
    h = z * np.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / den
    return (p, max(0.0, c - h), min(1.0, c + h))

# ----------------------------------------------------------------------------- one trial
CLASSES = ["legit", "F1-independent", "CM1a-spec-rank", "CM1b-spec-isospectral-rank", "CM2-operator-file",
           "CM3-shared-helper", "CM4-substrate-drift", "CM5-precision-collapse", "CM6-input-corruption"]

def trial(f, cls, seed):
    rng = np.random.default_rng(seed)
    e0 = f["eps0"]
    xh = rng.standard_normal(125); x_true = xh / f["S"]
    x_seen = x_true.copy()
    kind = rng.choice(["goe", "rotate", "close"])
    shared, jitter = rng.uniform(0, 0.8) * e0, 0.1 * e0
    cfg = config(f); defect = False; dtype = np.float64; out_round = None; in_round = None
    if cls == "CM1a-spec-rank": cfg = config(f, Lam=f["cm1a"])
    if cls == "CM1b-spec-isospectral-rank": cfg = config(f, Lam=f["cm1b"])
    if cls == "CM2-operator-file":
        C = f["C"].copy(); nz = np.argwhere(C != 0); i, j = nz[rng.integers(len(nz))]
        C[i, j] *= 1 + rng.choice([-1, 1]) * 10 ** rng.uniform(-3, 0.5)
        cfg = config(f, C=C)
    if cls == "CM3-shared-helper": defect = True
    if cls == "CM4-substrate-drift":
        shared = rng.uniform(1.25 * e0, 0.6 * f["g"])
    if cls == "CM5-precision-collapse":
        dtype = np.float32; out_round = fp8_e4m3; in_round = fp8_e4m3
    if cls == "CM6-input-corruption":
        d = rng.standard_normal(125) / f["S"]; d *= rng.uniform(0.05, 1.0) * wnorm(f, x_true) / wnorm(f, d)
        x_seen = x_true + d
    Csub = [cfg["C"] + E for E in substrate(f, rng, shared, kind, jitter)]
    if dtype == np.float32: Csub = [bf16(C) for C in Csub]
    x_in = in_round(x_seen) if in_round else x_seen
    outs = run_replicas(f, cfg, Csub, x_in, defect, dtype, out_round)
    if cls == "F1-independent":
        r = rng.integers(5); y = outs[r][0].copy(); i = rng.integers(125)
        b = int(rng.integers(44, 63)); y[i] = np.frombuffer(np.array([y[i]]).view(np.uint64) ^ np.uint64(1 << b), np.float64)[0]
        outs[r] = (y, outs[r][1])
    return dict(cls=cls, seed=seed, x_true=x_true, x_seen=x_seen, outs=outs, cfg=cfg, kind=str(kind),
                shared=float(shared))

def evaluate(P, t):
    f, aud = P.f, P.aud
    x_seen, x_true, outs, cfg = t["x_seen"], t["x_true"], t["outs"], t["cfg"]
    D = pairwise(f, outs, x_seen)
    bi, votes = vote(D, P.tol_vote)
    res = {}
    harm = lambda y: (not aud.accept(x_true, y))           # exact: deviation from P x_true > tau + rho
    dev_true = lambda y: aud.deviation(x_true, y)
    if bi is None:
        for k in ["vote", "+validated", "+anomaly", "+reference", "+auditor"]: res[k] = ("alarm", False)
        delivered = None
    else:
        y = outs[bi][0]; h = harm(y)
        res["vote"] = ("deliver", h)
        res["+validated"] = ("alarm", h) if P.validated_dev(cfg, x_seen, y) > float(aud.thr) else ("deliver", h)
        feat, rk = P.features(outs, D, bi, x_seen)
        bad = (rk not in P.legit_ranks) or (-P.iso.score_samples([feat])[0] > P.iso_thr)
        res["+anomaly"] = ("alarm", h) if bad else ("deliver", h)
        res["+reference"] = ("alarm", h) if P.ref_dev(cfg, x_seen, y) > P.ref_thr else ("deliver", h)
        res["+auditor"] = ("deliver", h) if aud.accept(x_seen, y) else ("alarm", h)
        delivered = y
    sel = next((i for i in range(5) if aud.accept(x_seen, outs[i][0])), None)
    res["auditor-select"] = ("alarm", False) if sel is None else ("deliver", harm(outs[sel][0]))
    rec = {k: v for k, v in res.items()}
    rec["_dev_delivered"] = dev_true(delivered) if delivered is not None else None
    rec["_votes"] = votes
    rec["_scores"] = None
    if bi is not None:
        feat, rk = P.features(outs, D, bi, x_seen)
        rec["_scores"] = dict(anom=float(-P.iso.score_samples([feat])[0]) + (1e3 if rk not in P.legit_ranks else 0),
                              ref=float(P.ref_dev(cfg, x_seen, delivered)),
                              val=float(P.validated_dev(cfg, x_seen, delivered)),
                              cert=float(aud.deviation(x_seen, delivered)),
                              true=float(dev_true(delivered)),
                              harmful=bool(harm(delivered)))
    return rec

def calibrate(P, n_cal, seed0):
    f = P.f; Ds, feats, refs, ranks, devs = [], [], [], [], []
    for s in range(n_cal):
        t = trial(f, "legit", seed0 + s)
        D = pairwise(f, t["outs"], t["x_seen"]); Ds.append(D[np.triu_indices(5, 1)])
        devs.append(max(P.aud.deviation(t["x_true"], y) for y, _ in t["outs"]))
        cal_feats_D = D
        t["D"] = D; feats.append(t); 
    allD = np.concatenate(Ds); allD = allD[np.isfinite(allD)]
    P.tol_vote = 1.25 * float(np.quantile(allD, 0.999))
    X, R = [], []
    for t in feats:
        bi, _ = vote(t["D"], P.tol_vote); bi = 0 if bi is None else bi
        feat, rk = P.features(t["outs"], t["D"], bi, t["x_seen"]); X.append(feat); ranks.append(rk)
        R.append(P.ref_dev(t["cfg"], t["x_seen"], t["outs"][bi][0]))
    P.legit_ranks = set(ranks)
    P.iso = IsolationForest(n_estimators=300, random_state=0).fit(np.array(X))
    sc = -P.iso.score_samples(np.array(X))
    P.iso_thr = float(np.quantile(sc, 0.995))
    P.ref_thr = 1.05 * float(np.quantile(R, 0.995))
    return dict(tol_vote=P.tol_vote, iso_thr=P.iso_thr, ref_thr=P.ref_thr, legit_ranks=sorted(P.legit_ranks),
                max_replica_dev_legit=float(np.max(devs)), q999_replica_dev_legit=float(np.quantile(devs, 0.999)))

def run_family(name, n_test, n_cal, out):
    f = family(name)
    aud = CertifiedAuditor(CERT, f["cert"], f["W"].astype(int) if name == "E47" else np.ones(125, int), f["tau"], RHO)
    P = Pipeline(f, aud)
    t0 = time.time(); cal = calibrate(P, n_cal, 10_000_000); cal["seconds"] = round(time.time() - t0, 1)
    print(f"[{name}] calibration {cal}", flush=True)
    table = {}; raw = {}
    for ci, cls in enumerate(CLASSES):
        t1 = time.time(); recs = []
        for s in range(n_test):
            recs.append(evaluate(P, trial(f, cls, 1_000_000 * (ci + 1) + s)))
        raw[cls] = recs
        row = {}
        for pipe in ["vote", "+validated", "+anomaly", "+reference", "+auditor", "auditor-select"]:
            act = [r[pipe][0] for r in recs]; hm = [r[pipe][1] for r in recs]
            n = len(recs)
            transfer = sum(1 for a, h in zip(act, hm) if a == "deliver" and h)
            alarms = sum(1 for a in act if a == "alarm")
            correct = sum(1 for a, h in zip(act, hm) if a == "deliver" and not h)
            row[pipe] = dict(transfer=wilson(transfer, n), alarm=wilson(alarms, n), correct=wilson(correct, n),
                             k_transfer=transfer, k_alarm=alarms, k_correct=correct, n=n)
        harmful_pre = sum(1 for r in recs if r["vote"][0] == "deliver" and r["vote"][1])
        row["_harmful_delivered_by_vote"] = harmful_pre
        row["_no_majority"] = sum(1 for r in recs if r["vote"][0] == "alarm")
        devs = [r["_dev_delivered"] for r in recs if r["_dev_delivered"] is not None]
        row["_max_dev_delivered"] = float(np.max(devs)) if devs else None
        for pipe in ["vote", "+validated", "+anomaly", "+reference", "+auditor", "auditor-select"]:
            kh = sum(1 for r in recs if r["vote"][0] == "deliver" and r["vote"][1] and r[pipe][0] == "deliver" and r[pipe][1])
            row[pipe]["transfer_given_harmful_vote"] = [kh, harmful_pre]
        table[cls] = row
        print(f"[{name}] {cls:28s} " + "  ".join(f"{p}:{row[p]['k_transfer']:3d}/{row[p]['k_alarm']:3d}"
              for p in ["vote", "+validated", "+anomaly", "+reference", "+auditor", "auditor-select"])
              + f"   (transfer/alarm of {n_test}; {time.time()-t1:.0f}s)", flush=True)
    # tamper test: the auditor must refuse a modified certificate
    raw_bytes = open(CERT, "rb").read(); tampered = 0
    tmpd = os.path.join(HERE, "_tamper"); os.makedirs(tmpd, exist_ok=True)
    rng = np.random.default_rng(5)
    for k in range(50):
        b = bytearray(raw_bytes); pos = int(rng.integers(len(b)))
        while not chr(b[pos]).isdigit(): pos = int(rng.integers(len(b)))
        b[pos] = ord(str((int(chr(b[pos])) + 1 + int(rng.integers(9))) % 10))
        p = os.path.join(tmpd, "native_instances.json"); open(p, "wb").write(bytes(b))
        try:
            CertifiedAuditor(p, f["cert"], f["W"].astype(int) if name == "E47" else np.ones(125, int), f["tau"], RHO)
        except CertificateRefused:
            tampered += 1
    out[name] = dict(calibration=cal, table=table, tamper_refused=[tampered, 50],
                     tau=str(f["tau"]), rho=str(RHO), threshold=float(aud.thr), eps0=f["eps0"], g=f["g"], r=f["r"],
                     certificate_sha256=aud.sha256)
    scores = {cls: [r["_scores"] for r in raw[cls] if r["_scores"] is not None] for cls in CLASSES}
    out[name]["scores"] = scores
    return out

if __name__ == "__main__":
    n_test = int(sys.argv[1]) if len(sys.argv) > 1 else 50
    n_cal = int(sys.argv[2]) if len(sys.argv) > 2 else 200
    fams = sys.argv[3].split(",") if len(sys.argv) > 3 else ["E47", "Cube"]
    out = {}
    for name in fams:
        run_family(name, n_test, n_cal, out)
    tag = "_".join(fams)
    import platform, scipy, sklearn
    prov = dict(python=platform.python_version(), numpy=np.__version__, scipy=scipy.__version__, sklearn=sklearn.__version__,
                sources={fn: hashlib.sha256(open(os.path.join(d, fn), "rb").read()).hexdigest()
                         for d, fn in [(HERE, "bench.py"), (HERE, "auditor.py"), (GEN, "transfer.py"),
                                       (GEN, "native_instances.json"), (GEN, "certified_constants.json")]})
    json.dump(dict(n_test=n_test, n_cal=n_cal, rho=str(RHO), classes=CLASSES, provenance=prov, results=out),
              open(os.path.join(HERE, f"results_{tag}.json"), "w"), indent=1, default=float)
