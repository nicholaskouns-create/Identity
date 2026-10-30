"""Richardson contraction on the Casimir eigenbasis of V_2^{⊗3}.

The filter is diagonal in that basis, so the 125-dimensional iteration is 125
independent multiplies. K = (C − 6I)(C − 30I) vanishes on total spin 2 and 5
(47 dimensions) and the optimal step ε* = 1/99144 multiplies every other mode
by a factor at most 15/17.

The initial vector is deterministic: coordinate i is (17*i + 3) mod 97,
centered and normalized. Q4.28 rounds every coordinate to a multiple of 2^{−28}
after each step. This is not the unpublished vector behind the plate's printed
table; the rate law is the same.
"""

from __future__ import annotations

import math

K2 = (32400, 12544, 0, 11664, 19600, 0, 186624)
MULT = (1, 9, 25, 28, 27, 22, 13)
J = (0, 1, 2, 3, 4, 5, 6)
EPS = 1 / 99144
RHO = 15 / 17
ULP = 2 ** (-28)
MARKS = (1, 5, 10, 20, 50, 100, 150, 200, 220, 250)


def spectrum():
    lam = []
    keep = []
    for j, k2, m in zip(J, K2, MULT):
        factor = 1 - EPS * k2
        lam.extend([factor] * m)
        keep.extend([k2 == 0] * m)
    return lam, keep


def initial(n=125):
    raw = [((17 * i + 3) % 97) - 48 for i in range(n)]
    mean = sum(raw) / n
    centered = [v - mean for v in raw]
    norm = math.sqrt(sum(v * v for v in centered))
    return [v / norm for v in centered]


def quant(x):
    return [math.floor(v / ULP + 0.5) * ULP for v in x]


def complement_norm(x, keep):
    return math.sqrt(sum(v * v for v, k in zip(x, keep) if not k))


def kernel_norm(x, keep):
    return math.sqrt(sum(v * v for v, k in zip(x, keep) if k))


def main():
    lam, keep = spectrum()
    assert len(lam) == 125
    assert sum(1 for k in keep if k) == 47
    factors = []
    print("sector  mult  K^2      multiplier     role")
    for j, k2, m in zip(J, K2, MULT):
        factor = 1 - EPS * k2
        factors.append(factor)
        role = "retain" if k2 == 0 else "contract"
        print(f"J={j:<2} {m:5} {k2:8}  {factor: .10f}  {role}")
    worst = max(abs(f) for f, k2 in zip(factors, K2) if k2)
    print(f"\nworst |multiplier| = {worst:.12f}")
    print(f"15/17              = {RHO:.12f}")
    print(f"gap                = {abs(worst - RHO):.3e}")

    x = initial()
    xq = quant(x)
    print(f"\n||P x0|| = {kernel_norm(x, keep):.6f}   ||(I−P) x0|| = {complement_norm(x, keep):.6f}")
    print(f"{'n':>4}  {'float R⊥':>12}  {'Q4.28 R⊥':>12}  {'||Δx||':>12}  {'(15/17)^n':>12}")
    rows = []
    for n in range(0, 251):
        if n in MARKS or n == 0:
            rf = complement_norm(x, keep)
            rq = complement_norm(xq, keep)
            dx = math.sqrt(sum((a - b) ** 2 for a, b in zip(x, xq)))
            bound = RHO**n
            print(f"{n:4}  {rf:12.4e}  {rq:12.4e}  {dx:12.4e}  {bound:12.4e}")
            rows.append((n, rf, rq, dx, bound))
        if n == 250:
            break
        x = [a * L for a, L in zip(x, lam)]
        xq = quant([a * L for a, L in zip(xq, lam)])
    print(f"\nkernel after 250 float steps: {kernel_norm(x, keep):.10f}")
    print(f"kernel after 250 Q4.28 steps: {kernel_norm(xq, keep):.10f}")
    return rows


if __name__ == "__main__":
    main()
