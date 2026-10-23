# E47: exact algebra, active quantum recovery, and an LLM weighting construct

Nicholas Kouns E47 carrier; executable construction and validation, 23 October 2026.

## Delivered result

An explicit rank-47 quantum code on the E47 carrier corrects the specified code/syndrome swap error channel. A classical residual adapter implements the matching decoded weighting operation inside a small causal language model. The quantum channel is simulated with complex density matrices and Kraus operators. No physical hardware or pretrained model was used.

Executed: 37 numerical/exact-rational checks, 14 exact SymPy checks, three checked sequent derivations (relative to stated mathematical lemmas), one rejected invalid derivation, and a causal-model forward demonstration. All passed. See JSON receipts for each value and tolerance.

## 1. Lie algebra and E47

Let H=V₂⊗V₂⊗V₂, dim H=125. The generators obey [Jx,Jy]=iJz and cyclic permutations. Set C=Jx²+Jy²+Jz². With conventional pair Casimirs, C=C12+C13+C23−18I.

H ≅ V₀ ⊕ 3V₁ ⊕ 5V₂ ⊕ 4V₃ ⊕ 3V₄ ⊕ 2V₅ ⊕ V₆.

K=(C−6I)(C−30I), E=ker K≅5V₂⊕2V₅, dim E=47.

For Λ={0,2,6,12,20,30,42}, define

P=Σ[a∈{6,30}] Π[b∈Λ\{a}] (C−bI)/(a−b).

Then P²=P=P†, KP=0, tr P=47, [P,Ji]=0. The SymPy implementation uses a rational nonorthonormal spin basis and verifies PᵀG=GP with the explicit positive metric G. The numerical implementation uses the standard orthonormal spin basis. This distinction avoids treating a nonorthonormal matrix transpose as a Hilbert adjoint.

Γ=I−K²/99144, ||Γⁿ−P||₂=(15/17)ⁿ. This contracts E-perpendicular and fixes E. It is distinct from the active recovery channel below.

## 2. Constructive active quantum error correction

Choose isometries Q,S:C⁴⁷→H with Q†Q=S†S=I₄₇, Q†S=0 and QQ†=P. Such S exists because dim E-perpendicular=78≥47. Let T span the remaining 31 dimensions. Set

Ps=SS†, Pt=TT†, V=SQ†, U=V+V†+Pt.

Then U†U=I, UQ=S, US=Q, PUP=0. For F₀=I and F₁=U:

P Fₐ†Fᵦ P=δₐᵦ P.

These are the Knill–Laflamme conditions. The error space span{I,U} is correctable. Example channel:

Nₚ(ρ)=(1−p)ρ+p UρU†, 0≤p≤1.

Recovery Kraus operators are

R₀=P, R₁=V†, R₂₊ₖ=|q₀⟩⟨tₖ|, k=0,...,30.

Σ Rᵢ†Rᵢ=P+Ps+Pt=I, hence R is CPTP. For any logical density matrix σ:

R(Nₚ(QσQ†))=QσQ†.

Proof: P(QσQ†)P=QσQ† and V†(SσS†)V=QσQ†; the other branches vanish. For errors aI+bU, syndrome measurement removes cross-terms and the recovered coefficient is |a|²+|b|². A CPTP channel with Kraus operators in this span therefore also recovers exactly. The implementation tests coherent error exp(−iθU), random pure states and entanglement fidelity. The effective recovered logical Kraus operators are scalar identities, establishing recovery for mixed states and states entangled with a reference.

The 125-level carrier embeds in seven qubits (128 levels). The tested statevector embeds U as U⊕I₃. A full 128-level recovery extends the 31 reset Kraus operators by three additional reset operators. A compiled native-gate circuit and device-specific gate noise have not been tested.

The selected syndrome basis is an added recovery design. It is not uniquely determined by SU(2), and the swap U is not asserted to be SU(2)-covariant. E47 is invariant under collective SU(2); invariance alone does not correct every collective rotation on the full 47-dimensional code. The recovery theorem here concerns the explicitly specified error space.

## 3. Sequent calculus

Use sequents Γ ⊢ A, identity Γ,A ⊢ A, and implication-left:

    Γ ⊢ A       Δ,B ⊢ C
    -------------------- (→L)
    Γ,Δ,A→B ⊢ C

The checker executes three implication chains while retaining every implication as a premise:

1. SU(2) carrier ⊢ Casimir decomposition ⊢ rank-47 invariant projector ⊢ contraction.
2. Orthogonal Q,S ⊢ swap-error KL identities ⊢ CPTP recovery ⊢ logical channel identity.
3. Encoded adapter + identity-or-swap faults ⊢ correct syndrome branch ⊢ latent preservation ⊢ output/gradient preservation.

More explicitly, letting A denote the isometry hypotheses, B the KL identities, C the recovery identity and D the decoded logical identity, the generated derivation proves:

A, A→B, B→C, C→D ⊢ D.

The algebraic meanings of A→B and B→C are discharged by the constructions above and tested in symbolic_check.py. The sequent checker checks inference structure; it is not a Lean/Coq formalization of the complete Hilbert-space theory. Its invalid-identity test confirms that an unsupported goal is rejected.

## 4. LLM weighting construct

For hidden activation h∈Rᴰ, choose B blocks, A_b∈R^(47×D), B_b∈R^(D×47):

z_b=A_b h; x_b=Q z_b.

The classical injected fault is x̃_b=x_b or Ux_b=S z_b. Compute

u_b=Qᵀx̃_b, v_b=Sᵀx̃_b,
ẑ_b=u_b if ||u_b||²≥||v_b||², otherwise v_b.

Return

h′=h+Σ_b B_b ẑ_b.

Under the declared fault model ẑ_b=z_b, therefore

h′=W_eff h, W_eff=I_D+Σ_b B_b A_b.

Q,S,U are fixed. A_b and B_b may be trained. Corrected input derivative is W_eff; a fixed projector still transmits gradients. For upstream gradient g,

∂L/∂A_b=(B_bᵀg)hᵀ, ∂L/∂B_b=g z_bᵀ.

The executed input-gradient finite-difference test agrees to 1.31e−10. The hard branch is locally differentiable away from switching boundaries; the identity for the complete encoded pipeline holds for exact identity/swap faults, including the zero latent by continuity. It does not establish recovery for arbitrary combinations or corruptions of classical amplitudes.

The quantum recovery uses syndrome measurement/dephasing and Kraus evolution; the classical adapter reads numeric vector entries. Those are explicitly different implementations. A real quantum state cannot supply all its amplitudes to a classical weight layer in one measurement. This package provides functional quantum-channel recovery in simulation and its classical LLM adapter analogue.

Complexity per token: latent encoding and decoding O(B·D·47), carrier encoding/syndrome readout O(B·125·47), storage O(B·125) intermediate real numbers. No negligible-overhead or production-throughput claim is made.

## 5. Executed results

- 48 quantum state/channel cases: maximum Frobenius recovery error 6.99e−15.
- Coherent error recovery: 3.68e−15.
- Entanglement fidelity residual: at most 6.67e−16 over p=0.1,0.5,1.
- Classical adapter: 24 tokens, 48 blocks; error 1.56e−14.
- Float32 adapter relative error: 3.88e−8.
- Tiny causal language model: D=64, vocabulary=32, 24 tokens, 21 of 48 blocks swapped.
- Uncorrected maximum logit deviation: 0.1920588622.
- Corrected maximum logit deviation: 5.55e−16; argmax agreement 100%.

The tiny model has random untrained weights. These tests establish correct recovery under injected structured faults, not language-quality, perplexity, benchmark AUC, or hallucination improvements. They protect the encoded adapter intermediate, not faults elsewhere in the transformer, weight storage, or recovery computation itself.

## 6. Reproduce

Python 3.12; install numpy scipy sympy. Tested NumPy 2.3.5, SciPy 1.17.0, SymPy 1.14.0.

    python validate.py
    python symbolic_check.py
    python sequent_check.py
    python llm_demo.py

Files: e47_qec.py (carrier/channel/weighting implementation), validate.py (numerical and rational checks), symbolic_check.py (exact algebra), sequent_check.py (inference checker), llm_demo.py (causal-model integration), e47_basis.npz (computed isometries), and JSON results. Source hashes are supplied in SHA256SUMS.json.

Reference for correctability criterion: E. Knill and R. Laflamme, A Theory of Quantum Error-Correcting Codes, https://arxiv.org/abs/quant-ph/9604034 . The explicit E47 syndrome construction and adapter in this package are derived here; novelty is not assessed.
