#!/usr/bin/env python3
"""Build the pinned data layer for Grid (identity/grid/).

Outputs, all under grid/data/ unless noted:

  topology-ieee14.json, topology-ieee118.json
      Canonical bus-branch models of the IEEE 14- and 118-bus test systems,
      read from MATPOWER's case files through PYPOWER. Reactances and tap
      ratios are stored as exact decimal strings so Python and the browser
      rebuild the same rational operator.

  certificate-ieee14.json, certificate-ieee118.json
      General-branch spectral certificates. The DC susceptance Laplacian A has
      rational entries, so A0 = A and eps_r = 0. Exact inertia counts of
      A - sigma*I (sparse LDL^T over the rationals) enclose every eigenvalue
      in a rational interval and certify the window Lambda and its gap g.

  plants-us.json      WRI Global Power Plant Database v1.3.0, US rows.
  us-states.json      us-atlas states-10m (Census cartographic boundaries).
  ba-meta.json        EIA-930 respondent identifiers and names.

  grid/engine/pins.js SHA-256 pins compiled into the browser engine.

Run from the repository root:
  python3 tools/grid/build_grid_data.py --gppd PATH --atlas PATH --ba PATH
"""
import argparse
import csv
import hashlib
import json
import platform
import sys
from fractions import Fraction as F
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "grid" / "data"
ENGINE = ROOT / "grid" / "engine"

SYSTEMS = {
    "ieee14": {"label": "IEEE 14-bus", "case": "case14", "window": [1, 2]},
    "ieee118": {"label": "IEEE 118-bus", "case": "case118", "window": [1, 2]},
}

EPS0_FRACTION_OF_GAP = F(1, 40)   # declared envelope: eps0 = g/40
RHO = F(1, 200)                   # float32 rounding and flow precision


def canonical_bytes(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def sha256(b):
    return hashlib.sha256(b).hexdigest()


def dec(v):
    """Shortest round-trip decimal string of a float (identical to JS String(v))."""
    s = repr(float(v))
    if s.endswith(".0"):
        s = s[:-2]
    return s


# ---------------------------------------------------------------- topology

def load_case(name):
    mod = __import__("pypower." + name, fromlist=[name])
    return getattr(mod, name)()


def topology_from_case(key):
    meta = SYSTEMS[key]
    c = load_case(meta["case"])
    buses = [[int(b[0]), int(b[1]), float(b[2]), float(b[3])] for b in c["bus"]]
    branches = []
    for row in c["branch"]:
        tap = 0.0 if row[8] == 0 else float(row[8])
        branches.append([int(row[0]), int(row[1]), dec(row[3]), dec(tap), int(row[10])])
    gens = [[int(g[0]), float(g[1]), int(g[7] > 0)] for g in c["gen"]]
    return {
        "schema": "KKP-GRID-TOPOLOGY-1.0",
        "system": meta["label"],
        "source": "MATPOWER " + meta["case"] + " (PYPOWER 5.1.21, BSD-3-Clause)",
        "baseMVA": float(c["baseMVA"]),
        "fields": {
            "buses": ["id", "type(1=PQ,2=PV,3=ref)", "Pd_MW", "Qd_MVAr"],
            "branches": ["from", "to", "x_pu(exact decimal)", "tap(exact decimal, 0 means 1)", "status"],
            "gens": ["bus", "Pg_MW", "in_service"],
        },
        "buses": buses,
        "branches": branches,
        "gens": gens,
    }


# ------------------------------------------------------- exact operator

def exact_operator(topo):
    idx = {b[0]: i for i, b in enumerate(topo["buses"])}
    n = len(topo["buses"])
    A = [dict() for _ in range(n)]
    for f, t, x, tap, st in topo["branches"]:
        if st == 0:
            continue
        tau = F(tap) if F(tap) != 0 else F(1)
        b = 1 / (F(x) * tau)
        i, j = idx[f], idx[t]
        for (p, q, v) in ((i, i, b), (j, j, b), (i, j, -b), (j, i, -b)):
            A[p][q] = A[p].get(q, F(0)) + v
    return A, n


def float_matrix(A, n):
    M = np.zeros((n, n))
    for i in range(n):
        for j, v in A[i].items():
            M[i, j] = float(v)
    return M


def min_degree_order(A, n):
    adj = [set(k for k in A[i] if k != i) for i in range(n)]
    order, alive = [], set(range(n))
    while alive:
        v = min(alive, key=lambda i: (len(adj[i]), i))
        order.append(v)
        nb = adj[v]
        for a in nb:
            adj[a] |= nb
            adj[a].discard(a)
            adj[a].discard(v)
        alive.remove(v)
        for a in nb:
            adj[a] &= alive
    return order


def count_below(A, n, sigma, order):
    """Number of eigenvalues of A strictly below sigma, by Sylvester inertia
    of A - sigma I through sparse LDL^T over Q. Returns None on a zero pivot."""
    pos = {v: k for k, v in enumerate(order)}
    M = [dict() for _ in range(n)]
    for i in range(n):
        for j, v in A[i].items():
            M[pos[i]][pos[j]] = v
        M[pos[i]][pos[i]] = M[pos[i]].get(pos[i], F(0)) - sigma
    neg = 0
    for k in range(n):
        d = M[k].get(k, F(0))
        if d == 0:
            return None
        if d < 0:
            neg += 1
        row = {j: v for j, v in M[k].items() if j > k}
        for i, aik in row.items():
            f = aik / d
            Mi = M[i]
            for j, akj in row.items():
                if j < i:
                    continue
                Mi[j] = Mi.get(j, F(0)) - f * akj
                if j != i:
                    M[j][i] = Mi[j]
        M[k] = None
    return neg


def nice_rational(target, below=None, above=None, max_den=10**9):
    """Simplest-looking rational near target, strictly inside (below, above)."""
    for den in (10**3, 10**4, 10**5, 10**6, 10**7, 10**8, max_den):
        q = F(target).limit_denominator(den)
        if (below is None or float(q) > below) and (above is None or float(q) < above):
            return q
    return F(target)


def certify(key, topo):
    A, n = exact_operator(topo)
    Af = float_matrix(A, n)
    w, V = np.linalg.eigh(Af)
    order = min_degree_order(A, n)
    lo_i, hi_i = SYSTEMS[key]["window"]
    r = hi_i - lo_i + 1
    scale = max(1.0, float(np.max(np.abs(w))))

    separators = []

    def add(sigma, expect, role):
        got = count_below(A, n, sigma, order)
        bump = 0
        while got is None:  # zero pivot: move sigma by a hair inside the same gap
            bump += 1
            sigma = sigma + F(1, 10**(12 - bump))
            got = count_below(A, n, sigma, order)
        if got != expect:
            raise SystemExit(f"{key}: inertia count {got} != expected {expect} at sigma={sigma} ({role})")
        separators.append({"sigma": str(sigma), "below": got, "role": role})
        return sigma

    # Every eigenvalue enclosed: separators between consecutive float eigenvalues.
    add(F(-1, 10**6), 0, "floor")
    for k in range(1, n):
        if w[k] - w[k - 1] < 1e-9 * scale:
            continue  # numerically repeated: enclosed together by the next separator
        mid = (w[k - 1] + w[k]) / 2
        add(nice_rational(mid, w[k - 1], w[k]), k, "between")
    add(nice_rational(w[-1] + 1.0, w[-1], None), n, "ceiling")

    # Tight enclosure of Lambda and its neighbours.
    delta = 1e-7 * scale
    L = add(nice_rational(w[lo_i] - delta, w[lo_i - 1], w[lo_i]), lo_i, "lambda-lower")
    U = add(nice_rational(w[hi_i] + delta, w[hi_i], w[hi_i + 1]), hi_i + 1, "lambda-upper")
    Vn = add(nice_rational(w[hi_i + 1] - delta, w[hi_i], w[hi_i + 1]), hi_i + 1, "next-lower")
    # Neighbour below Lambda is the exact zero mode (A 1 = 0); its upper bound is 0.
    below_top = F(0)
    if lo_i - 1 != 0:
        raise SystemExit("window must sit directly above the zero mode for this certificate form")
    g_below = L - below_top
    g_above = Vn - U
    g = min(g_below, g_above)
    eps0 = g * EPS0_FRACTION_OF_GAP
    s = eps0 / (g - eps0)
    tol = s + RHO

    seps = sorted(separators, key=lambda d: F(d["sigma"]))
    intervals = []
    for a, b in zip(seps, seps[1:]):
        m = b["below"] - a["below"]
        if m > 0:
            intervals.append({"lo": a["sigma"], "hi": b["sigma"], "count": m})

    U_basis = V[:, lo_i:hi_i + 1].copy()
    for c in range(U_basis.shape[1]):
        j = int(np.argmax(np.abs(U_basis[:, c])))
        if U_basis[j, c] < 0:
            U_basis[:, c] *= -1
    orth = float(np.max(np.abs(U_basis.T @ U_basis - np.eye(r))))

    return {
        "schema": "KKP-GRID-CERTIFICATE-1.0",
        "system": SYSTEMS[key]["label"],
        "topology": {"file": f"topology-{key}.json", "sha256": sha256(canonical_bytes(topo))},
        "operator": {
            "name": "DC susceptance Laplacian",
            "definition": "A = sum over in-service branches of (1/(x*tau)) (e_from - e_to)(e_from - e_to)^T; tau = 1 when the tap field is 0",
            "inner_product": "<x,y>_W = x^T W y with W = I",
            "n": n,
            "exact_null_vector": "A 1 = 0 (each row sums to zero over Q)",
        },
        "window": {
            "statement": f"Lambda = {{lambda_{lo_i + 1}, lambda_{hi_i + 1}}} of A in ascending order: the two slowest non-trivial (inter-area) modes",
            "indices": [lo_i, hi_i],
            "r": r,
            "enclosure": {"lo": str(L), "hi": str(U)},
            "neighbours": {"below": "0 (exact zero mode)", "above_lower_bound": str(Vn)},
        },
        "branch": "general",
        "eps_r": "0",
        "branch_note": "A has rational entries (exact decimal reactances and taps), so the rational surrogate A0 equals A and eps_r = 0.",
        "separators": separators,
        "intervals": intervals,
        "gap": {"below": str(g_below), "above": str(g_above), "g": str(g), "g_float": float(g)},
        "envelope": {
            "eps0": str(eps0), "eps0_float": float(eps0),
            "eps0_rule": "eps0 = g/40, declared for this deployment",
            "rho": str(RHO),
            "s_eps0": str(s), "s_rule": "s(eps) = eps/(g - eps): Davis-Kahan sin-Theta bound with the Weyl-shifted gap",
            "tolerance": str(tol), "tolerance_float": float(tol),
        },
        "transfer": "For A_hat with eps = ||A_hat - A|| < g/2, exactly r eigenvalues of A_hat lie within g/2 of Lambda (Weyl), and the window projector moves by at most s(eps) (Davis-Kahan). Radius g/2 is sharp.",
        "basis": {
            "note": "Orthonormal float64 basis of the Lambda-eigenspace of A; P_d = U U^T.",
            "orthonormality_defect": orth,
            "U": [[float(f"{v:.17g}") for v in row] for row in U_basis.tolist()],
        },
        "eigenvalue_estimates": [float(f"{v:.12g}") for v in w.tolist()],
        "elimination_order": order,
        "generated_by": {
            "tool": "tools/grid/build_grid_data.py",
            "python": platform.python_version(),
            "numpy": np.__version__,
        },
    }


# --------------------------------------------------------- map layers

FUEL_CODES = {
    "Solar": "SUN", "Gas": "NG", "Hydro": "WAT", "Wind": "WND", "Oil": "OIL",
    "Waste": "WST", "Coal": "COL", "Biomass": "BIO", "Storage": "BAT",
    "Geothermal": "GEO", "Nuclear": "NUC", "Cogeneration": "CHP", "Other": "OTH",
    "Petcoke": "PET",
}


def build_plants(gppd_path):
    rows = []
    with open(gppd_path, encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            if r["country"] != "USA":
                continue
            rows.append([
                round(float(r["longitude"]), 4), round(float(r["latitude"]), 4),
                round(float(r["capacity_mw"]), 1), FUEL_CODES.get(r["primary_fuel"], "OTH"),
                r["name"], r["gppd_idnr"],
            ])
    rows.sort(key=lambda t: -t[2])
    return {
        "schema": "KKP-GRID-PLANTS-1.0",
        "source": "WRI Global Power Plant Database v1.3.0 (CC BY 4.0); US rows from EIA-860, capacity year 2019",
        "url": "https://github.com/wri/global-power-plant-database",
        "fields": ["lon", "lat", "capacity_mw", "fuel", "name", "gppd_id"],
        "fuels": {v: k for k, v in FUEL_CODES.items()},
        "count": len(rows),
        "total_mw": round(sum(t[2] for t in rows), 1),
        "rows": rows,
    }


def decode_topojson_states(path, precision=3):
    topo = json.load(open(path, encoding="utf-8"))
    sx, sy = topo["transform"]["scale"]
    tx, ty = topo["transform"]["translate"]
    arcs = []
    for arc in topo["arcs"]:
        x = y = 0
        pts = []
        for dx, dy in arc:
            x += dx
            y += dy
            pts.append((round(x * sx + tx, precision), round(y * sy + ty, precision)))
        arcs.append(pts)

    def ring(idxs):
        out = []
        for a in idxs:
            pts = arcs[a] if a >= 0 else list(reversed(arcs[~a]))
            if out:
                pts = pts[1:]
            out.extend(pts)
        dedup = [out[0]]
        for p in out[1:]:
            if p != dedup[-1]:
                dedup.append(p)
        return [list(p) for p in dedup]

    feats = []
    for g in topo["objects"]["states"]["geometries"]:
        if g["type"] == "Polygon":
            geom = {"type": "Polygon", "coordinates": [ring(r) for r in g["arcs"]]}
        elif g["type"] == "MultiPolygon":
            geom = {"type": "MultiPolygon", "coordinates": [[ring(r) for r in p] for p in g["arcs"]]}
        else:
            continue
        feats.append({"type": "Feature", "id": g.get("id"),
                      "properties": {"name": g.get("properties", {}).get("name")}, "geometry": geom})
    return {"type": "FeatureCollection",
            "source": "us-atlas 3.0.1 states-10m (U.S. Census Bureau cartographic boundary files, ISC)",
            "features": feats}


def build_ba(path):
    d = json.load(open(path, encoding="utf-8"))
    rows = sorted(([k, v.get("Type"), v.get("Name")] for k, v in d.items()), key=lambda t: (t[1] != "Region", t[0]))
    return {"schema": "KKP-GRID-BA-1.0",
            "source": "EIA Hourly Electric Grid Monitor respondents (EIA-930), as listed in gridstatus 0.37.0 metadata (BSD-3-Clause)",
            "fields": ["id", "type", "name"], "rows": rows}


# -------------------------------------------------------------- main

def cm2_survey(key, topo):
    """Every single-entry status flip of the runtime file, ranked by how far it moves the
    window component of the nominal DC state (not pinned; used to choose live demos)."""
    A, n = exact_operator(topo)
    base = float_matrix(A, n)
    lo, hi = SYSTEMS[key]["window"]
    def proj(M):
        w, V = np.linalg.eigh(M)
        U = V[:, lo:hi + 1]
        return U @ U.T
    idx = {b[0]: i for i, b in enumerate(topo["buses"])}
    ref = [i for i, b in enumerate(topo["buses"]) if b[1] == 3][0]
    P = np.zeros(n)
    for b in topo["buses"]:
        P[idx[b[0]]] -= b[2] / topo["baseMVA"]
    for bus, pg, on in topo["gens"]:
        if on:
            P[idx[bus]] += pg / topo["baseMVA"]
    keep = [i for i in range(n) if i != ref]
    x = np.zeros(n)
    x[keep] = np.linalg.solve(base[np.ix_(keep, keep)], P[keep])
    Pd = proj(base)
    out = []
    for k, br in enumerate(topo["branches"]):
        t2 = dict(topo)
        t2["branches"] = [list(b) for b in topo["branches"]]
        t2["branches"][k][4] = 1 - t2["branches"][k][4]
        A2, _ = exact_operator(t2)
        M = float_matrix(A2, n)
        if np.linalg.eigvalsh(M)[1] < 1e-9:
            out.append({"k": k, "from": br[0], "to": br[1], "islanding": True})
            continue
        d = float(np.linalg.norm(proj(M) @ x - Pd @ x) / np.linalg.norm(x))
        out.append({"k": k, "from": br[0], "to": br[1], "dev": round(d, 6)})
    out.sort(key=lambda r: -(r.get("dev") or -1))
    return {"system": SYSTEMS[key]["label"], "note": "Deviation of the window component of the nominal DC state when one branch status is flipped in the runtime file.", "flips": out}


def write(path, obj):
    b = canonical_bytes(obj)
    path.write_bytes(b)
    return sha256(b), len(b)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gppd", required=True)
    ap.add_argument("--atlas", required=True)
    ap.add_argument("--ba", required=True)
    args = ap.parse_args()
    DATA.mkdir(parents=True, exist_ok=True)
    pins = {}
    for key in SYSTEMS:
        topo = topology_from_case(key)
        h, size = write(DATA / f"topology-{key}.json", topo)
        pins[f"topology-{key}.json"] = h
        cert = certify(key, topo)
        assert cert["topology"]["sha256"] == h
        h2, size2 = write(DATA / f"certificate-{key}.json", cert)
        pins[f"certificate-{key}.json"] = h2
        write(DATA / f"cm2-survey-{key}.json", cm2_survey(key, topo))
        print(f"{key}: n={cert['operator']['n']} g={cert['gap']['g_float']:.6f} "
              f"tol={cert['envelope']['tolerance_float']:.6f} separators={len(cert['separators'])} "
              f"topology {size} B, certificate {size2} B")
    h, size = write(DATA / "plants-us.json", build_plants(args.gppd))
    print("plants", size, "B")
    h, size = write(DATA / "us-states.json", decode_topojson_states(args.atlas))
    print("states", size, "B")
    h, size = write(DATA / "ba-meta.json", build_ba(args.ba))
    print("ba", size, "B")

    lines = ["// GENERATED by tools/grid/build_grid_data.py. Do not edit by hand.",
             "// SHA-256 pins of the certificate files and the topology models used to build A.",
             "// The runtime topology file is deliberately not pinned: a runtime edit changes A, not the certificate.",
             "export const PINS = Object.freeze(" + json.dumps(pins, indent=2, sort_keys=True) + ");", ""]
    (ENGINE / "pins.js").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps(pins, indent=1))


if __name__ == "__main__":
    sys.exit(main())
