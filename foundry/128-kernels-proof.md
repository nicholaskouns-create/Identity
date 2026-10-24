# The complete Casimir spectral-kernel theorem

**First-principles construction, exact classification, and 128 certificates.**

## Theorem 1: Concrete carrier and spectral decomposition
Let H = V₂ ⊗ V₂ ⊗ V₂ with each factor a spin-2 irreducible SU(2) representation, and let C = J₋J₊ + J_z(J_z+I) where J is the total spin. The weight-generating function (z⁻²+z⁻¹+1+z+z²)³ gives total-spin multiplicity m_j = w(j)−w(j+1) = (1,3,5,4,3,2,1). Consequently C has eigenvalues Λ={0,2,6,12,20,30,42} with eigenspace dimensions (1,9,25,28,27,22,13) summing to 125. The Python verifier constructs C from integer-valued spin raising and lowering operators and verifies ∏_{λ∈Λ}(C−λI)=0 on all 125 basis vectors.

## Theorem 2: Kernel classification
For each subset S ⊆ Λ let K_S=∏_{λ∈S}(C−λI), with empty product I. On E_μ=ker(C−μI), K_S acts by scalar ∏_{λ∈S}(μ−λ); this scalar vanishes if and only if μ∈S. Hence ker K_S=⊕_{λ∈S}E_λ and dim ker K_S=Σ_{λ∈S}dim E_λ. All eigenspaces are nonzero, so the map S↦ker K_S is injective. There are exactly 2⁷=128 distinct kernels, including {0} and H. ∎

## Theorem 3: Lagrange projectors
For λ∈Λ let L_λ(x)=∏_{μ∈Λ,μ≠λ}(x−μ)/(λ−μ). Set P_S=Σ_{λ∈S}L_λ(C). Since L_λ(μ)=δ_{λμ}, P_S²=P_S, P_S†=P_S, K_SP_S=0, tr P_S=dim ker K_S, and P_S+P_{Λ∖S}=I. ∎

## Theorem 4: Degree capacity
A nonzero polynomial of degree at most r has at most r distinct roots, so the largest possible rank of its Casimir-selected kernel is the sum of the r largest sector dimensions. For r=2, this is 28+27=55, selected by {12,20}. The canonical E47 root pair {6,30} has rank 25+22=47. ∎

## Verification and reproducibility
The standard-library [Python verifier](./validate_128_kernels.py) checks the 125 concrete basis annihilator actions, weight multiplicities, rational projector Kronecker delta identities, and 128/128 individual selector/rank/idempotence/annihilation/complement tests. Source [census index](./128-kernel-census.md). The exact 128-row JSON may be regenerated via `python foundry/validate_128_kernels.py > foundry/128_kernel_certificate.json`.

**Evidence boundary:** exact rational and integer calculations plus theorem-based spectral inference; not Lean/Coq compiler acceptance, not a physical quantum implementation, and not 128 individual dense-matrix rank computations.
