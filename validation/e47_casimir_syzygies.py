#!/usr/bin/env python3
"""Exact free-associative-algebra coefficient witness for Casimir syzygies.
Independent of Lean/Coq syntax, representation dimension and spectrum.
"""
from collections import defaultdict
from itertools import product

def atom(k): return {(k,): 1}
def plus(*ps):
    out = defaultdict(int)
    for p in ps:
        for word, coeff in p.items(): out[word] += coeff
    return {w: c for w, c in out.items() if c}
def minus(p): return {w: -c for w, c in p.items()}
def sub(p, q): return plus(p, minus(q))
def times(p, q):
    out = defaultdict(int)
    for w, c in p.items():
        for v, d in q.items(): out[w + v] += c * d
    return {w: c for w, c in out.items() if c}
def scale(p, n): return {w: n * c for w, c in p.items()}
def comm(p, q): return sub(times(p, q), times(q, p))

u, d, z = atom(0), atom(1), atom(2)
rzu = sub(sub(times(z, u), times(u, z)), u)
rzd = plus(sub(times(z, d), times(d, z)), d)
rud = sub(sub(times(u, d), times(d, u)), scale(z, 2))
c = plus(times(d, u), times(z, z), z)
claims = {
    'Z': (comm(c, z), plus(minus(times(d, rzu)), minus(times(rzd, u)))),
    'U': (comm(c, u), plus(minus(times(rud, u)), times(z, rzu), times(rzu, z))),
    'D': (comm(c, d), plus(times(d, rud), times(z, rzd), times(rzd, z))),
}
words = {w for n in range(4) for w in product(range(3), repeat=n)}
assert len(words) == 40
for label, (lhs, rhs) in claims.items():
    assert all(len(w) <= 3 and set(w) <= {0, 1, 2} for w in lhs | rhs)
    assert all(lhs.get(w, 0) == rhs.get(w, 0) for w in words), label
    assert lhs == rhs, label
    print(f'E47_SYZYGY_{label}_EXACT_PASS words=40')
mutant = plus(claims['U'][1], z)
assert mutant != claims['U'][0] and sub(claims['U'][0], mutant) == minus(z)
print('E47_SYZYGY_MUTANT_REJECTED')
