#!/usr/bin/env python3
"""Independent exact 125-state tensor-lift parity check, no dependencies.
This checks the literal 5x5 Kronecker-sum lift against the concrete
Tensor125 generators; it does not assert the full Casimir theorem.
"""
import json

def coords(n):
    return n // 25, (n // 5) % 5, n % 5

def delta(i, j):
    return int(i == j)

def z5(i, j):
    return 2 - i if i == j else 0

def up5(i, j):
    return j * (5 - j) if i + 1 == j else 0

def down5(i, j):
    return int(i == j + 1)

def lift(g, i, j):
    a, b, c = coords(i)
    A, B, C = coords(j)
    return (g(a, A) * delta(b, B) * delta(c, C)
            + delta(a, A) * g(b, B) * delta(c, C)
            + delta(a, A) * delta(b, B) * g(c, C))

def concrete_z(i, j):
    a, b, c = coords(i)
    return 6 - a - b - c if i == j else 0

def concrete_up(i, j):
    a, b, c = coords(i)
    A, B, C = coords(j)
    return ((A * (5 - A) if a + 1 == A and b == B and c == C else 0)
            + (B * (5 - B) if a == A and b + 1 == B and c == C else 0)
            + (C * (5 - C) if a == A and b == B and c + 1 == C else 0))

def concrete_down(i, j):
    a, b, c = coords(i)
    A, B, C = coords(j)
    return (int(a == A + 1 and b == B and c == C)
            + int(a == A and b == B + 1 and c == C)
            + int(a == A and b == B and c == C + 1))

def check():
    assert all(25*a + 5*b + c == n
               for n in range(125) for a, b, c in [coords(n)])
    for local, concrete in ((z5, concrete_z), (up5, concrete_up),
                            (down5, concrete_down)):
        assert all(lift(local, i, j) == concrete(i, j)
                   for i in range(125) for j in range(125))
    def mutant_up(i, j):
        return up5(i, j) + int(i == 0 and j == 1)
    assert lift(mutant_up, 0, 25) != concrete_up(0, 25)
    print("E47_TENSOR_LIFT_PARITY_PASS " + json.dumps({
        "dimension": 125, "entries_per_generator": 15625,
        "generator_parity": "PASS", "index_roundtrip": "PASS",
        "negative_control_rejected": True
    }, sort_keys=True))

if __name__ == "__main__":
    check()
