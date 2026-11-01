#!/usr/bin/env python3
"""Independent exact-integer dense/sparse comparison for the E47 third bracket.
No external packages, inferred eigenvalues, or private resources.
"""
import hashlib
import json
from pathlib import Path

def abc(n):
    return n // 25, (n // 5) % 5, n % 5

def z(i, j):
    a, b, c = abc(i)
    return 6 - a - b - c if i == j else 0

def up(i, j):
    a, b, c = abc(i)
    x, y, t = abc(j)
    return (x * (5 - x) if a + 1 == x and b == y and c == t else 0) + (
        y * (5 - y) if a == x and b + 1 == y and c == t else 0) + (
        t * (5 - t) if a == x and b == y and c + 1 == t else 0)

def down(i, j):
    a, b, c = abc(i)
    x, y, t = abc(j)
    return int(a == x + 1 and b == y and c == t) + int(
        a == x and b == y + 1 and c == t) + int(
        a == x and b == y and c == t + 1)

def sparse(i, j, raising=up):
    return sum(raising(i, k) * down(k, j) for k in (i + 25, i + 5, i + 1)) - sum(
        down(i, i - s) * raising(i - s, j) for s in (25, 5, 1) if i >= s)

def dense(i, j, raising=up):
    return sum(raising(i, k) * down(k, j) -
               down(i, k) * raising(k, j) for k in range(125))

def mutant(i, j):
    return up(i, j) + int(i == 0 and j == 25)

def main():
    count = 0
    for i in range(125):
        for j in range(125):
            lhs, rhs, target = sparse(i, j), dense(i, j), 2 * z(i, j)
            assert lhs == rhs == target, (i, j, lhs, rhs, target)
            count += 1
    assert sparse(0, 0, mutant) != 2 * z(0, 0)
    assert dense(0, 0, mutant) != 2 * z(0, 0)
    print(json.dumps({
        "status": "E47_THIRD_BRACKET_BRIDGE_PASS",
        "pairs": count,
        "dense_terms_per_product": 125,
        "sparse_intermediates_per_row": 6,
        "negative_control_rejected": True,
        "claim_boundary": "Python exact full matrix; paired formal sparse all-pairs and dense row zero only"
    }, sort_keys=True))

if __name__ == "__main__":
    main()
