"""Plates in the Babylonian Dark house style (near-black ground, gold/green luminous accents,
EB Garamond for prose, IBM Plex Mono for numerals, DejaVu Sans Mono for formula lines)."""
import json, sys, os, numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
from matplotlib.patches import FancyBboxPatch, Rectangle

GROUND, PANEL, INK, DIM, FAINT = "#0b0b0e", "#121217", "#e9e4d4", "#9a958a", "#3a3a44"
GOLD, GREEN, COPPER, TEAL, CRIMSON = "#d9b45a", "#7fdc9a", "#c9774b", "#6fc2c0", "#d0605e"
SERIF = "EB Garamond"; MONO = "IBM Plex Mono"; MATH = "DejaVu Sans Mono"
for f in sorted(fm.findSystemFonts()):
    if "EBGaramond08" in f: continue          # one optical size only, so the render is deterministic
    try: fm.fontManager.addfont(f)
    except Exception: pass
USED = {SERIF: set(), MONO: set(), MATH: set()}

def T(ax, x, y, s, font=MONO, **kw):
    USED[font].update(s)
    return ax.text(x, y, s, fontfamily=font, color=kw.pop("color", INK), **kw)

PIPES = ["vote", "+validated", "+anomaly", "+reference", "+auditor", "auditor-select"]
PIPE_LABEL = {"vote": "majority\nvote", "+validated": "+ validated\nresidual", "+anomaly": "+ anomaly\ndetector",
              "+reference": "+ independent\nreference", "+auditor": "+ certified\nauditor", "auditor-select": "auditor\nselects"}
PIPE_STATUS = {"vote": "empirical", "+validated": "formal, runtime data", "+anomaly": "empirical",
               "+reference": "empirical", "+auditor": "machine-checked", "auditor-select": "machine-checked"}
CLS_LABEL = {"legit": "legitimate (in envelope)", "F1-independent": "F1  independent bit flip",
             "CM1a-spec-rank": "CM1a  config Λ, rank changes", "CM1b-spec-isospectral-rank": "CM1b  config Λ, rank kept",
             "CM2-operator-file": "CM2  shared operator file", "CM3-shared-helper": "CM3  shared helper off-by-one",
             "CM4-substrate-drift": "CM4  substrate drift > ε₀", "CM5-precision-collapse": "CM5  fp8 precision collapse",
             "CM6-input-corruption": "CM6  input corrupted (control)"}

def grid(ax, fam, R, title):
    ax.set_facecolor(GROUND); ax.set_xlim(0, 10.6); ax.set_ylim(-0.2, 10.9); ax.axis("off")
    head, formula = title
    T(ax, 0.0, 10.5, head, SERIF, fontsize=22, color=GOLD, va="bottom")
    T(ax, 0.0, 10.18, formula, MATH, fontsize=9.6, color=DIM, va="bottom")
    tb = R["table"]; classes = list(tb.keys())
    x0, w, h = 3.55, 1.17, 0.98
    for j, p in enumerate(PIPES):
        st = PIPE_STATUS[p]; col = GOLD if st == "machine-checked" else (TEAL if st.startswith("formal") else DIM)
        T(ax, x0 + j * w + w / 2, 9.85, PIPE_LABEL[p], MONO, fontsize=9.2, ha="center", va="top", color=col, linespacing=1.15)
    for i, c in enumerate(classes):
        y = 9.2 - (i + 1) * h
        T(ax, 0.0, y + h / 2, CLS_LABEL[c], MATH if any(ch in CLS_LABEL[c] for ch in "Λε₀") else MONO,
          fontsize=9.6, va="center", color=INK if c != "CM6-input-corruption" else DIM)
        for j, p in enumerate(PIPES):
            r = tb[c][p]; n = r["n"]; kt, ka = r["k_transfer"], r["k_alarm"]
            frac = kt / n
            if c == "legit":
                face = GROUND if ka == 0 else "#2a1d16"; edge = GREEN if ka == 0 else COPPER
            else:
                face = (0.10 + 0.55 * frac, 0.05 + 0.10 * frac, 0.05 + 0.06 * frac) if kt else "#10161a"
                edge = CRIMSON if kt else (GREEN if not c.startswith("CM6") else FAINT)
            ax.add_patch(FancyBboxPatch((x0 + j * w + 0.06, y + 0.07), w - 0.12, h - 0.14,
                                        boxstyle="round,pad=0.0,rounding_size=0.06", fc=face, ec=edge, lw=1.1))
            if c == "legit":
                big = f"{ka}"; sub = "false alarms"
                T(ax, x0 + j * w + w / 2, y + h * 0.58, big, MONO, fontsize=15, ha="center", va="center",
                  color=GREEN if ka == 0 else COPPER, fontweight="bold")
            else:
                big = f"{kt}"; sub = f"alarm {ka}"
                T(ax, x0 + j * w + w / 2, y + h * 0.58, big, MONO, fontsize=15, ha="center", va="center",
                  color=(CRIMSON if kt else GREEN), fontweight="bold")
            T(ax, x0 + j * w + w / 2, y + h * 0.22, sub, MONO, fontsize=7.4, ha="center", va="center", color=DIM)
    T(ax, 0.0, -0.05, f"cells: harmful outputs delivered without alarm, of {n} trials per class   ·   "
      f"legitimate row: false alarms of {n}", MONO, fontsize=8.6, color=DIM, va="bottom")

def envelope(ax, R, fam, color):
    """x: deviation measured against the runtime reference (configuration + operator file);
       y: deviation measured against the certificate (exact).  One point per delivered output."""
    ax.set_facecolor(PANEL)
    for sp in ax.spines.values(): sp.set_color(FAINT)
    thr = R["threshold"]; lo = 1e-7
    groups = [("legit", GREEN, 7, "legitimate"), ("CM", CRIMSON, 9, "common-mode, harmful"),
              ("CMb", GOLD, 7, "common-mode, within tolerance")]
    pts = {"legit": [], "CM": [], "CMb": []}
    for c, L in R["scores"].items():
        if c.startswith("CM6") or c.startswith("F1"): continue
        for d in L:
            p = (max(d["val"], lo), max(d["cert"], lo))
            if c == "legit": pts["legit"].append(p)
            elif d["harmful"]: pts["CM"].append(p)
            else: pts["CMb"].append(p)
    for key, col, sz, lab in groups:
        if pts[key]:
            a = np.array(pts[key]); ax.scatter(a[:, 0], a[:, 1], s=sz, c=col, alpha=0.55, lw=0, label=f"{lab} ({len(a)})")
    ax.axvline(thr, color=TEAL, lw=1.1, ls="--"); ax.axhline(thr, color=GOLD, lw=1.4)
    ax.set_xscale("log"); ax.set_yscale("log"); ax.set_xlim(lo, 30); ax.set_ylim(lo, 30)
    ax.tick_params(colors=DIM, labelsize=7.5)
    for lab in ax.get_xticklabels() + ax.get_yticklabels(): lab.set_fontfamily(MONO)
    T(ax, 0.0, 1.05, f"{fam}: one point per delivered output", MONO, fontsize=8.8, color=INK, transform=ax.transAxes)
    T(ax, 0.5, -0.2, "deviation vs runtime reference (validated check)", MONO,
      fontsize=7.6, color=TEAL, transform=ax.transAxes, ha="center")
    T(ax, -0.17, 0.5, "deviation vs certificate (auditor)", MONO, fontsize=7.6, color=GOLD,
      transform=ax.transAxes, rotation=90, va="center")
    T(ax, 0.03, 0.93, "harmful, yet invisible\nto runtime references", MONO, fontsize=7.4, color=CRIMSON,
      transform=ax.transAxes, va="top")
    T(ax, thr * 1.3, 8.0, "τ+ρ", MATH, fontsize=8, color=TEAL, va="top")
    T(ax, 2e-7, thr * 1.6, "τ+ρ", MATH, fontsize=8, color=GOLD)
    lg = ax.legend(frameon=True, fontsize=7.2, loc="lower right", labelcolor=INK, markerscale=1.6, facecolor=PANEL, edgecolor=FAINT, framealpha=0.95)

def benchmark_plate(path_e47, path_cube, out):
    Re = json.load(open(path_e47))["results"]["E47"]; Rc = json.load(open(path_cube))["results"]["Cube"]
    fig = plt.figure(figsize=(13, 24.5), facecolor=GROUND)
    top = fig.add_axes([0.04, 0.905, 0.92, 0.085]); top.axis("off"); top.set_facecolor(GROUND)
    T(top, 0, 0.98, "Common-mode transfer", SERIF, fontsize=34, color=INK, va="top")
    T(top, 0, 0.47, "Five diverse replicas, six ways to decide what to deliver, nine fault classes, two certified carriers.",
      SERIF, fontsize=15, color=DIM, va="top", style="italic")
    T(top, 0, 0.05, "gold = reference machine-checked (Coq)   teal = rigorous check, runtime data   grey = calibrated on data",
      MONO, fontsize=9, color=DIM, va="bottom")
    a1 = fig.add_axes([0.04, 0.53, 0.92, 0.37]); grid(a1, "E47", Re, ("E47 carrier", f"K = (C−6)(C−30) on V₂⊗³ · dim ker K = 47 of 125 · ε₀ = {Re['eps0']:.3g}, g = 4 · τ+ρ = {Re['threshold']:.4f}"))
    a2 = fig.add_axes([0.04, 0.15, 0.92, 0.37]); grid(a2, "Cube", Rc, ("The Professor's Cube", f"K = L²−5L+5 on the 5×5×5 torus · golden cluster (5∓√5)/2, dim 12 of 125 · ε₀ = {Rc['eps0']:.3g}, g = 5−2√5 · τ+ρ = {Rc['threshold']:.4f}"))
    b1 = fig.add_axes([0.09, 0.03, 0.36, 0.10]); envelope(b1, Re, "E47", GREEN)
    b2 = fig.add_axes([0.59, 0.03, 0.36, 0.10]); envelope(b2, Rc, "Cube", TEAL)
    fig.savefig(out, dpi=150, facecolor=GROUND)
    return out

def falsification_plate(path, out):
    D = json.load(open(path)); fams = D["families"]; S = D["summary"]
    keys = ["occupancy_real", "davis_kahan_l2", "flow_window", "buoy_telescoping", "occupancy_complex",
            "riesz_projector", "residual_lower", "residual_upper"]
    lab = {"occupancy_real": "occupancy\n(Weyl)", "davis_kahan_l2": "subspace\n(Sylvester DK)", "flow_window": "flow\nwindow",
           "buoy_telescoping": "buoy\ntelescoping", "occupancy_complex": "occupancy\n(Bauer–Fike)", "riesz_projector": "Riesz\nprojector",
           "residual_lower": "residual\nγ‖(I−P)x‖≤‖Kx‖", "residual_upper": "residual\n‖Kx‖≤κ‖(I−P)x‖"}
    short = lambda nm: (nm.replace("Professor's Cube Laplacian, golden cluster", "Professor's Cube, golden cluster")
                          .replace("Heisenberg ring n=8, ground state (numeric gap)", "Heisenberg ring n=8, ground state")
                          .replace("E47 Casimir, W-frame, Lam={6,30}", "E47 Casimir, Λ = {6, 30}")
                          .replace("E47 K-level buoy, Lam={0}", "E47 K-level buoy, Λ = {0}")
                          .replace("|Lam|", "|Λ|"))
    fig = plt.figure(figsize=(14, 9.2), facecolor=GROUND)
    ax = fig.add_axes([0.03, 0.03, 0.94, 0.94]); ax.axis("off"); ax.set_xlim(0, 14); ax.set_ylim(0, 9.2)
    T(ax, 0, 9.1, "Theorem G, transfer half: falsification", SERIF, fontsize=27, va="top")
    T(ax, 0, 8.5, f"{S['total_checks']:,} inequality checks · {S['violations']} violations · seed {S['seed']} · "
      f"ε from 5% to 99.9% of g/2 · 7 perturbation families, symmetric and non-normal", MATH, fontsize=9.6, color=DIM, va="top")
    x0, w, h = 3.75, 1.13, 0.64
    for j, k in enumerate(keys + ["sharp"]):
        txt = lab.get(k, "radius g/2\nis sharp")
        T(ax, x0 + j * w + w / 2, 7.95, txt, MATH, fontsize=7.9, ha="center", va="top", color=GOLD, linespacing=1.1)
    for i, F in enumerate(fams):
        y = 7.25 - (i + 1) * h
        T(ax, 0, y + h / 2 + 0.1, short(F["name"]), MATH, fontsize=8.5, va="center")
        T(ax, 0, y + h / 2 - 0.16, f"r = {F['r']}   g = {F['g']:.4g}" + ("  (numeric gap)" if "numeric" in F["name"] else ""),
          MATH, fontsize=7.4, va="center", color=DIM)
        for j, k in enumerate(keys):
            c = F["checks"].get(k)
            if not c:
                T(ax, x0 + j * w + w / 2, y + h / 2, "no window\n(γ ≤ η)", MATH, fontsize=7.2, ha="center", va="center", color=DIM)
                continue
            n, v = c; ratio = F["max_ratio"].get(k, 0.0)
            exact = k.startswith("occupancy")
            if not exact:
                ax.add_patch(Rectangle((x0 + j * w + 0.07, y + 0.07), (w - 0.14) * min(ratio, 1.0), h - 0.14,
                                       fc=(GREEN if v == 0 else CRIMSON), alpha=0.22, ec="none"))
            ax.add_patch(Rectangle((x0 + j * w + 0.07, y + 0.07), w - 0.14, h - 0.14, fc="none", ec=FAINT, lw=0.8))
            T(ax, x0 + j * w + w / 2, y + h * 0.62, f"{v}/{n}", MONO, fontsize=8.4, ha="center", va="center",
              color=(GREEN if v == 0 else CRIMSON))
            T(ax, x0 + j * w + w / 2, y + h * 0.27, "count exact" if exact else f"max {ratio:.3f}", MONO, fontsize=6.9,
              ha="center", va="center", color=DIM)
        sh = F["sharpness"]; j = len(keys)
        ax.add_patch(Rectangle((x0 + j * w + 0.07, y + 0.07), w - 0.14, h - 0.14, fc="none", ec=GOLD, lw=0.8, alpha=0.7))
        T(ax, x0 + j * w + w / 2, y + h * 0.62, f"{sh['occupancy_at_0.999g/2']} → {sh['occupancy_at_1.001g/2']}", MATH,
          fontsize=8.4, ha="center", va="center", color=GOLD)
        T(ax, x0 + j * w + w / 2, y + h * 0.27, "0.999 → 1.001", MONO, fontsize=6.9, ha="center", va="center", color=DIM)
    T(ax, 0, 0.25, "cell: violations / checks;  bar and 'max' = largest observed actual ÷ bound (1.000 = the bound is attained);",
      MONO, fontsize=8.4, color=DIM)
    T(ax, 0, 0.0, "last column: window count at ε = 0.999·g/2 and at 1.001·g/2 under a one-sided shift of the nearest outside eigenvalue",
      MATH, fontsize=8.4, color=DIM)
    fig.savefig(out, dpi=150, facecolor=GROUND)
    return out

def glyph_check():
    from fontTools.ttLib import TTFont
    bad = {}
    for fam, chars in USED.items():
        path = fm.findfont(fm.FontProperties(family=fam), fallback_to_default=False)
        cmap = TTFont(path).getBestCmap()
        miss = sorted(c for c in chars if c not in "\n" and ord(c) not in cmap)
        if miss: bad[fam] = (path, miss)
    return bad

if __name__ == "__main__":
    which = sys.argv[1]
    if which == "falsification":
        print(falsification_plate(sys.argv[2], sys.argv[3]))
    else:
        print(benchmark_plate(sys.argv[2], sys.argv[3], sys.argv[4]))
    bad = glyph_check()
    print("GLYPHS OK" if not bad else f"MISSING GLYPHS: {bad}")
