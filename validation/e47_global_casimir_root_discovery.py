#!/usr/bin/env python3
"""Independent exact 125-state E47 Casimir spectral audit (stdlib only).

Constructs the spin-2 triple tensor in the canonical 0..124 basis.
Derives weight blocks directly from the diagonal total Z. Tests the global
annihilating polynomial, exact characteristic polynomials, and rank of K.
This is an exact computation, not a Lean/Coq theorem or signed certificate.
"""
from collections import Counter
from fractions import Fraction

N = 125
EXPECTED_SPECTRUM = {0: 1, 2: 9, 6: 25, 12: 28, 20: 27, 30: 22, 42: 13}  # comparison only, never used for discovery

def abc(n):
    return n // 25, (n // 5) % 5, n % 5

def z(n):
    return 6 - sum(abc(n))

def up(i, j):
    a, b, c = abc(i)
    x, y, t = abc(j)
    return ((x * (5 - x) if a + 1 == x and b == y and c == t else 0)
            + (y * (5 - y) if a == x and b + 1 == y and c == t else 0)
            + (t * (5 - t) if a == x and b == y and c + 1 == t else 0))

def down(i, j):
    a, b, c = abc(i)
    x, y, t = abc(j)
    return (int(a == x + 1 and b == y and c == t)
            + int(a == x and b == y + 1 and c == t)
            + int(a == x and b == y and c == t + 1))

def casimir(i, j):
    return sum(down(i, k) * up(k, j) for k in range(N)) + (
        z(i) * (z(i) + 1) if i == j else 0)

def identity(n):
    return [[int(i == j) for j in range(n)] for i in range(n)]

def matmul(A, B):
    return [[sum(A[i][k] * B[k][j] for k in range(len(B)))
             for j in range(len(B[0]))] for i in range(len(A))]

def subtract_root(A, r):
    return [[v - (r if i == j else 0) for j, v in enumerate(row)]
            for i, row in enumerate(A)]

def characteristic_polynomial(A):
    # Exact Faddeev-LeVerrier, coefficients in descending degree order.
    n = len(A)
    Q = identity(n)
    coeffs = [1]
    for k in range(1, n + 1):
        Q = matmul(A, Q)
        tr = sum(Q[i][i] for i in range(n))
        assert tr % k == 0
        ck = -tr // k
        coeffs.append(ck)
        for i in range(n):
            Q[i][i] += ck
    return coeffs

def divide_linear_desc(coeffs, root):
    quotient = [coeffs[0]]
    for c in coeffs[1:-1]:
        quotient.append(c + root * quotient[-1])
    remainder = coeffs[-1] + root * quotient[-1]
    return quotient, remainder

def discover_integer_spectrum(A):
    """Factor the exact characteristic polynomial, without supplied roots.

    Search every integer in a row-sum eigenvalue bound. Complete factorization
    of the degree-n polynomial proves no other complex eigenvalues remain.
    """
    poly = characteristic_polynomial(A)
    bound = max((sum(abs(x) for x in row) for row in A), default=0)
    counts = Counter()
    for root in range(-bound, bound + 1):
        while len(poly) > 1:
            quotient, rem = divide_linear_desc(poly, root)
            if rem:
                break
            poly = quotient
            counts[root] += 1
    assert poly == [1], ("unfactored characteristic polynomial", poly)
    assert sum(counts.values()) == len(A)
    return counts


def exact_rank(A):
    M = [[Fraction(x) for x in row] for row in A]
    n = len(M)
    row = 0
    for col in range(n):
        pivot = next((r for r in range(row, n) if M[r][col]), None)
        if pivot is None:
            continue
        M[row], M[pivot] = M[pivot], M[row]
        v = M[row][col]
        M[row] = [x / v for x in M[row]]
        for r in range(row + 1, n):
            factor = M[r][col]
            if factor:
                M[r] = [a - factor * b for a, b in zip(M[r], M[row])]
        row += 1
        if row == n:
            break
    return row

def exact_commutator(A, B):
    AB = matmul(A, B)
    BA = matmul(B, A)
    return [[a - b for a, b in zip(ar, br)] for ar, br in zip(AB, BA)]


def check_global_lie_and_casimir():
    """Check every entry of all six 125x125 commutator identities.

    Uses full integer matrix multiplication, not only weight-block identities
    or a symbolic syzygy. A one-entry Casimir mutation must break centrality.
    """
    U = [[up(i, j) for j in range(N)] for i in range(N)]
    D = [[down(i, j) for j in range(N)] for i in range(N)]
    Z = [[z(i) if i == j else 0 for j in range(N)] for i in range(N)]
    C = [[casimir(i, j) for j in range(N)] for i in range(N)]
    zero = [[0] * N for _ in range(N)]
    assert exact_commutator(Z, U) == U
    assert exact_commutator(Z, D) == [[-x for x in row] for row in D]
    assert exact_commutator(U, D) == [[2 * x for x in row] for row in Z]
    print('E47_GLOBAL_LIE_RELATIONS_EXACT_PASS')
    assert exact_commutator(C, Z) == zero
    assert exact_commutator(C, U) == zero
    assert exact_commutator(C, D) == zero
    print('E47_GLOBAL_CASIMIR_CENTRALITY_EXACT_PASS')
    mutant = [row[:] for row in C]
    mutant[0][0] += 1
    assert exact_commutator(mutant, U) != zero
    print('E47_GLOBAL_CENTRALITY_MUTANT_REJECTED')


def main():
    check_global_lie_and_casimir()
    multiplicities = Counter()
    total_dim = total_rank = 0
    central = None
    for weight in range(-6, 7):
        states = [i for i in range(N) if z(i) == weight]
        n = len(states)
        A = [[casimir(i, j) for j in states] for i in states]
        assert all(casimir(i, j) == 0 and casimir(j, i) == 0
                   for i in states for j in range(N) if j not in states)
        # Characteristic roots are discovered from the concrete matrix,
        # not supplied by the expected seven-eigenvalue statement.
        block_counts = discover_integer_spectrum(A)
        multiplicities.update(block_counts)
        roots = sorted(block_counts)
        P = identity(n)
        for root in roots:
            P = matmul(P, subtract_root(A, root))
        assert P == [[0] * n for _ in range(n)]
        K = matmul(subtract_root(A, 6), subtract_root(A, 30))
        total_rank += exact_rank(K)
        total_dim += n
        if weight == 0:
            central = A
        print(f'weight={weight:+d} dimension={n} roots={dict(sorted(block_counts.items()))}')
    assert total_dim == N
    # Compare only after discovering every block's complete charpoly.
    assert dict(sorted(multiplicities.items())) == EXPECTED_SPECTRUM
    roots = sorted(multiplicities)
    # Verify one common global annihilator on every invariant block.
    for weight in range(-6, 7):
        states = [i for i in range(N) if z(i) == weight]
        A = [[casimir(i, j) for j in states] for i in states]
        P = identity(len(A))
        for root in roots:
            P = matmul(P, subtract_root(A, root))
        assert P == [[0] * len(A) for _ in A]
    assert total_rank == 78 and N - total_rank == 47
    print('E47_GLOBAL_ANNIHILATOR_EXACT_PASS')
    print('E47_GLOBAL_MULTIPLICITIES_EXACT_PASS', dict(sorted(multiplicities.items())))
    print('E47_GLOBAL_RANK_NULLITY_EXACT_PASS', total_rank, N - total_rank)
    assert central is not None
    mutant = [row[:] for row in central]
    mutant[0][0] += 1
    P = identity(len(mutant))
    for root in roots:
        P = matmul(P, subtract_root(mutant, root))
    assert any(v != 0 for row in P for v in row)
    print('E47_GLOBAL_MUTANT_REJECTED')
    print('E47_GLOBAL_ROOT_DISCOVERY_PASS', roots)

if __name__ == '__main__':
    main()
