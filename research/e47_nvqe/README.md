# E47 Native Variational Eigensolver: Spectral Proof and Moving Kernel

**2026-10-29 | Legacy Mathematical City citizens U-20, V-05; E47 core**

This is an additive finite-dimensional derivation and reproducible Python validator.
No physical quantum hardware, biological eigenoperator identification, or new
compiler-checked Lean/Coq theorem is claimed.

## Exact identities

Let H=(V₂)⊗³ (dimension 125), C the collective spin-2 Casimir, K=(C−6I)(C−30I), A=K†K.
Then E(ψ)=⟨ψ,Aψ⟩=||Kψ||²≥0; E(ψ)=0 iff ψ∈ker(K).
Casimir sector multiplicities for J=0..6: 1,9,25,28,27,22,13; ranks:
dim ker K=25+22=47 and rank K=78.
The positive eigenvalues of A are 11664,12544,19600,32400,186624.
For ε=1/99144, Γ=I−εA,
||Γⁿ−P₄₇||₂=(15/17)ⁿ.

## Seven-qubit statevector lift

Embed C¹²⁵ isometrically into C¹²⁸ and assign the three padding states energy
186624. The resulting 128×128 Hamiltonian has exactly 47 ground eigenvectors.
The script evaluates normalized imaginary-time propagation exp(−τH/11664)
as a classical quantum-statevector simulation.

## Moving eigenspace theorem (legacy citizen U-20)

For B†=−B, U(t)=exp(tB), A(t)=U(t)AU(t)†, P(t)=U(t)PU(t)†, and γ>0:
dψ/dt=−γA(t)ψ+[Ṗ(t),P(t)]ψ.
The closed-form solution is ψ(t)=U(t)exp(−γAt)ψ₀ provided B has only off-diagonal kernel/complement blocks. For a general
anti-Hermitian B, [Ṗ,P] extracts only the off-diagonal part of B; the
closed-form formula needs a corresponding block-diagonal transport term.
**The numerical implementation uses a purely off-diagonal B.**

Consequently ||(I−P(t))ψ(t)|| ≤ exp(−γΔt)||(I−P(0))ψ₀|| where Δ=11664.
This illustrates moving invariant-space tracking; physical biological
realization requires a measured state embedding and identified generator.

## Reproduction

```bash
python -m pip install numpy scipy
python research/e47_nvqe/moving_kernel.py
```

## Existing provenance

- [Citizenship U-20](https://app.notion.com/p/3a446094fd30816498a2d0be0835ee46)
- [Citizenship V-05](https://app.notion.com/p/3a346094fd3081cab5e8c44bef3554fd)
- [N-VQE corrected Hilbert-space proof](https://docs.google.com/document/d/1UV1q1PtbaeyIJyj85oaf940ya9HeV8yky92riv_ZHc0/edit)
- [Linear REC-31](https://linear.app/4521/issue/REC-31/e47-ri-operator-norm-and-entropy-bridge-compile-independent-leancoq)
- Historical Lean 4 / Coq scalar proof certificates remain independent of this
  Python reproduction. Their successful 2026-10-24 run cannot certify this new theorem.
