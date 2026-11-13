#!/usr/bin/env python3
"""Independent exact-integer Casimir projector witness for 125 spin-2 states.

Arithmetic evidence, not a Lean/Coq theorem about the concrete matrix.
No NumPy, SymPy, external imports, or assumed multiplicity list.
"""
import hashlib
import json
import platform

N = 125
DENO = 1814400
ROOTS = (0, 2, 6, 12, 20, 30, 42)
POLY_FACTORS = (0, 2, 12, 20, 31, 42)


def abc(i):
    return i // 25, (i // 5) % 5, i % 5


def zero():
    return [dict() for _ in range(N)]


def identity():
    return [{i: 1} for i in range(N)]


def add(A, B, scale=1):
    out = zero()
    for i in range(N):
        row = dict(A[i])
        for j, v in B[i].items():
            row[j] = row.get(j, 0) + scale * v
            if not row[j]:
                del row[j]
        out[i] = row
    return out


def subscalar(A, v):
    out = [dict(row) for row in A]
    for i in range(N):
        out[i][i] = out[i].get(i, 0) - v
        if not out[i][i]:
            del out[i][i]
    return out


def multiply(A, B):
    out = zero()
    for i, row in enumerate(A):
        dest = {}
        for k, a in row.items():
            for j, b in B[k].items():
                dest[j] = dest.get(j, 0) + a * b
        out[i] = {j: v for j, v in dest.items() if v}
    return out


def scale(A, s):
    return [{j: s * v for j, v in row.items() if s * v} for row in A]


def equal(A, B):
    return all(a == b for a, b in zip(A, B))


def is_zero(A):
    return all(not row for row in A)


def trace(A):
    return sum(row.get(i, 0) for i, row in enumerate(A))


def build_casimir():
    U, L, Z = zero(), zero(), zero()
    for j in range(N):
        x, y, z = abc(j)
        Z[j][j] = 6 - x - y - z
        for axis, coordinate in enumerate((x, y, z)):
            if coordinate > 0:
                i = j - (25, 5, 1)[axis]
                U[i][j] = coordinate * (5 - coordinate)
            if coordinate < 4:
                i = j + (25, 5, 1)[axis]
                L[i][j] = 1
    C = multiply(L, U)
    for i in range(N):
        w = Z[i][i]
        C[i][i] = C[i].get(i, 0) + w * (w + 1)
        if not C[i][i]:
            del C[i][i]
    return C, Z, U, L


def poly_matrix(C, factors):
    result = identity()
    for a in factors:
        result = multiply(result, subscalar(C, a))
    return result


def rank_mod_prime(A, prime):
    """Exact F_p elimination; gives a lower bound for rational rank."""
    rows = [[A[i].get(j, 0) % prime for j in range(N)] for i in range(N)]
    rank = 0
    for col in range(N):
        pivot = next((r for r in range(rank, N) if rows[r][col]), None)
        if pivot is None:
            continue
        rows[rank], rows[pivot] = rows[pivot], rows[rank]
        inverse = pow(rows[rank][col], -1, prime)
        for j in range(col, N):
            rows[rank][j] = rows[rank][j] * inverse % prime
        for i in range(rank + 1, N):
            factor = rows[i][col]
            if factor:
                for j in range(col, N):
                    rows[i][j] = (rows[i][j] - factor * rows[rank][j]) % prime
        rank += 1
    return rank


def run():
    C, Z, U, L = build_casimir()
    assert is_zero(add(multiply(C, Z), multiply(Z, C), -1)), '[C,Z] != 0'
    assert is_zero(add(multiply(C, U), multiply(U, C), -1)), '[C,U] != 0'
    assert is_zero(add(multiply(C, L), multiply(L, C), -1)), '[C,D] != 0'
    assert is_zero(add(add(multiply(U, L), multiply(L, U), -1), scale(Z, 2), -1)), '[U,D] != 2Z'

    assert is_zero(poly_matrix(C, ROOTS)), 'square-free degree-seven annihilator failed'
    numerator = poly_matrix(C, POLY_FACTORS)
    assert equal(multiply(numerator, numerator), scale(numerator, DENO)), 'P^2 != P'
    K = multiply(subscalar(C, 6), subscalar(C, 30))
    assert is_zero(multiply(K, numerator)), 'K P != 0'
    assert trace(numerator) == 47 * DENO, 'tr(P) != 47'
    assert trace(K) == 0, 'unexpected K trace'
    assert not is_zero(K) and not is_zero(numerator), 'degenerate test'
    # P^2=P and tr(P)=47 give rank_Q(P)=47. KP=0 gives rank_Q(K)<=78.
    # A rank-78 minor mod p gives rank_Q(K)>=78. Hence rank_Q(K)=78.
    rank101 = rank_mod_prime(K, 101)
    rank103 = rank_mod_prime(K, 103)
    assert (rank101, rank103) == (78, 78), 'modular rank lower bound failed'

    corrupt = [dict(row) for row in C]
    corrupt[0][0] += 1
    assert not is_zero(poly_matrix(corrupt, ROOTS)), 'corrupted C escaped annihilator'
    wrong = poly_matrix(corrupt, POLY_FACTORS)
    assert not equal(multiply(wrong, wrong), scale(wrong, DENO)), 'corrupted C escaped idempotence'

    canonical = json.dumps([[C[i].get(j, 0) for j in range(N)] for i in range(N)], separators=(',', ':'))
    report = {
        'status': 'EXACT_CONCRETE_PROJECTOR_POLYNOMIAL_PASS',
        'python': platform.python_version(),
        'dimension': N,
        'casimir_dense_sha256': hashlib.sha256(canonical.encode()).hexdigest(),
        'annihilating_roots': list(ROOTS),
        'square_free_annihilator_zero_matrix': True,
        'projector_numerator_factors': list(POLY_FACTORS),
        'projector_denominator': DENO,
        'projector_numerator_squared_equals_denominator_times_numerator': True,
        'kernel_selector_K_times_projector_numerator_zero': True,
        'projector_trace': 47,
        'K_rank_mod_101': rank101,
        'K_rank_mod_103': rank103,
        'K_rank_over_Q_by_sandwich': 78,
        'K_nullity_over_Q_by_rank_nullity': 47,
        'negative_control_corrupted_matrix_rejected': True,
        'proof_boundary': 'exact arithmetic; full 125x125 Lean/Coq kernel theorem remains open',
    }
    print(json.dumps(report, sort_keys=True, indent=2))


if __name__ == '__main__':
    run()
