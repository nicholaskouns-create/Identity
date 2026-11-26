#!/usr/bin/env python3
"""Independent exact 5x5 spin-2 Lie and Casimir witness (stdlib only)."""
import hashlib
import json
from pathlib import Path

N = 5
Z = [[(2-i) if i == j else 0 for j in range(N)] for i in range(N)]
U = [[j*(5-j) if i+1 == j else 0 for j in range(N)] for i in range(N)]
D = [[1 if i == j+1 else 0 for j in range(N)] for i in range(N)]
def mm(a,b):
    return [[sum(a[i][k]*b[k][j] for k in range(N)) for j in range(N)] for i in range(N)]
def add(a,b):
    return [[a[i][j]+b[i][j] for j in range(N)] for i in range(N)]
def sub(a,b):
    return [[a[i][j]-b[i][j] for j in range(N)] for i in range(N)]
def scale(k,a):
    return [[k*a[i][j] for j in range(N)] for i in range(N)]
def bracket(a,b):
    return sub(mm(a,b),mm(b,a))
def assert_eq(a,b,name):
    if a != b:
        raise AssertionError(name)
assert_eq(bracket(Z,U),U,"Z/U")
assert_eq(bracket(Z,D),scale(-1,D),"Z/D")
assert_eq(bracket(U,D),scale(2,Z),"U/D")
I = [[int(i==j) for j in range(N)] for i in range(N)]
assert_eq(add(add(mm(D,U),mm(Z,Z)),Z),scale(6,I),"Casimir")
mutant = [r[:] for r in U]
mutant[0][1] += 1
assert bracket(mutant,D) != scale(2,Z), "mutant was not rejected"
print(json.dumps({"status":"E47_LOCAL_SPIN2_PASS","dimension":N,
                  "matrix_entries_checked":25*4,
                  "negative_control_rejected":True},sort_keys=True))
