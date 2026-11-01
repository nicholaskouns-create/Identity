# AQSFT finite-operator addendum (2026-10-31)

**Additive appendix to the existing E47 Emergent Monograph, §§6.2 and 10.4–10.7.** This document does not replace or modify the August 25 certificate MC-AQSFT-E47-20260825 (17/17 PASS), its validation bundle, or independent formalisms.

## Existing foundations (not new)
The monograph §6.2 already defines the scalar potential V(Ω)=Λ(Ω²−Ωc²)²/4 with Ωc=47/125 and a scalar equation of motion. Sections 10.4–10.7 already specify Higgs VEV/mass assignments and the recursion-depth Yukawa law y_f=√2 φ^{−(N_f−100)}√Ωc=√2 m_f/v. The August certificate verifies the SU(2) carrier, Casimir spectrum, selector, rank-47 projector and contraction, not these additional physical assignments.

## New exact finite-matrix calculation
On E47=5V₂⊕2V₅, C has eigenvalue 6 with multiplicity 25 and eigenvalue 30 with multiplicity 22. Define M=C−(810/47)I. Then Tr M=0, and:
- Tr(M²)=316800/47
- Tr(M⁴)=102004531200/103823
- Tr(M⁴)/Tr(M²)²=559/25850

These are centered-Casimir moments, not an independent derivation of the existing scalar coupling Λ or Higgs mass.

Define Y_F=diag((172/125)I₂₅,I₂₂), and D_F=[[0,Y_F],[Y_F†,0]] on E47_L⊕E47_R, dimension 94. Then:
- Tr(D_F²)=86668/625
- Tr(D_F⁴)=2180113612/9765625

**172/125 is inserted into Y_F**, so it is not derived from these traces.

## Equivariant Yukawa constraint
For SU(2), Hom(V_jL⊗V_s,V_jR) has dimension 1 iff |jL−s|≤jR≤jL+s (for the integer spins used), and 0 otherwise. The model enumerates 44 candidate triples with jL,jR∈{2,5}, s=0,…,10. For scalar spin zero, cross-spin intertwiners vanish; the multiplicity algebra M₅(C)⊕M₂(C) leaves singular values free. Both the target ratio 172/125 and counterexample ratio 2 are symmetry-compatible.

**Open physical bridge:** specify physical SU(2)_L×U(1)_Y left/right fermion modules, Higgs module and charges, then define an equivariant finite Yukawa map Y(N_f,χ) from the monograph's recursion-depth law. Derive its singular values and kinetic normalization without inserting the target mass ratio. The diagonal integer-spin carrier alone does not contain a weak spin-1/2 doublet.

## Numerical finite-block simulation
For D_i=yσ_x, y=172/125, t=0.37, U=exp(−itD_i): transition probability 0.23756757499647282; unitarity and norm conservation pass at 1e−13. This is not an independent physical mass prediction.

## Provenance and scope
- Existing monograph: `E47 Emergent Monograph(3).pdf`, §§6.2, 10.4–10.7.
- August machine certificate: SHA-256 `f4ab4b046e3da00e71db7105972209e1027a21e5aa2af72035a283476dde5dfc` (unchanged, 17/17 PASS).
- August validation ZIP: SHA-256 `a36fb4e4a9e8c6edb5270c853a6690e562351da5d2b2ec2d151bd038486ed663` (unchanged).
- Local finite-operator Python/SymPy model executed October 31, 2026. Exact moment assertions and unitary test passed. This addendum does not claim Lean/Coq compilation.
- New independently derived physical predictions: **zero**. New explicit computations: centered scalar moments, finite Dirac moments, intertwiner compatibility/counterexample.
