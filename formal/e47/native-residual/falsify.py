"""
Randomised falsification of Theorem G (transfer half) across operator families.
Every check is an inequality the theorem asserts; a single violation would refute it.
Writes falsification_results.json.
"""
import numpy as np, json, time, sys
from transfer import *

rng = np.random.default_rng(20261120)
TOL_REL, TOL_ABS = 1e-9, 1e-11

def sym_gauss(n): E = rng.standard_normal((n, n)); return (E + E.T) / 2
def scaled(E, eps): return E * (eps / opnorm(E))

def closest_pair(G):
    """eigenvectors of a Lam-eigenvalue and a rest eigenvalue at distance g (a binding pair)."""
    best = None
    for l in G.lam:
        for m in G.rest:
            if best is None or abs(l - m) < best[0]: best = (abs(l - m), l, m)
    _, l, m = best
    il = int(np.argmin(np.abs(G.w - l))); im = int(np.argmin(np.abs(G.w - m)))
    Pl = sum(np.outer(G.V[:, i], G.V[:, i]) for i in range(G.n) if abs(G.w[i] - l) <= 1e-6 * max(1, abs(l)))
    Pm = sum(np.outer(G.V[:, i], G.V[:, i]) for i in range(G.n) if abs(G.w[i] - m) <= 1e-6 * max(1, abs(m)))
    return l, m, G.V[:, il], G.V[:, im], Pl, Pm

def perturbation(kind, G, eps):
    n = G.n
    l, m, u, v, Pl, Pm = closest_pair(G)
    if kind == 'goe':     return scaled(sym_gauss(n), eps)
    if kind == 'rotate':  return eps * (np.outer(u, v) + np.outer(v, u))
    if kind == 'close':   return eps * np.sign(m - l) * (Pl - Pm)
    if kind == 'shift':   return eps * rng.choice([-1, 1]) * np.eye(n)
    if kind == 'mixed':   return scaled(eps * (np.outer(u, v) + np.outer(v, u)) + eps * np.sign(m - l) * (Pl - Pm)
                                        + 0.3 * scaled(sym_gauss(n), eps), eps)
    if kind == 'nonsym':  return scaled(rng.standard_normal((n, n)), eps)
    if kind == 'nonnormal': return scaled(np.outer(u, v) * 3 + 0.2 * scaled(rng.standard_normal((n, n)), 1), eps)
    raise ValueError(kind)

def matpoly(p, M):
    R = np.zeros_like(M); I = np.eye(M.shape[0])
    for c in p.coef[::-1]: R = R @ M + c * I
    return R

def check_family(name, A, lam, reps, fracs, kinds):
    G = Gap(A, lam)
    s = G.selector()
    c = 0.5 * (G.w.min() + G.w.max()); R0 = G.spectral_radius_about(c)
    sA = matpoly(s, G.A)
    rec = {'name': name, 'n': G.n, 'r': G.r, 'g': G.g, 'deltas': G.deltas, 'Lam': list(map(float, G.lam)),
           'checks': {}, 'max_ratio': {}, 'trials': 0}
    def note(key, actual, bound):
        ok = actual <= bound * (1 + TOL_REL) + TOL_ABS
        d = rec['checks'].setdefault(key, [0, 0]); d[0] += 1; d[1] += (not ok)
        if np.isfinite(bound) and bound > 0:
            rec['max_ratio'][key] = max(rec['max_ratio'].get(key, 0.0), actual / bound)
        return ok
    for kind in kinds:
        for f in fracs:
            eps = f * G.g / 2
            for _ in range(reps):
                E = perturbation(kind, G, eps)
                Ah = G.A + E
                rec['trials'] += 1
                if kind in ('nonsym', 'nonnormal'):
                    note('occupancy_complex', abs(G.occupancy(Ah) - G.r), 0.0)
                    Pr, k = G.riesz_projector(Ah)
                    note('riesz_projector', opnorm(Pr - G.P), G.riesz_bound(eps))
                    continue
                note('occupancy_real', abs(G.occupancy(Ah) - G.r), 0.0)
                Ph, w, V, sel = G.window_projector(Ah)
                note('davis_kahan_l2', opnorm(Ph - G.P), G.dk_bound(eps))
                eta, gam = G.eta_gamma(s, eps)
                ts = G.best_time(eta, gam)
                if ts is not None:
                    for t in (ts / 8, ts, 8 * ts):
                        F = (V * np.exp(-t * s(w)**2)) @ V.T
                        note('flow_window', opnorm(F - Ph), G.flow_bound(eta, gam, t))
                note('buoy_telescoping', opnorm(matpoly(s, Ah) - sA), telescoping_bound(s, c, R0, eps))
    # native residual two-sided inequality, exact case (q = s vanishes on Lam)
    gamK = float(np.min(np.abs(s(G.rest)))); kapK = float(np.max(np.abs(s(G.rest))))
    for _ in range(200):
        x = rng.standard_normal(G.n)
        res = np.linalg.norm(sA @ x); comp = np.linalg.norm(x - G.P @ x)
        note('residual_lower', gamK * comp, res)
        note('residual_upper', res, kapK * comp)
    rec['gamma_K'] = gamK; rec['kappa_K'] = kapK
    return rec

def sharpness(G, label):
    """(a) occupancy radius g/2 is sharp; (b) telescoping bound attained by the uniform shift."""
    l, m, u, v, Pl, Pm = closest_pair(G)
    out = {}
    for f in (0.999, 1.001):
        eps = f * G.g / 2
        out[f'occupancy_at_{f}g/2'] = G.occupancy(G.A - eps * np.sign(m - l) * Pm)
    s = G.selector(); c = 0.5 * (G.w.min() + G.w.max()); R0 = G.spectral_radius_about(c)
    ratios = []
    for eps in (0.01, 0.1, 0.5, 0.9) :
        eps = eps * G.g / 2
        best = max(opnorm(matpoly(s, G.A + sg * eps * np.eye(G.n)) - matpoly(s, G.A)) for sg in (-1, 1))
        ratios.append(best / telescoping_bound(s, c, R0, eps))
    out['telescoping_ratio_uniform_shift'] = ratios
    out['r'] = G.r
    return out

if __name__ == '__main__':
    t0 = time.time()
    reps = int(sys.argv[1]) if len(sys.argv) > 1 else 12
    fracs = [0.05, 0.2, 0.5, 0.8, 0.95, 0.999]
    kinds = ['goe', 'rotate', 'close', 'shift', 'mixed', 'nonsym', 'nonnormal']
    C, W = e47_native(); H, S = to_frame(C, W)
    K = (H - 6 * np.eye(125)) @ (H - 30 * np.eye(125))
    L = cube_laplacian(); a, b = (5 - 5**.5) / 2, (5 + 5**.5) / 2
    Hh = heisenberg_ring(8); w0 = float(np.linalg.eigvalsh(Hh)[0])
    fams = [('E47 Casimir, W-frame, Lam={6,30}', H, [6., 30.]),
            ('E47 K-level buoy, Lam={0}', K, [0.]),
            ('Professor\'s Cube Laplacian, golden cluster', L, [a, b]),
            ('Heisenberg ring n=8, ground state (numeric gap)', Hh, [w0])]
    for i in range(6):
        A, vals, centres, mult = planted(rng, 40, 7, spread=0.0)
        k = int(rng.integers(1, 6)); idx = sorted(rng.choice(7, k, replace=False))
        fams.append((f'planted random n=40 #{i+1}, |Lam|={k}', A, list(centres[idx])))
    results = []
    for name, A, lam in fams:
        t1 = time.time()
        rec = check_family(name, A, lam, reps, fracs, kinds)
        G = Gap(A, lam); rec['sharpness'] = sharpness(G, name)
        rec['seconds'] = round(time.time() - t1, 1)
        viol = sum(v[1] for v in rec['checks'].values()); tot = sum(v[0] for v in rec['checks'].values())
        print(f"{name:55s} r={rec['r']:3d} g={rec['g']:.6g}  checks={tot:6d} violations={viol}  "
              f"maxratio DK={rec['max_ratio'].get('davis_kahan_l2',0):.3f} Riesz={rec['max_ratio'].get('riesz_projector',0):.3f} "
              f"flow={rec['max_ratio'].get('flow_window',0):.3f} buoy={rec['max_ratio'].get('buoy_telescoping',0):.4f}  "
              f"occ@0.999/1.001={rec['sharpness']['occupancy_at_0.999g/2']}/{rec['sharpness']['occupancy_at_1.001g/2']}  ({rec['seconds']}s)", flush=True)
        results.append(rec)
    tot = sum(sum(v[0] for v in r['checks'].values()) for r in results)
    viol = sum(sum(v[1] for v in r['checks'].values()) for r in results)
    summary = {'total_checks': tot, 'violations': viol, 'reps': reps, 'fracs': fracs, 'kinds': kinds,
               'seed': 20261120, 'seconds': round(time.time() - t0, 1)}
    print('TOTAL', summary)
    json.dump({'summary': summary, 'families': results}, open('falsification_results.json', 'w'), indent=1, default=float)
