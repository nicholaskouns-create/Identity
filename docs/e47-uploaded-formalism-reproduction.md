# Uploaded E47 formalism: reproduction and corrections (2026-10-24)

Source: *Formal Verification of the E47 Unified Formalism and Casimir Spectral-Kernel Theorem.docx* (user-provided). This document is a validation record, not a blanket certification of the source.

## Reproduction
- Original extracted Python failed at the Casimir spectrum assertion. Its raising entry used `m_vals[i]` instead of the column's `m_vals[i+1]`; the correct coefficient for `J_+|m>` is `sqrt((2-m)(3+m))`.
- Correcting that index allowed the extracted Python program to reach its final PASS printout locally. That printout includes some overbroad claims: checking the ratio 15/17 is not by itself a contraction theorem, and checking numerical coincidences does not prove logical independence.
- Independently built `validation/e47_lie_reproduction.py`, checking all three spin-2 Lie brackets, spin-2 Casimir 6I, all three 125-dimensional Lie brackets, Casimir commutation, spectrum, rank-47 projector, exact rational contraction factor, and enumeration of 128 subsets.
- Local run: PASS. Max Lie algebra residual 3.553e-15, Casimir commutation residual 1.421e-14, projector idempotence residual 6.661e-16, K P residual 2.061e-13; spectrum {0:1,2:9,6:25,12:28,20:27,30:22,42:13}; rank 47; rho 15/17.
- This is numerical evidence, NOT compiler acceptance of the full matrix-level theorem in Lean/Coq.

## Source discrepancies requiring explicit treatment
- The uploaded 128-kernel census table assigns sector labels/dimensions inconsistently with its own theorem. The correct dimension for E6 ⊕ E30 is 25+22=47, NOT E0 ⊕ E42. The largest quadratic kernel is E12 ⊕ E20 with dimension 28+27=55, NOT E0 ⊕ E30.
- The uploaded 8-qubit diagram describes an isometry from 256-dimensional qubit space into a 47-dimensional space, which cannot exist. A 125-dimensional carrier can be embedded into 7 data qubits (128 dimensions), with an additional syndrome ancilla.
- The uploaded abstract Lean 'kernel_projector_is_sum' is a reflexive equality proved by rfl, not a proof of a projector/kernel identity.
- For stable contraction use Gamma = I - K^2/99144, not generally I - epsilon K.

## Follow-up
Integrate the numerical script in an existing Python CI job and link a real successful workflow run. Separately advance Lean/Coq concrete matrix commutators and Casimir polynomial proofs. Do not treat the Python test as formal proof.
