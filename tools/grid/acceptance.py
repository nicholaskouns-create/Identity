#!/usr/bin/env python3
"""Reference implementation of the Grid acceptance protocol (KKP-GRID-ACCEPTANCE-1.0).

The browser engine (grid/engine/monitor.js) runs the same protocol with the
same random stream (tools/grid/prng.py == grid/engine/prng.js). This file uses
numpy's LAPACK eigensolver for R1, R2 and R5, so agreement with the browser is
agreement between independent implementations, not a replay of one codebase.

Fault classes (the names are this deployment's own; only CM2 and CM6 follow
the definitions given in the Grid application note):
  L0   legitimate: shared substrate perturbation <= 0.8 eps0, jitter <= 0.1 eps0
  CM2  one entry of the shared runtime topology file altered (a branch status
       flipped); each replica independently untouched with probability 0.15
  H1   shared window-selection helper defect (R1, R2, R5 select the next r modes)
  E1   substrate drift beyond the declared envelope: 2 eps0 to 6 eps0 (< g/2)
  CM6  input integrity: the state vector itself is spoofed inside the window

Pipelines compared: voting, validated residual, independent reference,
anomaly detector, certified auditor (deliver / select / refuse).

Usage: python3 tools/grid/acceptance.py --trials14 1200 --trials118 200
"""
import argparse
import json
import math
import platform
import sys
from fractions import Fraction as F
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prng import Stream  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "grid" / "data"
CLASSES = ["L0", "CM2", "H1", "E1", "CM6"]
PIPES = ["voting", "validated_residual", "independent_reference", "anomaly_detector", "certified_auditor"]
P_UNTOUCHED = 0.15
SIGMA_PMU = 0.002
SPOOF = 0.25
R4_ITERS = 60
NS_ITERS = 40


def fmix32(h):
    h &= 0xFFFFFFFF
    h ^= h >> 16
    h = (h * 0x85EBCA6B) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * 0xC2B2AE35) & 0xFFFFFFFF
    h ^= h >> 16
    return h


def trial_seed(seed, cls_index, t):
    return fmix32((seed + 0x9E3779B9 * (cls_index + 1) + 0x7F4A7C15 * (t + 1)) & 0xFFFFFFFF)


# ------------------------------------------------------------ system

class System:
    def __init__(self, key):
        self.key = key
        self.topo = json.loads((DATA / f"topology-{key}.json").read_text())
        self.cert = json.loads((DATA / f"certificate-{key}.json").read_text())
        self.n = len(self.topo["buses"])
        self.idx = {b[0]: i for i, b in enumerate(self.topo["buses"])}
        self.ref = [i for i, b in enumerate(self.topo["buses"]) if b[1] == 3][0]
        env = self.cert["envelope"]
        self.g = float(F(self.cert["gap"]["g"]))
        self.eps0 = float(F(env["eps0"]))
        self.tol = float(F(env["tolerance"]))
        w = self.cert["window"]
        self.r = w["r"]
        self.lo_i = w["indices"][0]
        self.lam_lo = float(F(w["enclosure"]["lo"]))
        self.lam_hi = float(F(w["enclosure"]["hi"]))
        self.win_lo = self.lam_lo - self.g / 2
        self.win_hi = self.lam_hi + self.g / 2
        self.mu = (self.lam_lo + self.lam_hi) / 2
        U = np.array(self.cert["basis"]["U"])
        self.Pd = U @ U.T
        self.A = self.operator(self.topo["branches"])
        self.nonisland = [k for k in range(len(self.topo["branches"])) if self._flip_ok(k)]
        st = Stream(0x5EED0000 + self.n)
        self.V0 = np.array([[st.normal() for _ in range(self.r)] for _ in range(self.n)])

    def operator(self, branches):
        A = np.zeros((self.n, self.n))
        for f, t, x, tap, s in branches:
            if s == 0:
                continue
            tau = float(tap) if float(tap) != 0 else 1.0
            b = 1.0 / (float(x) * tau)
            i, j = self.idx[f], self.idx[t]
            A[i, i] += b
            A[j, j] += b
            A[i, j] -= b
            A[j, i] -= b
        return A

    def flipped(self, k):
        br = [list(b) for b in self.topo["branches"]]
        br[k][4] = 1 - br[k][4]
        return br

    def _flip_ok(self, k):
        w = np.linalg.eigvalsh(self.operator(self.flipped(k)))
        return w[1] > 1e-9

    def state(self, scale):
        P = np.zeros(self.n)
        base = self.topo["baseMVA"]
        for b in self.topo["buses"]:
            P[self.idx[b[0]]] -= b[2] * scale / base
        for bus, pg, on in self.topo["gens"]:
            if on:
                P[self.idx[bus]] += pg * scale / base
        keep = [i for i in range(self.n) if i != self.ref]
        th = np.zeros(self.n)
        th[keep] = np.linalg.solve(self.A[np.ix_(keep, keep)], P[keep])
        return th


def sym_noise(st, n):
    S = np.zeros((n, n))
    for i in range(n):
        for j in range(i, n):
            v = st.normal()
            S[i, j] = v
            S[j, i] = v
    return S


def spectral_norm(S):
    w = np.linalg.eigvalsh(S)
    return float(max(abs(w[0]), abs(w[-1])))


def helper_window(sysm, w, V, defect=False):
    if defect:
        k = sysm.lo_i + 1
        return V[:, k:k + sysm.r]
    sel = [i for i in range(len(w)) if sysm.win_lo <= w[i] <= sysm.win_hi]
    return V[:, sel]


def proj_eig(sysm, A, defect=False):
    w, V = np.linalg.eigh(A)
    U = helper_window(sysm, w, V, defect)
    return U @ U.T


def sign_newton(M):
    X = M.copy()
    n = X.shape[0]
    for _ in range(NS_ITERS):
        Xi = np.linalg.inv(X)
        _, logdet = np.linalg.slogdet(X)
        mu = math.exp(-logdet / n) if math.isfinite(logdet) else 1.0
        Xn = 0.5 * (mu * X + Xi / mu)
        if np.linalg.norm(Xn - X, 1) <= 1e-14 * np.linalg.norm(Xn, 1):
            X = Xn
            break
        X = Xn
    return X


def proj_sign(sysm, A):
    # One sign evaluation: (U I - A)(A - L I) is positive exactly on the window (L, U).
    I = np.eye(sysm.n)
    return 0.5 * (I + sign_newton((sysm.win_hi * I - A) @ (A - sysm.win_lo * I)))


def proj_resolvent(sysm, A):
    M = A - sysm.mu * np.eye(sysm.n)
    V = sysm.V0.copy()
    for _ in range(R4_ITERS):
        V = np.linalg.solve(M, V)
        V, _ = np.linalg.qr(V)
    return V @ V.T


def vote(ys, xnorm, tol):
    best = None
    for i in range(len(ys)):
        group = [j for j in range(len(ys)) if np.linalg.norm(ys[j] - ys[i]) / xnorm <= tol]
        if best is None or len(group) > len(best):
            best = group
    if len(best) >= 3:
        return np.mean([ys[j] for j in best], axis=0), best
    return None, best


def run_trial(sysm, cls, seed, cache):
    st = Stream(seed)
    n = sysm.n
    scale = 0.85 + 0.30 * st.uniform()
    x_true = sysm.state(scale)
    eta = np.array([st.normal() for _ in range(n)]) * SIGMA_PMU
    x_meas = x_true + eta
    runtime = sysm.topo["branches"]
    untouched = [False] * 5
    flipped_branch = None
    if cls == "CM2":
        k = sysm.nonisland[st.int_below(len(sysm.nonisland))]
        runtime = sysm.flipped(k)
        flipped_branch = k
        untouched = [st.uniform() < P_UNTOUCHED for _ in range(5)]
    x_rec = x_meas
    if cls == "CM6":
        c = np.array([st.normal() for _ in range(sysm.r)])
        c /= np.linalg.norm(c)
        U = np.array(sysm.cert["basis"]["U"])
        x_rec = x_meas + SPOOF * np.linalg.norm(x_meas) * (U @ c)
    A_rt = sysm.operator(runtime) if cls == "CM2" else sysm.A
    S = sym_noise(st, n)
    u2 = st.uniform()
    mag = (2 + 4 * u2) * sysm.eps0 if cls == "E1" else 0.8 * sysm.eps0 * u2
    Es = S * (mag / spectral_norm(S))
    Ej = []
    for _ in range(5):
        J = sym_noise(st, n)
        v = st.uniform()
        Ej.append(J * (0.1 * sysm.eps0 * v / spectral_norm(J)))
    defect = cls == "H1"
    Ahat = [(sysm.A if untouched[i] else A_rt) + Es + Ej[i] for i in range(5)]
    ys = [
        proj_eig(sysm, Ahat[0], defect) @ x_rec,
        proj_eig(sysm, Ahat[1], defect) @ x_rec,
        proj_sign(sysm, Ahat[2]) @ x_rec,
        proj_resolvent(sysm, Ahat[3]) @ x_rec,
        proj_eig(sysm, Ahat[4], defect) @ x_rec,
    ]
    xr = np.linalg.norm(x_rec)
    dev = [float(np.linalg.norm(y - sysm.Pd @ x_rec) / xr) for y in ys]
    y_true = sysm.Pd @ x_meas
    xm = np.linalg.norm(x_meas)

    def harmful(y):
        return float(np.linalg.norm(y - y_true) / xm) > sysm.tol

    yv, group = vote(ys, xr, sysm.tol)
    key = (cls, flipped_branch)
    if key not in cache:
        cache[key] = (proj_eig(sysm, A_rt, defect), proj_sign(sysm, A_rt))
    P_rt, P_ref = cache[key]
    out = {"dev": dev, "group": group, "vote": yv is not None}
    res = {}
    res["voting"] = ("deliver", harmful(yv)) if yv is not None else ("refuse", False)
    if yv is None:
        for p in ("validated_residual", "independent_reference", "anomaly_detector"):
            res[p] = ("refuse", False)
    else:
        d_rt = float(np.linalg.norm(yv - P_rt @ x_rec) / xr)
        res["validated_residual"] = ("deliver", harmful(yv)) if d_rt <= sysm.tol else ("refuse", False)
        d_ref = float(np.linalg.norm(yv - P_ref @ x_rec) / xr)
        res["independent_reference"] = ("deliver", harmful(yv)) if d_ref <= sysm.tol else ("refuse", False)
        ratio = float(np.linalg.norm(yv) / xr)
        mu_r, sd_r = cache["anomaly_band"]
        res["anomaly_detector"] = ("deliver", harmful(yv)) if abs(ratio - mu_r) <= 4 * sd_r else ("refuse", False)
    dv = float(np.linalg.norm(yv - sysm.Pd @ x_rec) / xr) if yv is not None else None
    if dv is not None and dv <= sysm.tol:
        res["certified_auditor"] = ("deliver", harmful(yv))
        out["auditor"] = "deliver"
    else:
        sel = next((i for i in range(5) if dev[i] <= sysm.tol), None)
        if sel is None:
            res["certified_auditor"] = ("refuse", False)
            out["auditor"] = "refuse"
        else:
            res["certified_auditor"] = ("deliver", harmful(ys[sel]))
            out["auditor"] = f"select_R{sel + 1}"
    out["pipelines"] = res
    out["vote_dev"] = dv
    out["truth_harm_vote"] = harmful(yv) if yv is not None else None
    return out


def calibrate_anomaly(sysm, seed, m=50):
    ratios = []
    for t in range(m):
        st = Stream(fmix32(seed ^ 0xA5A5A5A5 ^ t))
        scale = 0.85 + 0.30 * st.uniform()
        x = sysm.state(scale) + np.array([st.normal() for _ in range(sysm.n)]) * SIGMA_PMU
        ratios.append(float(np.linalg.norm(sysm.Pd @ x) / np.linalg.norm(x)))
    return float(np.mean(ratios)), float(np.std(ratios) + 1e-12)


def run(key, trials, seed):
    sysm = System(key)
    cache = {"anomaly_band": calibrate_anomaly(sysm, seed)}
    table = {}
    trial_log = []
    for ci, cls in enumerate(CLASSES):
        agg = {p: {"delivered": 0, "harmful_passed": 0, "refused": 0} for p in
               ("voting", "validated_residual", "independent_reference", "anomaly_detector", "certified_auditor")}
        selected = 0
        refused_auditor = 0
        largest_legit = 0.0
        harmful_truth = 0
        for t in range(trials):
            o = run_trial(sysm, cls, trial_seed(seed, ci, t), cache)
            for p, (d, h) in o["pipelines"].items():
                if d == "deliver":
                    agg[p]["delivered"] += 1
                    agg[p]["harmful_passed"] += int(h)
                else:
                    agg[p]["refused"] += 1
            if o["auditor"].startswith("select"):
                selected += 1
            if o["auditor"] == "refuse":
                refused_auditor += 1
            if o["truth_harm_vote"]:
                harmful_truth += 1
            if cls == "L0":
                largest_legit = max(largest_legit, max(o["dev"]), o["vote_dev"] or 0.0)
            trial_log.append([cls, t, o["auditor"]] + [int(o["pipelines"][p][0] == "deliver") for p in PIPES])
        table[cls] = {
            "trials": trials,
            "voted_output_harmful": harmful_truth,
            "pipelines": agg,
            "auditor_selected": selected,
            "auditor_refused": refused_auditor,
        }
        if cls == "L0":
            table[cls]["auditor_false_alarms"] = trials - agg["certified_auditor"]["delivered"] + selected
            table[cls]["largest_legitimate_dev"] = largest_legit
        print(key, cls, json.dumps({k: v for k, v in table[cls].items() if k != "pipelines"}),
              {p: v["harmful_passed"] for p, v in agg.items()})
    return {
        "system": sysm.cert["system"],
        "n": sysm.n,
        "tolerance": sysm.cert["envelope"]["tolerance"],
        "tolerance_float": sysm.tol,
        "g": sysm.cert["gap"]["g"],
        "eps0": sysm.cert["envelope"]["eps0"],
        "seed": seed,
        "classes": table,
        "trials_per_class": trials,
        "decisions_sha256": __import__("hashlib").sha256(json.dumps(trial_log, separators=(",", ":")).encode()).hexdigest(),
        "decisions": trial_log,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--trials14", type=int, default=240)
    ap.add_argument("--trials118", type=int, default=40)
    ap.add_argument("--seed", type=int, default=47)
    ap.add_argument("--out", default=str(DATA / "reference-acceptance.json"))
    a = ap.parse_args()
    res = {
        "schema": "KKP-GRID-ACCEPTANCE-1.0",
        "implementation": "Python reference (numpy LAPACK eigensolver for R1, R2, R5)",
        "python": platform.python_version(),
        "numpy": np.__version__,
        "protocol": {
            "classes": CLASSES, "p_untouched": P_UNTOUCHED, "sigma_pmu_rad": SIGMA_PMU, "spoof_fraction": SPOOF,
            "vote": "largest group within tolerance, majority >= 3 of 5, output = group mean",
            "harmful": "delivered y with ||y - P_d x_meas|| / ||x_meas|| > tolerance",
        },
        "systems": {
            "ieee14": run("ieee14", a.trials14, a.seed),
            "ieee118": run("ieee118", a.trials118, a.seed),
        },
    }
    Path(a.out).write_text(json.dumps(res, indent=1))
    print("wrote", a.out)


if __name__ == "__main__":
    main()
