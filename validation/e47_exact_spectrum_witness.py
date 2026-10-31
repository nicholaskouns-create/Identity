"""Exact independent 125-state Casimir spectrum witness.

Run: python3 validation/e47_exact_spectrum_witness.py
Only arbitrary-precision Python integers are used. This finite computation
is not a Lean or Coq certificate.

A squarefree annihilating polynomial makes C semisimple over Q.
Reducing C-lambda*I modulo a prime cannot increase its rank, so modular
nullity is an upper bound for rational nullity. If these bounds sum to
the full carrier dimension, they are all exact.
"""
from __future__ import annotations

import hashlib
import json

N = 125
ROOTS = (0, 2, 6, 12, 20, 30, 42)
MODULUS = 1009  # prime, and all candidate roots remain distinct


def generators():
    z = [0] * N
    up = [[0] * N for _ in range(N)]
    down = [[0] * N for _ in range(N)]
    for i in range(N):
        a, b, c = i // 25, (i // 5) % 5, i % 5
        z[i] = 6 - a - b - c
        for k, stride in ((a, 25), (b, 5), (c, 1)):
            if k < 4:
                down[i + stride][i] = 1
                up[i][i + stride] = (k + 1) * (4 - k)
    return z, up, down


def matmul(a, b):
    out = [[0] * N for _ in range(N)]
    for i, row in enumerate(a):
        dest = out[i]
        for k, x in enumerate(row):
            if x:
                for j, y in enumerate(b[k]):
                    if y:
                        dest[j] += x * y
    return out


def identity():
    return [[int(i == j) for j in range(N)] for i in range(N)]


def rank_mod(a, prime):
    work = [[v % prime for v in row] for row in a]
    r = 0
    pivots = []
    for col in range(N):
        pivot = next((k for k in range(r, N) if work[k][col]), None)
        if pivot is None:
            continue
        work[r], work[pivot] = work[pivot], work[r]
        inverse = pow(work[r][col], -1, prime)
        work[r] = [(v * inverse) % prime for v in work[r]]
        for k in range(r + 1, N):
            factor = work[k][col]
            if factor:
                work[k] = [(v - factor * w) % prime
                           for v, w in zip(work[k], work[r])]
        pivots.append(col)
        r += 1
        if r == N:
            break
    return r, pivots


def main():
    z, up, down = generators()
    casimir = matmul(down, up)
    for i in range(N):
        casimir[i][i] += z[i] * (z[i] + 1)
    ident = identity()
    polynomial = ident
    max_intermediate = 0
    for lam in ROOTS:
        shifted = [[casimir[i][j] - lam * ident[i][j]
                    for j in range(N)] for i in range(N)]
        polynomial = matmul(polynomial, shifted)
        max_intermediate = max(max_intermediate,
                               max(abs(v) for row in polynomial for v in row))
    residual_count = sum(v != 0 for row in polynomial for v in row)
    assert residual_count == 0, f"annihilator failed at {residual_count} entries"

    nullities = []
    pivots_by_root = {}
    for lam in ROOTS:
        shifted = [[casimir[i][j] - lam * ident[i][j]
                    for j in range(N)] for i in range(N)]
        rank, pivots = rank_mod(shifted, MODULUS)
        nullities.append(N - rank)
        pivots_by_root[str(lam)] = pivots
    assert len({lam % MODULUS for lam in ROOTS}) == len(ROOTS)
    assert sum(nullities) == N, "modular bounds do not exhaust the carrier"
    assert nullities == [1, 9, 25, 28, 27, 22, 13], nullities
    kernel_dimension = nullities[ROOTS.index(6)] + nullities[ROOTS.index(30)]
    assert kernel_dimension == 47
    canonical_matrix = json.dumps(casimir, separators=(",", ":"))
    print(json.dumps({
        "status": "EXACT_INTEGER_AND_MODULAR_WITNESS_PASS",
        "carrier_dim": N,
        "candidate_roots": ROOTS,
        "annihilator_residual_nonzero": residual_count,
        "max_intermediate_abs": max_intermediate,
        "modulus": MODULUS,
        "modular_nullities": nullities,
        "modular_pivot_columns": pivots_by_root,
        "kernel_6_30_dim": kernel_dimension,
        "casimir_matrix_sha256": hashlib.sha256(canonical_matrix.encode()).hexdigest(),
        "evidence_class": "exact computed; not Lean/Coq compiled"
    }, sort_keys=True))


if __name__ == "__main__":
    main()
