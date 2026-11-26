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

## Two hypotheses formed while building this, both discarded

Neither of the following was a claim of the corpus. Both were guesses made by the author of
this file during the derivation, written down here so they are not guessed again.

**Guess 1: that the signature would turn at Ω_c.** It does not. Over 120 random mixing
directions the turn happens between **0.509 and 0.701**, median 0.607, standard deviation
0.042 — direction-dependent, so not a constant at all, and `0.376` lies outside the entire
observed range.

This says nothing about `Ω_c = 47/125` itself, which is untouched. `dim ker K = 47`,
`125 − 47 = 78` and `Ω_c = 0.376` are all reconfirmed at the top of the validator. Ω_c is a
kernel fraction and remains exactly that. The only thing refuted is the extra role this file
briefly supposed for it.

**Guess 2: that states inside `E₄₇` would carry ordinary spacetime.** They do not. A state
lying wholly inside `E₄₇` gives signature `(3,0)`
in every draw: `A` annihilates it, so the time leg vanishes. Lorentzian geometry exists
strictly *between* the two ends — it needs weight off the kernel to have a time direction
and enough weight on it to have space. The attractor of the flow is therefore a degenerate
three-metric, and spacetime is a **transient** of the recursion, not its limit.

That is a derived structural fact about the construction in this file, not a revision of
anything in the corpus.

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

---

# Addendum: can Einstein's equations be derived here? No, and here is the obstruction

**Attribution, since the body above learned this lesson:** everything in this addendum is a
test of the construction built *in this file*. Nothing here tests, revises or bears on the
E₄₇ formalism. `Ω_c = 47/125`, `dim ker K = 47` and the spectral facts of §0 are untouched.

## The question has to be posed correctly

`G_μν + Λg_μν = (8πG/c⁴) T_μν` cannot be *derived* from a metric. For any `g` whatever,
define `T_μν ≔ (c⁴/8πG)(G_μν + Λg_μν)` and the equation holds identically. That is a
definition dressed as a result.

The decidable question is instead: **does the flowed geometry satisfy the field equations
with a source that is physically admissible?** That has an answer, and the answer is no.

## What the computation returns

With `G = c = 1`, at the base point:

    R = −37.3238
    best-fit Λ = R/4 = −9.3309
    ‖Ric − Λg‖ / ‖Ric‖ = 1.5907          →  NOT an Einstein manifold

So `Λ` is not produced by the construction. `R_μν ∝ g_μν` fails by more than its own size.

Reading `T_(ab) = G_(ab)/8π` in an orthonormal frame (tetrad verified to 6.6×10⁻¹⁶):

    energy density       ρ   = +0.166011
    principal pressures  p_i = (0.401595, 0.539984, 0.709496)
    anisotropy                 23%  — three distinct pressures, not one
    shear / heat flux          1.31×10⁻¹, nonzero
    equation of state    w     = +3.3152

    weak      ρ ≥ 0                 ✓
    null      ρ + p_i ≥ 0           ✓
    strong    ρ + Σp_i ≥ 0          ✓
    dominant  ρ ≥ |p_i|             ✗

`w = 3.32` puts the sound speed above `c`, the pressures are anisotropic with shear, and the
dominant energy condition fails. This is not matter.

The Bianchi check `‖∇_a G^a_b‖/‖G‖ = 9.6×10⁻⁵` is a measurement of finite-difference error,
not of physics — the identity holds exactly in exact arithmetic.

## Why it fails, stated as a reason rather than a disappointment

The coframe of §3 is **kinematic**. It is a pullback along a group orbit, and a pullback
carries no dynamics. Einstein's equations are not a property a metric can have on its own;
they are the Euler–Lagrange equations of an action. Nothing in `exp(−x⁰ε*A)·exp(ix^k J_k)`
says how geometry should respond to matter, so there is no reason for the resulting `g` to
satisfy a field equation, and it does not.

This is bridge 3 of the 22 November note, quoted exactly:

> Derive a covariant action and its coupling from microscopic state weights rather than
> inserting Einstein-Hilbert dynamics as a chosen effective action.

That bridge is not crossable by the route in this file, and the computation above is the
demonstration rather than an assertion. Getting the dynamics requires an action built from
the microscopic weights — a different construction, not a further step in this one.

## What the addendum settles

- Bridge 1 (the coframe) — closed by the body of this note.
- Bridge 3 (the action) — shown here to be **not** reachable kinematically.
- Bridges 2, 4, 5 — untouched and open.
