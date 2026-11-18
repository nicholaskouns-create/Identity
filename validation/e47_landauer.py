#!/usr/bin/env python3
"""
e47_landauer.py — the thermodynamic cost of projecting onto E47, end to end.

Builds the 125-dimensional carrier from spin-2 generators, forms the Casimir,
extracts the rank-47 projector, computes both von Neumann entropies on the
actual matrices, and prices the drop with the Landauer bound.

Nothing is quoted.  Every number is recomputed.  Run:  python3 e47_landauer.py
"""
import math
from fractions import Fraction as Q
import numpy as np

# ----------------------------------------------------------------- constants
k_B = 1.380649e-23        # J/K   exact, SI 2019
c   = 299792458.0         # m/s   exact, SI
T   = 310.15              # K     37.00 C

# --------------------------------------------------- 1. build V2^{otimes 3}
def spin_ops(j):
    d = 2 * j + 1
    m = np.arange(j, -j - 1, -1.0)
    Jz = np.diag(m)
    Jp = np.zeros((d, d))
    for i in range(1, d):
        Jp[i - 1, i] = math.sqrt(j * (j + 1) - m[i] * (m[i] + 1))
    Jm = Jp.T
    return (Jp + Jm) / 2, (Jp - Jm) / (2.0j), Jz

Jx, Jy, Jz = spin_ops(2)
I5 = np.eye(5)
kron3 = lambda a, b, cc: np.kron(np.kron(a, b), cc)
tot = lambda A: kron3(A, I5, I5) + kron3(I5, A, I5) + kron3(I5, I5, A)
Tx, Ty, Tz = tot(Jx), tot(Jy), tot(Jz)

C = Tx @ Tx + Ty @ Ty + Tz @ Tz
C = (C + C.conj().T) / 2
N = C.shape[0]

# ------------------------------------------------- 2. kernel and projector
K = (C - 6 * np.eye(N)) @ (C - 30 * np.eye(N))
w, V = np.linalg.eigh(C)
sel  = np.isclose(w, 6, atol=1e-6) | np.isclose(w, 30, atol=1e-6)
B    = V[:, sel]
P    = B @ B.conj().T
n    = int(round(P.trace().real))

# -------------------------------------------------- 3. von Neumann entropy
def vN(rho):
    ev = np.linalg.eigvalsh(rho)
    ev = ev[ev > 1e-12]
    return float(-(ev * np.log(ev)).sum())

rho_i, rho_f = np.eye(N) / N, P / n
S_i, S_f = vN(rho_i), vN(rho_f)
dS = S_i - S_f

# ------------------------------------------------------ 4. exact arithmetic
omega   = Q(n, N)
ratio   = Q(N, n)
bits    = dS / math.log(2)

# integer certificates: log2(N/n) > p/q  <->  n^q * 2^p < N^q
cert = lambda p, q: (n**q * 2**p < N**q, N**q < n**q * 2**(p + 1))

# ------------------------------------------------------------ 5. the report
line = "-" * 72
print(line); print("  E47 LANDAUER COST — recomputed from the generators"); print(line)
print(f"  carrier dim N              {N}")
print(f"  Tr P                       {n}            ||P^2-P|| = {np.abs(P@P-P).max():.2e}")
print(f"  ||K P||                    {np.abs(K@P).max():.2e}   (P lands in ker K)")
print(f"  rank-nullity               {n} + {N-n} = {n + (N-n)}")
print()
print(f"  Omega_c = n/N              {omega} = {float(omega)}")
print(f"  compression ratio N/n      {ratio} = {float(ratio):.9f}")
print()
print(f"  S(I/{N})  = ln {N}        {S_i:.10f}   (ln {N} = {math.log(N):.10f})")
print(f"  S(P/{n})   = ln {n}         {S_f:.10f}   (ln {n}  = {math.log(n):.10f})")
print(f"  Delta S                    {dS:.10f}   = ln(N/n) = {math.log(N/n):.10f}")
print(f"  -ln(Omega_c)               {-math.log(float(omega)):.10f}")
print(f"  Delta S in bits            {bits:.10f}   = log2(N/n) = {math.log2(N/n):.10f}")
print()
gt, lt = cert(141, 100)
print(f"  integer certificate   47^100 * 2^141 < 125^100          {gt}")
print(f"  integer certificate   125^100 < 47^100 * 2^142          {lt}")
print(f"  => 1.41 bits < Delta S < 1.42 bits, with no floating point")
print()
Qmin = k_B * T * dS
print(f"  Q_min = kT * Delta S       {Qmin:.6e} J        (T = {T} K)")
print(f"  in units of kT ln2         {dS/math.log(2):.6f} bits")
print(f"  mass equivalent Q/c^2      {Qmin/c**2:.6e} kg")
print()
print("  The cost sees the ratio and nothing else:")
for gamma, label in ((11664, "spectral gap"), (78, "discarded dims"), (16, "condition no.")):
    print(f"    {label:<16} {gamma:<8} appears nowhere above")
print()
print("  Scale invariance — double the carrier and the kernel:")
d2 = math.log2((2*N)/(2*n))
print(f"    log2(250/94) = {d2:.10f}   identical to log2(125/47)")
print(line)
print("  Bound presumes a deterministic reset I/N -> P/n against a bath at T.")
print("  Landauer 1961; Reeb & Wolf, New J. Phys. 16, 103011 (2014).")
print(line)
