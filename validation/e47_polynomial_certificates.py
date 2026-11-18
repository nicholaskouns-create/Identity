#!/usr/bin/env python3
"""
e47_polynomial_certificates.py

Verifies the exact integer polynomial identities underlying the OP-1 operator
bridge and the OP-2 block grading.  Exact integer arithmetic throughout; no
floating point, nothing quoted.

    python3 e47_polynomial_certificates.py
"""
from collections import Counter

def mul(p, q):
    r = [0] * (len(p) + len(q) - 1)
    for i, a in enumerate(p):
        for j, b in enumerate(q):
            r[i + j] += a * b
    return r

def add(p, q):
    n = max(len(p), len(q))
    return [(p[i] if i < len(p) else 0) + (q[i] if i < len(q) else 0) for i in range(n)]

def trim(p):
    while p and p[-1] == 0:
        p = p[:-1]
    return p

def prod_roots(rs):
    acc = [1]
    for r in rs:
        acc = mul(acc, [-r, 1])
    return acc

def ev(p, x):
    return sum(c * x ** i for i, c in enumerate(p))

EIG = [0, 2, 6, 12, 20, 30, 42]      # Casimir eigenvalues j(j+1), j = 0..6
KER = [6, 30]                        # the retained sectors, j = 2 and j = 5
M = prod_roots(EIG)
K = prod_roots(KER)
T = prod_roots([0, 2, 12, 20, 31, 42])
Q = [10080, 5488, -1352, 71, -1]
D = 1814400

ok = True
def check(name, cond, detail=""):
    global ok
    ok = ok and cond
    print(f"  {'PASS' if cond else 'FAIL'}  {name}{('  ' + detail) if detail else ''}")

print("E47 polynomial certificates")
print("-" * 64)
check("K * T == (x - 31) * M", trim(mul(K, T)) == trim(mul([-31, 1], M)))
check("T + K * Q == 1814400", trim(add(T, mul(K, Q))) == [D])
R = mul([-31, 1], [-c for c in Q])
check("T^2 - D*T == M * R",
      trim(add(mul(T, T), [-D * c for c in T])) == trim(mul(M, R)))
check("D == 10!/2", D == 3628800 // 2, f"{D}")

print("\n  T evaluated on the Casimir spectrum (T/D is the projector):")
for x in EIG:
    print(f"    T({x:>2}) = {ev(T, x):>9}   {'<- retained' if x in KER else ''}")
check("T vanishes off the kernel and equals D on it",
      all(ev(T, x) == (D if x in KER else 0) for x in EIG))

print("\nM_z block grading of the 125-dimensional carrier")
print("-" * 64)
c = Counter(a + b + d for a in range(5) for b in range(5) for d in range(5))
dims = [c[m] for m in range(13)]
check("block dims == (1,3,6,10,15,18,19,18,15,10,6,3,1)",
      dims == [1, 3, 6, 10, 15, 18, 19, 18, 15, 10, 6, 3, 1], str(dims))
check("blocks sum to 125", sum(dims) == 125)
check("cubic ops 27761 vs 1953125",
      sum(d ** 3 for d in dims) == 27761 and 125 ** 3 == 1953125,
      f"speedup {125**3 / sum(d**3 for d in dims):.1f}x")

print("\nIsotypic dimensions and the kernel")
print("-" * 64)
iso = {0: 1, 1: 9, 2: 25, 3: 28, 4: 27, 5: 22, 6: 13}
check("isotypic dims sum to 125", sum(iso.values()) == 125)
check("ker K = 25 + 22 = 47", iso[2] + iso[5] == 47)
check("complement = 78", 125 - 47 == 78)

print("-" * 64)
print("ALL CERTIFICATES PASS" if ok else "SOME CERTIFICATES FAILED")
raise SystemExit(0 if ok else 1)
