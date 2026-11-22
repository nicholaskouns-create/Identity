#!/usr/bin/env python3
"""Independent numerical lane-19 regression (not a Lean/Coq proof).
Run: python3 validation/lane19_casimir_numeric.py
Requires NumPy. No CI completion or formal status is inferred.
"""
import numpy as np

m = np.arange(-2, 3, dtype=float)
plus = np.zeros((5, 5))
for i in range(4):
    plus[i+1, i] = np.sqrt(6 - m[i] * (m[i] + 1))
minus = plus.T
jx = (plus + minus) / 2
a = (plus - minus) / 2            # Jy = -i a
jz = np.diag(m)
identity = np.eye(5)

def lift(operator):
    return sum(
        np.kron(np.kron(operator if i == 0 else identity,
                        operator if i == 1 else identity),
                        operator if i == 2 else identity)
        for i in range(3)
    )

x, y_real, z = map(lift, (jx, a, jz))
casimir = x @ x - y_real @ y_real + z @ z
raising, lowering = x + y_real, x - y_real

eigenvalues, basis = np.linalg.eigh(casimir)
spectrum = (0, 2, 6, 12, 20, 30, 42)
counts = tuple(int(np.count_nonzero(np.abs(eigenvalues - s) < 1e-8))
               for s in spectrum)
assert counts == (1, 9, 25, 28, 27, 22, 13), counts

selected = (np.abs(eigenvalues - 6) < 1e-8) | (np.abs(eigenvalues - 30) < 1e-8)
p = basis[:, selected] @ basis[:, selected].T
selector = (casimir - 6 * np.eye(125)) @ (casimir - 30 * np.eye(125))

def commutator_norm(a, b):
    return float(np.linalg.norm(a @ b - b @ a))

report = {
    "sector_multiplicities": counts,
    "selected_rank": int(np.count_nonzero(selected)),
    "commutator_Z_frobenius": commutator_norm(casimir, z),
    "commutator_U_frobenius": commutator_norm(casimir, raising),
    "commutator_D_frobenius": commutator_norm(casimir, lowering),
    "projector_idempotence_frobenius": float(np.linalg.norm(p @ p - p)),
    "selector_projector_residual_frobenius": float(np.linalg.norm(selector @ p)),
}
assert report["selected_rank"] == 47
assert all(report[k] < 1e-9 for k in
           ("commutator_Z_frobenius", "commutator_U_frobenius",
            "commutator_D_frobenius", "projector_idempotence_frobenius",
            "selector_projector_residual_frobenius"))
for key, value in report.items():
    print(f"{key}: {value}")
print("Numerical regression PASS; formal lane-19 eigenspace proof remains OPEN.")
