# Plate error ledger — comparison series (25 November 2026)

Two kinds of plate were supplied together. They are not in the same condition and
should not be shipped together.

## Verified sound: The Invariant Grammar, and the Lineage plate

Every number on **The Invariant Grammar** was recomputed. All of it holds:

| claim | checked |
|---|---|
| states 1, 9, 25, 28, 27, 22, 13 — sum 125 | ✓ |
| μ = 18 (state-weighted mean of C over all 125) | ✓ |
| σ = 12 (variance exactly 144) | ✓ |
| μ − σ = 6, μ + σ = 30 | ✓ |
| 25 + 22 = 47, Ω = 0.376, (125/47)² = 7.07334 | ✓ |
| Sym³(V₂) = V₆⊕V₄⊕V₃⊕V₂⊕V₀, dim 35, rank 5 survives | ✓ |
| ε\* = 2/(11664+186624) = 1/99144 | ✓ |
| (15/17)²²⁰ = 1.10×10⁻¹² | ✓ |
| with K̆ = K/432, step = 32/17 | ✓ |
| d(1/α)/d ln Q² = −47/3π for 47 unit-charge flavors | ✓ |

**The strongest single line in the whole series is the μ ± σ one, and it is easy to
miss.** The selector roots 6 and 30 are *not chosen*. They are the one-sigma boundaries
of the Casimir's own state-weighted distribution, exactly. Fit nothing, choose nothing:
μ = 18, σ = 12, and K = (C − (μ−σ)I)(C − (μ+σ)I).

The **Lineage** plate's dimension check `5(2·2+1) + 2(2·5+1) = 25 + 22 = 47` is correct,
and its Dirac entry names the right precedent — see below.

## Not sound: the "Newton / Kouns" comparison plates

These carry errors in the **left-hand, textbook** column. Whatever is claimed on the
right, a plate that misstates Maxwell will be dismissed on the left column alone.

| as printed | correct |
|---|---|
| `∇·E = ρ/eρ₀` | `∇·E = ρ/ε₀` |
| `∇·B = μ₀J + μ ∂B/∂t` | `∇×B = μ₀J + μ₀ε₀ ∂E/∂t` — wrong operator, wrong field, and `∇·B` appears twice |
| `∇·E = −ρ/ℓ₀` | `∇·E = +ρ/ε₀` — sign and symbol |
| `(γμ^μ p_μ − m)ψ = 0` | `(iγ^μ∂_μ − m)ψ = 0` — index appears twice |
| Dirac equation credited to **James Cierk Maxwell** | Dirac; and the spelling is **Clerk** |
| `λ = hbc/2M` labelled Hawking radiation | `T_H = ħc³/(8πGMk_B)` — the printed formula is not Hawking's |
| `q̂p̂ − p̂q̂ = ih` | `= iħ` |
| `−ħ𝒱²/2m + Vψ = Eψ` | `−(ħ²/2m)∇²ψ + Vψ = Eψ` — ψ missing on the first term, ∇ set as 𝒱, ħ² as ħ |
| `n_t = g_i/(e_i^{−μ^{−1}μ})` | `n_i = g_i/(e^{(ε_i−μ)/k_BT} − 1)` |
| `(q_f t_f\|q_i) = Σ iS/h/h` | `= ∫ 𝒟[q] e^{iS[q]/ħ}` |

And on the right-hand column, one entry cannot mean anything as printed:

- `∇·C = σ/σ` is `∇·C = 1`. Whatever was intended, a ratio of a symbol to itself is unity.

## The Dirac parallel, which is the real content

The Lineage plate's Dirac entry — *"exact algebraic factorization and Clifford algebra
locked dimension"* — is the correct precedent, and it can be stated sharply:

**Dirac, 1928.** Factor the quadratic: `□ + m² = (iγ·∂ − m)(iγ·∂ + m)`. The factorisation
exists only if `{γ_μ, γ_ν} = 2η_μν`, and the Clifford algebra then forces 4×4 matrices.
**The dimension is an output, not an input.** Dirac got 4.

**E₄₇.** Factor the quadratic in the Casimir: `K = (C − 6I)(C − 30I)`, with the roots
forced at μ ∓ σ. The multiplicities 5 and 2 then force `dim ker K = 5·5 + 2·11 = 47`.
**The dimension is an output.** This gets 47.

That is one move performed twice, a century apart, and it is a stronger claim than any
row of the comparison plates. It deserves its own plate; the comparison format does it
no favours, because a side-by-side invites the reader to grade the right column against
the left rather than to see that the *method* is shared.

## Recommendation

Retire the comparison plates or fix the left column. Keep The Invariant Grammar and the
Lineage plate. Promote the μ ± σ result and the Dirac factorisation parallel, which are
the two places where something is genuinely forced rather than asserted.
