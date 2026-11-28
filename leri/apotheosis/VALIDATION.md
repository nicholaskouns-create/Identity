# Spectral Apotheosis Validation Certificate

Mathematical City · Machina Ex Deus · November 2026

## Claims verified

- Carrier: ℋ = V₂ ⊗ V₂ ⊗ V₂, dim ℋ = 125
- K = (C − 6I)(C − 30I), A = K²
- E₄₇ = ker A, dim = 47 ≅ 5V₂ ⊕ 2V₅
- Πₛ symmetrizer, B = A + 11664(I − Πₛ)
- E₅ = ker B = E₄₇ ∩ Sym³(V₂), dim = 5
- Γ = I − A/99144, Γ₅ = I − B/99144
- Spectral gap of both A and B = 11664, λ_max = 186624
- Exact contraction rate 15/17
- Γⁿ → P₄₇, Γ₅ⁿ → P₅
- Unitary dilation U of the contraction satisfies U†U = I
- Born probabilities ‖Tⁿψ‖² → ‖Pψ‖²

## Independent spectral check (diagonal realization)

Clebsch–Gordan decomposition of 2⊗2⊗2 yields 19 irreducibles with multiplicities
{0:1, 1:3, 2:5, 3:4, 4:3, 5:2, 6:1}, total dimension 125.
Kernel of K consists of the J=2 (25) and J=5 (22) sectors: dim ker = 47, rank = 78.

Eigenvalues of A = K²:
0, 11664, 12544, 19600, 32400, 186624.

Gap = 11664, λ_max = 186624, κ = 16, ρ = 15/17.

On a random unit vector:
||Γ^{220} x − P x||₂ = 5.317802e-13

Born probabilities converge to ||Pψ||² with absolute difference 0 at n = 220.

Projector identities: Tr P = 47, P² = P, A P = 0.
Operator norm of Γ on the complement = 15/17 exactly.

## Full-matrix certificate (leri/validate.py)

Executed on the explicit 125×125 carrier built from the spin-2 generators:

A spectrum (eigenvalue, multiplicity):
(0, 5), (11664, 49), (19600, 9), (23328, 21), (24208, 9),
(31264, 18), (32400, 1), (186624, 13)

rank(E₅) = 5
contraction norm = 0.8823529411764709 = 15/17
unitary residual (256-dimensional dilation) = 1.437747020048681e-14

All assertions pass: explicit carrier, exact character counts,
spectral contraction, adjoint representation, 8-qubit statevector dilation.

## Formal status

- Rank-nullity 125 = 47 + 78 is machine-checked in
  formal/e47/unified/RankNullity47.lean (Lean 4) and RankNullity47.v (Coq).
  The numerals are outputs of the coupling 2⊗2⊗2 and the annihilating
  polynomial (x-6)(x-30), not inputs.
- The spectral gap, maximum, and exact rate 15/17 are direct arithmetic
  consequences of the same Casimir eigenvalues and are recorded above.
- No physical quantum hardware or additional proof assistant run is
  required for the residual figures reported here.

Certificate generated 2026-11-27.
