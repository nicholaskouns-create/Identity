#!/usr/bin/env python3
"""Independent exact characteristic-polynomial census of the concrete 125-state Casimir.

Source convention: formal/e47/unified/Tensor125.lean and Tensor125.v.
No NumPy/SymPy, eigenvalue tolerance, assumed spectrum, or character decomposition.
The 13 diagonal-Z weight blocks are computed directly from generator entries.
For each block, Newton identities derive the monic characteristic polynomial
from exact integer traces; synthetic division checks every factor.
This is computational evidence, not a Lean/Coq formal certificate.
"""
from __future__ import annotations

from collections import Counter
from fractions import Fraction
from hashlib import sha256
import json
import sys

N = 125

def abc(i):
    return (i // 25, (i // 5) % 5, i % 5)

def matrix_zero():
    return [dict() for _ in range(N)]

def add_entry(M, i, j, v):
    if v:
        t = M[i].get(j, 0) + v
        if t:
            M[i][j] = t
        else:
            M[i].pop(j, None)

def multiply(A, B):
    out = matrix_zero()
    for i, row in enumerate(A):
        for k, v in row.items():
            for j, w in B[k].items():
                add_entry(out, i, j, v * w)
    return out

def comm_zero(A, B):
    AB, BA = multiply(A, B), multiply(B, A)
    return all(AB[i] == BA[i] for i in range(N))

def mm(A, B):
    n = len(A)
    return [[sum(A[i][k] * B[k][j] for k in range(n))
             for j in range(n)] for i in range(n)]

def charpoly(M):
    """Newton trace identities with exact integral coefficients."""
    n = len(M)
    power = [[int(i == j) for j in range(n)] for i in range(n)]
    traces = [0]
    for _ in range(n):
        power = mm(power, M)
        traces.append(sum(power[i][i] for i in range(n)))
    coeff = [1]
    for k in range(1, n + 1):
        numerator = -sum(coeff[k-i] * traces[i] for i in range(1, k+1))
        assert numerator % k == 0, ("nonintegral coefficient", k)
        coeff.append(numerator // k)
    return coeff

def divide_root(coeff, root):
    quotient = [coeff[0]]
    for a in coeff[1:-1]:
        quotient.append(a + root * quotient[-1])
    remainder = coeff[-1] + root * quotient[-1]
    return quotient, remainder

def factor_integer_roots(coeff, bound):
    roots = Counter()
    while len(coeff) > 1:
        found = False
        for r in range(-bound, bound + 1):
            q, rem = divide_root(coeff, r)
            if rem == 0:
                roots[r] += 1
                coeff = q
                found = True
                break
        if not found:
            raise AssertionError("unfactored characteristic polynomial; no integer-root assumption")
    assert coeff == [1]
    return roots

def main():
    Z, U, D = matrix_zero(), matrix_zero(), matrix_zero()
    for j in range(N):
        a, b, c = abc(j)
        Z[j][j] = 6 - a - b - c
        for k, stride in ((a, 25), (b, 5), (c, 1)):
            if k < 4:
                add_entry(U, j, j + stride, (k + 1) * (4 - k))
                add_entry(D, j + stride, j, 1)
    C = multiply(D, U)
    for i in range(N):
        z = Z[i][i]
        add_entry(C, i, i, z * (z + 1))
    if "--negative-control" in sys.argv:
        add_entry(C, 0, 0, 1)  # deliberate corruption must fail the commutator gate
    assert comm_zero(C, Z) and comm_zero(C, U) and comm_zero(C, D)
    groups = {m: [i for i in range(N) if Z[i][i] == m] for m in range(-6, 7)}
    assert sum(map(len, groups.values())) == N
    assert all(Z[i][i] == Z[j][j] for i, row in enumerate(C) for j in row)
    bound = max(sum(abs(v) for v in row.values()) for row in C)
    allroots = Counter()
    blocks = []
    for m, indices in sorted(groups.items()):
        block = [[C[i].get(j, 0) for j in indices] for i in indices]
        roots = factor_integer_roots(charpoly(block), bound)
        assert sum(roots.values()) == len(indices)
        allroots.update(roots)
        blocks.append({"weight": m, "dimension": len(indices),
                       "roots": dict(sorted(roots.items()))})
    eig = dict(sorted(allroots.items()))
    assert sum(eig.values()) == N
    kernel = sum(mult for lam, mult in eig.items() if (lam - 6) * (lam - 30) == 0)
    K2 = {lam: (lam - 6)**2 * (lam - 30)**2 for lam in eig}
    eps = Fraction(1, 99144)
    off = {lam: abs(1 - eps * v) for lam, v in K2.items() if v}
    rho = max(off.values())
    assert eig == {0: 1, 2: 9, 6: 25, 12: 28, 20: 27, 30: 22, 42: 13}
    assert kernel == 47 and N - kernel == 78
    assert rho == Fraction(15, 17)
    result = {
        "dimension": N, "casimir_eigenvalue_multiplicities": eig,
        "kernel_dimension": kernel, "rank_K": N - kernel,
        "K_squared_eigenvalues": K2, "richardson_epsilon": str(eps),
        "richardson_off_kernel_spectral_radius": str(rho),
        "weight_blocks": blocks,
        "method": "exact integer Newton traces + root division",
        "trust": "computational exact arithmetic; no formal proof/CI claim",
    }
    raw = json.dumps(result, sort_keys=True, separators=(",", ":")).encode()
    print(json.dumps(result, indent=2, sort_keys=True))
    print("E47_WEIGHTBLOCK_CHARPOLY_PASS SHA256=" + sha256(raw).hexdigest())

if __name__ == "__main__":
    main()
