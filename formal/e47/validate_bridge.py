#!/usr/bin/env python3
"""
validate_bridge.py  —  independent cross-check of E47Bridge.lean and E47Bridge.v.

Re-derives every claim from first principles in exact arithmetic (Fraction /
int / mpmath-free), theorem-for-theorem, so the MATHEMATICS of both proof files
is confirmed by a third, independent implementation.

Run:  python3 -I validate_bridge.py
"""
from fractions import Fraction as Q
from collections import Counter
import sys

ok = 0
fail = []

def check(tag, cond, detail=""):
    global ok
    if cond:
        ok += 1
        print(f"  [ok] {tag:<34} {detail}")
    else:
        fail.append(tag)
        print(f"  [FAIL] {tag:<32} {detail}")

print("E47 BRIDGE — independent validation")
print("=" * 70)

# ---- 1. Clebsch-Gordan recursion -----------------------------------------
print("\n1. Clebsch-Gordan recursion  (E47-BRIDGE-001)")

def cg_step(m, width=9):
    """Tensor a multiplicity vector with one further spin-2 factor."""
    out = []
    for J in range(width):
        s = 0
        for j in range(width):
            if abs(j - 2) <= J <= j + 2:
                s += m[j] if j < len(m) else 0
        out.append(s)
    return out

spin2 = [0, 0, 1, 0, 0, 0, 0, 0, 0]
m2 = cg_step(spin2)
m3 = cg_step(m2)
check("cg_two", m2 == [1, 1, 1, 1, 1, 0, 0, 0, 0], str(m2))
check("cg_three", m3 == [1, 3, 5, 4, 3, 2, 1, 0, 0], str(m3))

# cross-check against a direct enumeration of three coupled spin-2 systems
direct = Counter({2: 1})
for _ in range(2):
    nxt = Counter()
    for j, mult in direct.items():
        for J in range(abs(j - 2), j + 3):
            nxt[J] += mult
    direct = nxt
check("cg_matches_direct_coupling",
      all(direct.get(J, 0) == m3[J] for J in range(9)),
      str(dict(sorted(direct.items()))))

# ---- 2. Carrier and kernel -----------------------------------------------
print("\n2. Carrier and kernel  (E47-BRIDGE-002)")

dimJ    = lambda J: 2 * J + 1
casimir = lambda J: J * (J + 1)
selected = lambda J: casimir(J) in (6, 30)      # q(x) = (x-6)(x-30)

carrier   = sum(m3[J] * dimJ(J) for J in range(9))
kernelDim = sum(m3[J] * dimJ(J) for J in range(9) if selected(J))

check("carrier_125", carrier == 125, f"carrier = {carrier}")
check("kernel_47", kernelDim == 47, f"dim ker q(C) = {kernelDim}")
check("dimension_identity", kernelDim + 78 == carrier, f"{kernelDim} + 78 = {carrier}")
check("kernel_below_carrier", kernelDim < carrier)
check("selected_sectors",
      [J for J in range(9) if selected(J)] == [2, 5],
      "selected exactly at J = 2 (eigenvalue 6) and J = 5 (eigenvalue 30)")
check("isotypic_split",
      m3[2] * dimJ(2) == 25 and m3[5] * dimJ(5) == 22 and 25 + 22 == kernelDim,
      "47 = 25 + 22 = 5x5 + 2x11")

# ---- 3. Omega as a functional --------------------------------------------
print("\n3. Omega as a functional, at two arguments  (E47-BRIDGE-003)")

Omega_c = Q(kernelDim, carrier)
check("omega_c_exact", Omega_c == Q(376, 1000), f"Omega_c = {Omega_c} = 0.376")
check("omega_c_matches_site", Omega_c == Q(47, 125))

# ---- 4. The wheel --------------------------------------------------------
print("\n4. The wheel is the same construction  (E47-BRIDGE-004)")

F = lambda s, j: (3 * j + s) % 40

def fit(s, n, j):
    for _ in range(n):
        j = F(s, j)
    return j

def orbit_count(s):
    """Count stations that are their own orbit representative: the encoding the
    proof files use (one representative per orbit)."""
    return sum(1 for j in range(40) if min(fit(s, k, j) for k in range(4)) == j)

def orbit_count_distinct(s):
    """Independent method: count distinct representatives."""
    return len({min(fit(s, k, j) for k in range(4)) for j in range(40)})

check("wheel_period_exactly_four",
      all(fit(s, 4, j) == j and fit(s, 1, j) != j and fit(s, 2, j) != j
          for s in range(1, 40, 2) for j in range(40)),
      "period 4 exactly, every odd offset")
check("wheel_ten_registers",
      all(orbit_count(s) == 10 for s in range(1, 40, 2)),
      "10 registers for every odd offset")
check("wheel_even_degenerates", orbit_count(0) == 13,
      f"s=0 gives {orbit_count(0)} orbits of mixed length")
check("orbit_count_encoding_agrees",
      all(orbit_count(s) == orbit_count_distinct(s) for s in range(40)),
      "representative-counting = distinct-counting, all 40 offsets")

Omega_wheel = Q(orbit_count(1), 40)
check("omega_wheel_quarter", Omega_wheel == Q(1, 4), f"Omega_wheel = {Omega_wheel}")
check("no_bridge", Omega_c != Omega_wheel,
      f"{Omega_c} != {Omega_wheel} — no identification asserted")

# the CRT refinement: 10 = 2 + 8, not merely 40/4
z8 = {min((3 * j + 1) % 8 for _ in [0]) for j in range(8)}   # placeholder, recomputed below
def orbits_mod(n, s):
    seen, out = set(), []
    for j in range(n):
        if j in seen:
            continue
        k, L = j, 0
        while k not in seen:
            seen.add(k); k = (3 * k + s) % n; L += 1
        out.append(L)
    return out
o8, o5 = orbits_mod(8, 1), orbits_mod(5, 1)
from math import gcd
crt = sum(gcd(a, b) for a in o8 for b in o5)
check("wheel_crt_split", crt == 10 and sorted(o5) == [1, 4] and sorted(o8) == [4, 4],
      f"Z8 orbits {o8}, Z5 orbits {o5}, sum gcd = {crt} = 2 + 8")

# ---- 5. Lifshitz dictionary ----------------------------------------------
print("\n5. The Lifshitz dictionary — the fulcrum  (E47-BRIDGE-005)")

dH = lambda d, z: d + z
dw = lambda z: 2 * z
ds = lambda d, z: Q(d + z, z) if isinstance(d, int) else (d + z) / z

check("triality",
      all(ds(d, z) * dw(z) == 2 * dH(d, z) for d in range(1, 12) for z in range(1, 12)),
      "d_s * d_w = 2 d_H for every integer (d, z)")
check("marginal_iff_isotropic",
      all((ds(d, z) == 2) == (d == z) for d in range(1, 12) for z in range(1, 12)),
      "d_s = 2  <=>  z = d")
check("self_dual_iff_isotropic",
      all((dw(z) == dH(d, z)) == (d == z) for d in range(1, 12) for z in range(1, 12)),
      "d_w = d_H  <=>  z = d")
check("spectral_two_blind_to_d",
      all(ds(d, d) == 2 for d in range(1, 40)),
      "d_s = 2 for EVERY d: the UV result D->2 does not constrain d_H")

sols = [(d, z) for d in range(0, 21) for z in range(1, 21)
        if ds(d, z) == 2 and dH(d, z) == 10]
check("selection", sols == [(5, 5)],
      f"d_s = 2 and d_H = 10 force (d, z) = {sols[0]}")
check("selection_dw_equals_dH", dw(5) == dH(5, 5) == 10,
      "d_w = d_H = 10 at the selected point")

# ---- 6. Carrier against the selected dimension ---------------------------
print("\n6. Carrier against the selected dimension  (E47-BRIDGE-006)")
check("multiplet_dimension", 2 * 2 + 1 == 5, "spin-2 multiplet has dim 5")
check("carrier_is_multiplet_cube", 5 ** 3 == carrier, f"5^3 = {carrier}")
check("selected_dimension_sums_to_ten", 5 + 5 == 10,
      "arithmetic observation only; no causal link asserted")

# ---- 7-8. Retention polynomial, degree lock ------------------------------
print("\n7-8. Retention polynomial and degree lock  (E47-BRIDGE-007/008)")

def bisect_root(n, lo=Q(1), hi=Q(2), iters=200):
    p = lambda x: x ** n - x - 1
    for _ in range(iters):
        mid = (lo + hi) / 2
        if p(mid) < 0:
            lo = mid
        else:
            hi = mid
    return lo, hi

lo, hi = bisect_root(10)
check("lambda_exists", lo < hi and (lo ** 10 - lo - 1) < 0 < (hi ** 10 - hi - 1),
      f"lambda in ({float(lo):.12f}, {float(hi):.12f})")
check("lambda_lower_bracket", 43 ** 10 < 40 ** 9 * (43 + 40),
      "p(43/40) < 0  <=>  43^10 < 40^9 * 83")
check("lambda_upper_bracket", 10 ** 9 * (11 + 10) < 11 ** 10,
      "p(11/10) > 0  <=>  10^9 * 21 < 11^10")
check("bracket_contains_root", Q(43, 40) < lo and hi < Q(11, 10),
      f"43/40 < lambda < 11/10")

# ring half: lambda^20 = (lambda+1)^2 to the full precision of the bracket
lam = (lo + hi) / 2
resid = abs(lam ** 20 - (lam + 1) ** 2)
check("retention_square_10", resid < Q(1, 10 ** 40),
      f"|lambda^20 - (lambda+1)^2| < 1e-40  (exact given lambda^10 = lambda+1)")

# degree lock: lambda^(2D) = (lambda+1)^2 only at D = n
def ratio(D):
    return lam ** (2 * D)
target = (lam + 1) ** 2
near = [D for D in range(1, 31) if abs(ratio(D) - target) < Q(1, 10 ** 20)]
check("degree_lock", near == [10],
      f"lambda^(2D) = (lambda+1)^2 only at D = {near[0]} = deg p")
check("retention_ratio_value", Q(43, 10) < target < Q(44, 10),
      f"retention ratio at the fixed point = {float(target):.6f}")

# ---- 9. RG fixed point ---------------------------------------------------
print("\n9. The RG fixed point  (E47-BRIDGE-009)")
rg = lambda sigma, D: sigma * (10 - D)
check("rg_fixed_point_unique",
      [D for D in range(0, 41) if rg(Q(1, 2), D) == 0] == [10],
      "dD/d(ln b) = sigma(10 - D) vanishes only at D* = 10")
check("rg_contraction",
      all(rg(Q(1, 2), D) == -Q(1, 2) * (D - 10) for D in range(0, 41)),
      "the flow is a contraction onto D* = 10")
check("three_tens", 10 == dH(5, 5) == dw(5) == 10,
      "RG fixed point = d_H at the selected point = deg p = 10")

# ---- 11. The commutant, from the same table -----------------------------
print("\n11. The commutant, from the same table  (E47-BRIDGE-011)")

# Schur: commutant of (+) m_J . V_J  is  (+) M_{m_J}(C),  dim = sum m_J^2.
commutantSelected = sum(m3[J] ** 2 for J in range(9) if selected(J))
commutantCarrier  = sum(m3[J] ** 2 for J in range(9))

check("commutant_29", commutantSelected == 29,
      f"sum m^2 over selected = {m3[2]}^2 + {m3[5]}^2 = {commutantSelected}")
check("commutant_carrier_65", commutantCarrier == 65,
      f"sum m^2 over all = {' + '.join(str(m3[J]**2) for J in range(7))} = {commutantCarrier}")
check("state_geometry_28", commutantSelected - 1 == 28,
      f"{commutantSelected} - 1 = {commutantSelected - 1}")
check("commutant_from_multiplicities",
      m3[2] == 5 and m3[5] == 2
      and m3[2] ** 2 + m3[5] ** 2 == commutantSelected
      and m3[2] * dimJ(2) + m3[5] * dimJ(5) == kernelDim,
      "one table, two readings: sum m(2J+1) = 47, sum m^2 = 29")

# ---- 10. Omega table ----------------------------------------------------
print("\n10. Omega table  (E47-BRIDGE-010)")
check("omega_table",
      kernelDim * 125 == 47 * carrier
      and orbit_count(1) * 40 == 10 * 40
      and kernelDim * 40 != orbit_count(1) * carrier,
      f"Omega_c = {Omega_c}, Omega_wheel = {Omega_wheel}, distinct")

print("\n" + "=" * 70)
print(f"{ok} checks passed, {len(fail)} failed")
if fail:
    print("FAILED:", ", ".join(fail))
    sys.exit(1)
print("All independent checks pass.")
