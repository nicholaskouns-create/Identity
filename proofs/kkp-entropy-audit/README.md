# KKP–MED entropy / Ginzburg–Landau proof audit

These are **limited mathematical audit files**, not a proof of the manuscript's universal critical coherence threshold or of gravitoelectromagnetic superconductivity.

- Exact spectral dimension ratio: 47/125 = 0.376.
- The binary entropy maximum occurs at p=1/2, not p=0.376.
- Homogeneous Ginzburg–Landau stability permits distinct minima for different coefficients.
- The manuscript does not provide enough physical parameters or data to reproduce its QuTiP or gravitomagnetic claims.

Run: `python validate.py`, `lake env lean KKPEntropy.lean` (Mathlib project), `coqc KKPEntropy.v`.

**Verification status:** Python arithmetic has been checked. Lean and Coq source are candidates and must be compiled before claiming compiler-verified proofs. Publication DOI 10.1000/jatp.2025.10.3.123 has not been authenticated.
