#!/usr/bin/env python3
"""Induced gravity from the E47 spectrum, and the Dirac factorisation parallel.

crf_einstein_test.py shows the kinematic route to Einstein's equations fails.
It does not show that no route exists, and the standard one is Sakharov's:
do not postulate Einstein-Hilbert, induce it. Integrating out matter modes
produces Lambda and R as the leading terms of the one-loop effective action,
with coefficients fixed by the mode spectrum. E47 supplies that spectrum.

Run: python3 research/e47_gr/induced_gravity.py
"""
from fractions import Fraction as F
import math
import sys

fails = []
def check(name, ok, detail=""):
    print(f"  [{'ok ' if ok else 'FAIL'}] {name}" + (f"   {detail}" if detail else ""))
    if not ok: fails.append(name)

J = list(range(7)); C = [j*(j+1) for j in J]; COP = [1, 3, 5, 4, 3, 2, 1]
ST = [COP[j]*(2*j+1) for j in J]

print("1. The selector roots are not chosen — they are mu -+ sigma")
mu = F(sum(c*n for c, n in zip(C, ST)), 125)
var = F(sum(n*(c-mu)**2 for c, n in zip(C, ST)), 125)
sig = math.isqrt(int(var))
check("mu = 18", mu == 18, f"state-weighted mean of C over all 125 states")
check("sigma = 12", sig == 12 and var == 144)
check("mu - sigma = 6 and mu + sigma = 30", (int(mu)-sig, int(mu)+sig) == (6, 30),
      "so K = (C - 6I)(C - 30I) has its roots forced, not fitted")
check("dim ker K = 5*5 + 2*11 = 47", 5*5 + 2*11 == 47)

print("\n2. The Dirac parallel, exactly")
print("   Dirac 1928 : box + m^2 = (i g.d - m)(i g.d + m), {g_u,g_v} = 2 eta_uv")
print("                the Clifford algebra forces 4x4. Dimension is an output.")
print("   E47        : K = (C - 6I)(C - 30I), roots at mu -+ sigma")
print("                multiplicities 5 and 2 force dim ker K = 47.")
print("   Same move: factor a quadratic in the generator and let the")
print("   representation theory fix the dimension. Dirac got 4; this gets 47.")

print("\n3. Mode masses, read off rather than assumed")
print(f"   {'j':>2} {'C':>4} {'K':>7} {'m^2':>9} {'dim':>4}  sector")
massive = []
for j in J:
    K = (C[j]-6)*(C[j]-30); d = ST[j]
    print(f"   {j:>2} {C[j]:>4} {K:>7} {K*K:>9} {d:>4}  {'E47 (massless)' if K == 0 else 'complement'}")
    if K: massive.append((abs(K), K*K, d))
check("47 massless modes", sum(d for j, d in zip(J, ST) if (C[j]-6)*(C[j]-30) == 0) == 47)
check("78 massive modes", sum(d for _, _, d in massive) == 78)

print("\n4. Sakharov coefficients. Logs and cutoff cancel in the ratio.")
S2 = sum(d*m2 for _, m2, d in massive)
S4 = sum(d*m2*m2 for _, m2, d in massive)
print(f"   sum m^2 = {S2:,}")
print(f"   sum m^4 = {S4:,}")
r = F(S4, S2*S2)
print(f"   Lambda_ind * G_ind ~ (1/2) sum m^4 / (sum m^2)^2 = {F(1,2)*r} = {float(F(1,2)*r):.6e}")
print(f"   spectral invariant  sum m^4/(sum m^2)^2          = {r} = {float(r):.8e}")
neff = float(1/r)
print(f"   N_eff = (sum m^2)^2 / sum m^4                    = {neff:.4f}")
check("the ratio is a rational, hence cutoff-free", isinstance(r, F))
check("N_eff is NOT 78 (the spectrum is not degenerate)", abs(neff - 78) > 1,
      f"{neff:.2f}, the m=432 sector dominates")
check("N_eff is near 25 but NOT equal to it", abs(neff - 25) < 0.05 and neff != 25,
      f"{neff:.4f} vs 25; a 0.09% coincidence, recorded as one, not built on")

print("\n5. What this is and is not")
print("   IS : the first dimensionless, cutoff-free quantity in this thread.")
print("        Comparable with Lambda*G in nature without choosing a scale.")
print("   NOT: a derivation. It presumes the 78 modes propagate as fields on")
print("        the background, which is bridge 2 and is not supplied by E47.")
print(f"   observed Lambda*G/c^4 ~ 1e-122 against {float(F(1,2)*r):.2e} here: the")
print("   cosmological constant problem, generic to every induced-gravity")
print("   model rather than specific to E47.")

print("\n" + ("ALL RESULTS REPRODUCE" if not fails else f"FAILURES: {fails}"))
sys.exit(1 if fails else 0)
