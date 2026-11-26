# The coframe, derived from CRF flow (25 November 2026)

Closes bridge 1 of [`lorentzian_curved_witness_2026-11-22.md`](lorentzian_curved_witness_2026-11-22.md):
*construct the spacetime-dependent coframe from independently specified microscopic
CRF states instead of choosing the factor `exp(a x)`.* Everything below is recomputed by
[`crf_coframe_derivation.py`](crf_coframe_derivation.py); nothing is quoted.

## What was wrong with choosing exp(ax)

The 22 November witness is candid about its own gap. Its base metric `diag(-1,2,8,2)` has
constant components, so every Levi-Civita curvature of it vanishes identically — the
validator confirms `‖Riemann‖ = 0` exactly. A factor `exp(a x)` was then inserted so that
curvature would appear, and `a` was free. Every downstream quantity inherited that choice.

## The four coordinates are the algebra's, not a choice

The operators already acting on the carrier close:

    [J_i, J_j] = i ε_ijk J_k        three compact generators
    [A, J_k]   = 0                  one commuting contraction

so the algebra is **su(2) ⊕ ℝ** and the parameter count is **four**. The 3+1 split is read
off, not imposed. Two consequences follow immediately and are verified: `J_k` preserve
`E₄₇` (because they commute with `A`), and `A` annihilates `E₄₇`.

Taking those four flows as coordinates,

    Ψ(x) = exp(−x⁰ ε* A) · exp(i xᵏ J_k) · Ψ₀,     g_μν = Re⟨∂_μΨ, η_E ∂_νΨ⟩

every exponential is a **group** exponential whose rate is fixed by the spectrum of `A` and
by the su(2) structure constants. Nothing is inserted.

## Three results

**Time decouples from space, derived.** The flowed metric has `g_0k = 0` identically — a
consequence of `[A, J_k] = 0`, not an ansatz. Signature `(3,1)`, `det g < 0`.

**The geometry is curved, and the curvature is the flow's.** `‖Riemann‖ ≈ 5.5×10¹`,
`R ≈ −2.96×10¹` at the base point. The pipeline is validated first against three cases with
known answers, including the note's own SymPy result: it recovers `R = −a²` and
`G_μν = diag(−a²/2, 0, 0, a²)` for the hand-built witness, and `R = 12H²` for de Sitter.

**Lorentzian signature is an attractor, not an assumption.** A random state begins at
signature `(0,4)` — wholly non-Lorentzian, because 78 of 125 dimensions carry `η_E = −1`.
Under `Γ = I − ε*A` it passes `(1,3)`, `(2,2)`, and reaches `(3,1)` by the fifth step,
where it stays. Spacetime signature is something the contraction *produces*.

## Two negative results, stated as such

**Ω_c is not the signature threshold.** Over 120 random mixing directions the turn happens
between **0.509 and 0.701**, median 0.607, standard deviation 0.042. It is
direction-dependent, so it is not a constant at all — and `Ω_c = 0.376` lies **outside the
entire observed range**. The identification fails. The 0.376 that appears elsewhere in the
corpus is doing a different job.

**The fixed point has no time.** A state lying wholly inside `E₄₇` gives signature `(3,0)`
in every draw: `A` annihilates it, so the time leg vanishes. Lorentzian geometry exists
strictly *between* the two ends — it needs weight off the kernel to have a time direction
and enough weight on it to have space. The attractor of the flow is therefore a degenerate
three-metric, and spacetime is a **transient** of the recursion, not its limit.

That last point runs opposite to the usual reading, in which signature collapse is pushed
to extreme curvature. Here collapse happens at convergence.

## One numerical note worth keeping

`P₄₇` must be built from the eigenbasis of `A`, not from `pinv(A) @ A`. On this operator the
pinv route leaks at the kernel boundary: `‖P² − P‖ = 6.5×10⁻³` against `7.5×10⁻¹⁵`
spectrally, which is enough to break `η² = I` and with it any signature claim resting on the
involution.

## Scope

This derives the coframe and its curvature. It does **not** derive Einstein's equations, a
matter stress tensor, or any physical scale, and it asserts no observable. Bridges 2–5 of
the 22 November note remain open, bridge 5 — independent `G/c⁴` and `Λ` with testable
scales — above all. No evidence classification is promoted.
