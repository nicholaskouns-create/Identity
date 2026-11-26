#!/usr/bin/env python3
"""Independent exact integer trace-moment and Lagrange inversion witness.

This program does NOT assume the concrete Casimir eigenvalues. It constructs
its 125-state entries and traces from sparse products, then separately checks
candidate spectral moments and an exact invertible moment transform.
"""
from collections import defaultdict

ROOTS = (0, 2, 6, 12, 20, 30, 42)
CANDIDATE_MULT = (1, 9, 25, 28, 27, 22, 13)
EXPECTED_MOMENTS = (125, 2250, 58500, 1827000, 63205200,
                    2327148000, 89208187200)

def xyz(n):
    return n // 25, (n // 5) % 5, n % 5

def idx(v):
    return 25 * v[0] + 5 * v[1] + v[2]

def generators():
    up, down = ([{} for _ in range(125)] for _ in range(2))
    for j in range(125):
        v = list(xyz(j))
        for axis in range(3):
            if v[axis] > 0:
                w = v.copy()
                w[axis] -= 1
                up[idx(w)][j] = v[axis] * (5 - v[axis])
            if v[axis] < 4:
                w = v.copy()
                w[axis] += 1
                down[idx(w)][j] = 1
    return up, down

def multiply(a, b):
    out = []
    for row in a:
        result = defaultdict(int)
        for k, v in row.items():
            for j, w in b[k].items():
                result[j] += v * w
        out.append({j: v for j, v in result.items() if v})
    return out

def casimir():
    up, down = generators()
    c = multiply(down, up)
    for i in range(125):
        z = 6 - sum(xyz(i))
        c[i][i] = c[i].get(i, 0) + z * (z + 1)
    return c

def traces(c):
    p = [{i: 1} for i in range(125)]
    moments = []
    for _ in range(7):
        moments.append(sum(p[i].get(i, 0) for i in range(125)))
        p = multiply(p, c)
    return tuple(moments)

def product_poly(excluded):
    p = [1]
    for j, root in enumerate(ROOTS):
        if j == excluded:
            continue
        nxt = [0] * (len(p) + 1)
        for k, a in enumerate(p):
            nxt[k] -= root * a
            nxt[k + 1] += a
        p = nxt
    return tuple(p)

def main():
    c = casimir()
    actual = traces(c)
    assert actual == EXPECTED_MOMENTS, (actual, EXPECTED_MOMENTS)
    print('E47_CONCRETE_MOMENTS_EXACT_PASS', actual)

    rows = tuple(product_poly(i) for i in range(7))
    diag = tuple(sum(rows[i][k] * ROOTS[i]**k for k in range(7))
                 for i in range(7))
    for i in range(7):
        for j in range(7):
            val = sum(rows[i][k] * ROOTS[j]**k for k in range(7))
            assert val == (diag[i] if i == j else 0), (i, j, val)
        assert diag[i] != 0
    print('E47_LAGRANGE_LEFT_INVERSE_EXACT_PASS', diag)

    candidate_moments = tuple(sum(CANDIDATE_MULT[j] * ROOTS[j]**k
                                  for j in range(7)) for k in range(7))
    assert candidate_moments == actual
    recovered = tuple(sum(rows[i][k] * actual[k] for k in range(7)) // diag[i]
                      for i in range(7))
    assert recovered == CANDIDATE_MULT
    assert all(sum(rows[i][k] * actual[k] for k in range(7)) ==
               diag[i] * recovered[i] for i in range(7))
    print('E47_MULTIPLICITY_MOMENT_RECOVERY_PASS', recovered)

    mutant = [dict(row) for row in c]
    mutant[0][0] = mutant[0].get(0, 0) + 1
    assert traces(mutant) != actual
    print('E47_CONCRETE_CASIMIR_MUTANT_REJECTED')

if __name__ == '__main__':
    main()
