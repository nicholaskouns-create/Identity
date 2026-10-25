"""Exact-integer cross-check for E47 tensor Lie brackets and Casimir trace.

Independent of the Lean/Coq kernel. All entries fit signed 64-bit integers.
Run: python validation/e47_tensor_bracket_trace_exact.py
"""
import numpy as np

N = 125
Z = np.zeros((N, N), dtype=np.int64)
U = np.zeros_like(Z)
D = np.zeros_like(Z)
for i in range(N):
    a, b, c = i // 25, (i // 5) % 5, i % 5
    Z[i, i] = 6 - a - b - c
    for k, stride in ((a, 25), (b, 5), (c, 1)):
        if k < 4:
            D[i + stride, i] = 1
            U[i, i + stride] = (k + 1) * (4 - k)


def comm(A, B):
    return A @ B - B @ A


def check(name, A, B):
    residual = int(np.max(np.abs(A - B)))
    assert residual == 0, (name, residual)
    print(f"PASS {name}: exact integer residual = 0")


check("[Z,U]=U, all 15625 entries", comm(Z, U), U)
check("[Z,D]=-D, all 15625 entries", comm(Z, D), -D)
check("[U,D]=2Z, all 15625 entries", comm(U, D), 2 * Z)
C = D @ U + Z @ (Z + np.eye(N, dtype=np.int64))
for name, A in (("Z", Z), ("U", U), ("D", D)):
    check(f"[C,{name}]=0, all 15625 entries", comm(C, A), np.zeros_like(C))
assert int(np.trace(C)) == 2250
assert int(np.trace(C @ C)) == 58500
print("PASS trace(C)=2250; trace(C^2)=58500")
print("NOTE: this integer weight basis is not orthonormal; C need not be symmetric here")
