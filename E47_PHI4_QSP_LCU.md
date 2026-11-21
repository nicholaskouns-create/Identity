# E₄₇ Φ₄ · quantum-signal-processing circuit packet

Shared exact polynomial identity:

Q₄(s) = 1 − (2176/353)s² + (2048/353)s⁴.

P(s) = Q₄(s) + 272is²/353.

R(s) = s(2048s² − 1152 + 16i√817)/353.

|P(s)|² + (1−s²)|R(s)|² = 1.

A = |(C−6I)(C−30I)|/432 on V₂⊗³ (125D). Φ₄ ≈ (0, 0.618892044578, 0.439842582816, −0.179049461762, 0).

U₂₅₀ = Z(φ₀)W(A)Z(φ₁)W(A)Z(φ₂)W(A)Z(φ₃)W(A)Z(φ₄), where W(A) = [[A,i√(I−A²)],[i√(I−A²),A]].

V₅₀₀ = (H⊗I₂₅₀)diag(U₂₅₀,U₂₅₀†)(H⊗I₂₅₀).

⟨0_LCU,0_signal|V₅₀₀|0_LCU,0_signal⟩ = Q₄(A); ‖Q₄(A)−P₄₇‖₂ = 225/353.

The construction has an E0 exact algebraic derivation and E1 numerical CG/QSP/LCU certificate with 14/14 PASS, executed November 21, 2026. Hardware, full resource accounting and deterministic quantum-channel realization are not established.

- [**Full interactive circuit**](https://nicholaskouns-create.github.io/E47-Kartekeya/interfaces/qsvt-phi4-circuit/)
- [**Embedded Mathematical City theater**](https://nicholaskouns-create.github.io/qsvt-phi4/)
- [Complete derivation](https://github.com/nicholaskouns-create/E47-Kartekeya/blob/main/research/e47/qsp_phi4/README.md)
- [Executable 125D/250D/500D certificate](https://github.com/nicholaskouns-create/E47-Kartekeya/blob/main/research/e47/qsp_phi4/e47_phi4_cg_lcu_certificate.py)
- [JSON verification receipt](https://github.com/nicholaskouns-create/E47-Kartekeya/blob/main/research/e47/qsp_phi4/e47_phi4_cg_lcu_receipt.json)

**Local evidence boundary:** Separate exact algebra, compiler-checked formal modules, and numerical matrix claims. This linked certificate is NumPy E1, not a new Lean/Coq compiler run.
