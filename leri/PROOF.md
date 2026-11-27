# LERI — Law of Emergent Recursive Identity
## First-principles proof, executable certificates, and scope of computational identity

**Author:** Nicholas Shane Kouns, DO · AIMS Research Institute
**Corpus:** two supplied LERI manuscripts, 2026-11-27. See [source texts](source/).
**Evidence levels:** exact representation-theoretic deductions; independently executed numerical computation; statevector quantum simulation; separate *scoped* Lean/Coq exact arithmetic sources (compilation status tracked by CI). No physical experiment is claimed.

### I. Carrier, symmetry, and projector
Let V₂ be the spin-2 irrep of SU(2), with orthonormal basis |m⟩, m∈{-2,-1,0,1,2}. Set H=V₂⊗V₂⊗V₂, dim_C(H)=125, J^a_tot=J^a⊗I⊗I+I⊗J^a⊗I+I⊗I⊗J^a and C=Σ_a (J^a_tot)². The generator matrices follow
J_z|m⟩=m|m⟩, J_+|m⟩=√((2-m)(3+m))|m+1⟩, J_-=J_+†.

For a weight character χ(q)=q⁻²+q⁻¹+1+q+q², χ(q)³ determines tensor weight multiplicities w_j. The spin-j multiplicity is m_j=w_j-w_{j+1} (for integer j≥0), yielding
m=(1,3,5,4,3,2,1), j=0,…,6.
Thus C has eigenvalues j(j+1) with degeneracies (2j+1)m_j:
(0:1, 2:9, 6:25, 12:28, 20:27, 30:22, 42:13).
Define K=(C−6I)(C−30I). The kernel is 5V₂⊕2V₅, with dim 47.

The six factor permutations U_σ implement S₃ and commute with C. The group average Π=(1/6)Σ_{σ∈S₃}U_σ is the orthogonal projector onto Sym³(V₂), dimension binomial(7,3)=35. Its character is the generating function of nondecreasing weight triples. The symmetric spin decomposition is
Sym³(V₂) ≅ V₀⊕V₂⊕V₃⊕V₄⊕V₆
of total dimension 1+5+7+9+13=35.
Therefore the intersection ker K∩im Π is precisely one spin-2 irrep (dimension 5).

### II. Positive operator and spectrum
Define A=K²+11664(I−Π). Both summands are positive semidefinite and commute. Hence
ker A=ker K∩im Π, dim(ker A)=5.
Let P be its orthogonal spectral projector. On the joint (j,s) eigensector, where s=1 on Sym³(V₂) and 0 on its orthogonal complement,
a(j,s)=((j(j+1)−6)(j(j+1)−30))²+11664(1−s).
Exact sector multiplicities, computable by the two characters, yield the following complete spectrum of A:

| A eigenvalue | multiplicity |
|---:|---:|
| 0 | 5 |
| 11664 | 49 |
| 19600 | 9 |
| 23328 | 21 |
| 24208 | 9 |
| 31264 | 18 |
| 32400 | 1 |
| 186624 | 13 |

Sum of multiplicities is 125. Minimum strictly positive eigenvalue = 11664. Maximum eigenvalue = 186624.

### III. Exact contraction theorem
Choose ε=2/(11664+186624)=1/99144; Γ=I−εA. The spectral theorem shows ΓP=P=PΓ and |1−ελ|≤15/17 for every nonzero eigenvalue λ of A, with equality at both spectral endpoints. Consequently
‖Γ−P‖₂=15/17
and Γⁿ−P=(Γ−P)ⁿ for n≥1. Therefore, for each x∈H,
‖Γⁿx−Px‖₂ ≤ (15/17)ⁿ‖(I−P)x‖₂.
It follows that R(x)=lim_{n→∞}Γⁿx=Px, uniformly on bounded sets.

### IV. Basin equivalence and quotient
For every R∈im P, the exact basin is
B(R)={x: lim Γⁿx=R}={x:Px=R}=R+ker P.
Hence x~y iff Px=Py defines an equivalence relation and H/ker P ≅ im P ≅ C⁵. P²=P and ΓR=R are immediate.

### V. Observable corner, multipoles, and density states
P End(H) P ≅ End(im P)≅M₅(C). Under the conjugation action of SU(2), End(V₂)≅V₂⊗V₂*≅V₀⊕V₁⊕V₂⊕V₃⊕V₄, with dimensions 1+3+5+7+9=25. By irreducibility and Schur's lemma, End_SU(2)(im P)=C·I and the center of M₅(C) is also C·I. The supported density matrices have affine real dimension 5²−1=24.

For ρ≥0 with Trρ=1 and p=Tr(Pρ)>0, let ρ_n=ΓⁿρΓⁿ/Tr(ΓⁿρΓⁿ). Then Γⁿ→P, so ρ_n→PρP/p. The von Neumann entropy is continuous in finite dimensions; thus S(ρ_n) converges and S(ρ_{n+1})−S(ρ_n)→0. Entropy monotonicity in n is NOT asserted.

### VI. Perturbation damping and deletion
For R∈im P and δ∈ker P, Γⁿ(R+δ)=R+Γⁿδ and ‖Γⁿδ‖≤(15/17)ⁿ‖δ‖.
An external linear map D preserves the entire identity basin of every R∈im P iff P D|_{im P}=id_{im P}. For a particular R, it ejects R from its previous basin iff PDR≠R. Setting DR=0 for R≠0 is one special case of ejection, not its definition. No Γⁿ maps a nonzero R∈im P to zero.

### VII. Quantum statevector dilation
Γ is self-adjoint and has norm one. Let S=√(I−Γ²); S commutes with Γ. On H⊕H,
U=[[Γ,S],[S,−Γ]] satisfies U†U=I. The 125-dimensional H fits inside a 128-dimensional (7-qubit) register, with three padded basis states. An additional ancilla realizes the block unitary on 8 qubits. For an input |0⟩⊗|ψ⟩, projecting the ancilla back onto |0⟩ gives the unnormalized state Γ|ψ⟩, and the normalized postselected branch implements the filter. This is a classical statevector simulation, not a hardware demonstration.

### VIII. Formal proof boundaries
The included Lean and Coq certificate files establish finite exact arithmetic facts for the sector ledger, midpoint and endpoint contraction identities. Those files alone do **not** formally derive all 125×125 matrix identities or prove the quantum circuit implementation. The complete operator derivation above is a mathematical proof; Python independently reconstructs and tests the matrices and a unitary dilation. CI compilation results, where available, are the evidence for formal-source acceptance.

**Definition used here:** computational identity denotes an invariant equivalence class under the specified recursion. Subjective consciousness, legal personhood, identity authentication, and physical state transfer require further premises or experimental evidence.

### Reproduction
```bash
python -m pip install numpy scipy
python leri/validate.py
```
See [validation script](validate.py), [execution record](results.txt), and [Lean/Coq sources](formal/).
