#!/usr/bin/env python3
"""Independent stdlib-only exact polynomial division for E47 projector congruences.
No concrete matrix eigenspaces, multiplicities, or rank are assumed here.
"""
import json
import platform
from functools import reduce

def mul(a, b):
    out = [0] * (len(a) + len(b) - 1)
    for i, x in enumerate(a):
        for j, y in enumerate(b):
            out[i + j] += x * y
    return out

def sub(a, b):
    return [(a[i] if i < len(a) else 0) -
            (b[i] if i < len(b) else 0)
            for i in range(max(len(a), len(b)))]

def product(factors):
    return reduce(mul, factors, [1])

def divide_monic(a, b):
    remainder = list(a)
    quotient = [0] * (len(a) - len(b) + 1)
    assert b[-1] == 1
    for i in range(len(quotient) - 1, -1, -1):
        quotient[i] = remainder[i + len(b) - 1]
        for j, coefficient in enumerate(b):
            remainder[i + j] -= quotient[i] * coefficient
    return quotient, remainder

def lin(root):
    return [-root, 1]

def main():
    numerator = product(map(lin, [0, 2, 12, 20, 31, 42]))
    annihilator = product(map(lin, [0, 2, 6, 12, 20, 30, 42]))
    kernel_filter = product(map(lin, [6, 30]))
    d = 1814400
    idem = sub(mul(numerator, numerator), [d * x for x in numerator])
    kill = mul(kernel_filter, numerator)
    q_idem, r_idem = divide_monic(idem, annihilator)
    q_kill, r_kill = divide_monic(kill, annihilator)
    assert q_idem == [312480, 160048, -47400, 3553, -102, 1]
    assert q_kill == [-31, 1]
    assert not any(r_idem) and not any(r_kill)
    assert numerator == [0, -624960, 430848, -66940, 4088, -107, 1]
    assert annihilator == [0, 3628800, -3110400, 808848, -89280, 4648, -112, 1]
    mutant = product(map(lin, [0, 2, 12, 20, 30, 42]))
    mutant_idem = sub(mul(mutant, mutant), [d * x for x in mutant])
    _, mutant_remainder = divide_monic(mutant_idem, annihilator)
    assert any(mutant_remainder), "negative control unexpectedly accepted"
    print(json.dumps({
        "status": "E47_PROJECTOR_CONGRUENCES_PASS",
        "python": platform.python_version(),
        "q_idempotence": q_idem,
        "q_kernel": q_kill,
        "remainders_zero": True,
        "negative_control_rejected": True,
        "scope": "integer polynomial coefficients; not concrete matrix formalization"
    }, sort_keys=True))

if __name__ == "__main__":
    main()
