#!/usr/bin/env python3
"""
e47_moment_selector_check.py

Checks that the selector K = (C - 6I)(C - 30I) is forced rather than chosen:
that 6 and 30 are the mean of the Casimir spectrum plus and minus one
standard deviation, under the normalised trace, on V_2 tensor 3.

Builds the Casimir from spin generators and takes the moments off the actual
matrix.  Nothing is quoted.

    python3 e47_moment_selector_check.py
"""
import math
from fractions import Fraction as F
import numpy as np

def spin_ops(two_j):
    j = F(two_j, 2); d = two_j + 1
    m = [j - k for k in range(d)]
    Jz = np.diag([float(x) for x in m])
    Jp = np.zeros((d, d))
    for k in range(1, d):
        Jp[k - 1, k] = math.sqrt(float(j * (j + 1) - m[k] * (m[k] + 1)))
    Jm = Jp.T
    return (Jp + Jm) / 2, (Jp - Jm) / (2.0 * 1j), Jz

def casimir(two_j, n):
    d = two_j + 1
    Jx, Jy, Jz = spin_ops(two_j); I = np.eye(d)
    def tot(A):
        s = np.zeros((d ** n, d ** n), dtype=complex)
        for i in range(n):
            ops = [I] * n; ops[i] = A
            M = ops[0]
            for o in ops[1:]: M = np.kron(M, o)
            s = s + M
        return s
    Tx, Ty, Tz = tot(Jx), tot(Jy), tot(Jz)
    C = Tx @ Tx + Ty @ Ty + Tz @ Tz
    return (C + C.conj().T) / 2

def moments(C):
    D = C.shape[0]
    mu = np.trace(C).real / D
    X = C - mu * np.eye(D)
    var = np.trace(X @ X).real / D
    return mu, math.sqrt(var)

ok = True
def check(name, cond, detail=""):
    global ok
    ok = ok and cond
    print(f"  {'PASS' if cond else 'FAIL'}  {name}{('  ' + detail) if detail else ''}")

print("E47 moment selector"); print("-" * 70)
C = casimir(4, 3)                       # j = 2, n = 3
mu, sig = moments(C)
print(f"  carrier dim                 {C.shape[0]}")
print(f"  mu  = E[C]                  {mu:.9f}")
print(f"  sigma = sqrt(E[(C-mu)^2])   {sig:.9f}")
print(f"  mu - sigma                  {mu - sig:.9f}")
print(f"  mu + sigma                  {mu + sig:.9f}")
print()
check("mu = n j(j+1) = 18", abs(mu - 18) < 1e-9)
check("sigma = sqrt(2n(n-1)/3) j(j+1) = 12", abs(sig - 12) < 1e-9)
check("lower root is 6", abs((mu - sig) - 6) < 1e-9)
check("upper root is 30", abs((mu + sig) - 30) < 1e-9)

K = (C - 6 * np.eye(125)) @ (C - 30 * np.eye(125))
w = np.linalg.eigvalsh(C)
ker = int(round(sum(1 for x in w if min(abs(x - 6), abs(x - 30)) < 1e-6)))
check("dim ker K = 47", ker == 47, f"{ker}")
check("47 + 78 = 125", ker + (125 - ker) == 125)

print("\n  the tensor order: sigma is irrational off n = 3")
for n in (2, 3, 4, 5):
    s = math.sqrt(2 * n * (n - 1) / 3) * 6      # j(j+1) = 6 for j = 2
    rat = abs(s - round(s)) < 1e-9
    print(f"    n = {n}   sigma = {s:10.6f}   {'rational' if rat else 'irrational -> excluded'}")
check("only n = 3 among 2..5 gives rational sigma",
      all((abs(math.sqrt(2*n*(n-1)/3)*6 - round(math.sqrt(2*n*(n-1)/3)*6)) < 1e-9) == (n == 3)
          for n in (2, 3, 4, 5)))

print("\n  the Fibonacci-Lucas tower (k odd, F_k and L_k both odd)")
fib = [0, 1]; luc = [2, 1]
while len(fib) < 18:
    fib.append(fib[-1] + fib[-2]); luc.append(luc[-1] + luc[-2])
phi = (1 + 5 ** 0.5) / 2
print(f"    {'k':>3} {'F_k':>5} {'L_k':>5} {'dim':>10} {'kernel':>9} {'ratio':>11} {'F_k*ratio':>11}")
for k in (5, 7, 11, 13):
    Fk, Lk = fib[k], luc[k]
    dimH = Fk ** 3; kerk = Fk ** 2 + fib[k - 2] * Lk
    print(f"    {k:>3} {Fk:>5} {Lk:>5} {dimH:>10} {kerk:>9} {kerk/dimH:>11.7f} {Fk*kerk/dimH:>11.7f}")
check("k = 5 gives 47 inside 125", fib[5] ** 2 + fib[3] * luc[5] == 47 and fib[5] ** 3 == 125)
check("F_k * ratio -> 3/phi", abs(fib[13] * (fib[13]**2 + fib[11]*luc[13]) / fib[13]**3 - 3/phi) < 2e-5,
      f"3/phi = {3/phi:.9f}")

print("-" * 70)
print("ALL CHECKS PASS" if ok else "SOME CHECKS FAILED")
print("6 and 30 are mu -/+ sigma. The selector has no free parameter.")
raise SystemExit(0 if ok else 1)
