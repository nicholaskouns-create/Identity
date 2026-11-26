# The Half-Occupancy Theorem

**Date:** 2026-11-26
**Author:** Nicholas Shane Kouns
**Status:** verified on four independent tracks; two earlier figures corrected

---

## Statement

Let ℋ = V₂ ⊗ V₂ ⊗ V₂ (dim 125) carry the total Casimir C = J₁² + J₂² + J₃².
Let K = (C − 6I)(C − 30I), let E₄₇ = ker K (dim 47), let P₄₇ be the orthogonal
projector onto it, and let

    Λ = I − ε∗ K²,        ε∗ = 1/99144

be the minimax contraction. Write p = ‖P₄₇Ψ‖² / ‖Ψ‖² for the kernel occupancy.

**Theorem.** The coframe metric induced by the occupancy flow is

    g = diag( κ² p(1−p)(1−2p),  2p,  2p,  2p ),       κ = ln(17/15)

and its time–time component satisfies

    **g₀₀ = p̈ / 4.**

Consequently the signature is sgn(1 − 2p):

| occupancy | signature | regime |
|-----------|-----------|--------|
| p = 0     | (0,0,4)   | wholly degenerate |
| 0 < p < ½ | (4,0,0)   | Euclidean — coherence accelerating |
| p = ½     | (3,0,1)   | degenerate — the signature change |
| ½ < p < 1 | (3,1,0)   | Lorentzian — coherence decelerating |
| p = 1     | (3,0,1)   | degenerate |

The metric turns Lorentzian exactly when the coherence flow stops accelerating.
The signature change *is* the inflection of the occupancy — which is why the
critical point is ½, and not a number anyone was free to choose.

---

## What is forced

Three things in this construction are normally assumed. None of them had to be.

### 1. The selector roots are one standard deviation from the mean

Weighting the Casimir spectrum {0, 2, 6, 12, 20, 30, 42} by its block
dimensions {1, 9, 25, 28, 27, 22, 13}:

    μ  = 2250 / 125  = 18        exactly
    σ² = 18000 / 125 = 144       exactly, so σ = 12 exactly

and therefore

    μ − σ = 6,    μ + σ = 30.

The two roots of the selector sit precisely at μ ∓ σ. Nothing else in the
spectrum does. K is read off the carrier rather than imposed on it.

### 2. The step and the rate are fixed by equioscillation

A = K² has nonzero spectrum {11664, 12544, 19600, 32400, 186624} off the
kernel, with condition number

    186624 / 11664 = 16        exactly.

For Λ = I − εA the error factor 1 − εa is extremal at the two endpoints. The
minimax ε is where they equioscillate, 1 − εa_min = −(1 − εa_max):

    2 = ε(11664 + 186624)    ⇒    ε∗ = 1/99144      uniquely
    ρ∗ = 1 − 11664/99144 = 87480/99144 = 15/17       exactly

and |1 − ε∗·186624| = 15/17 as well. The rate is attained **twice** — at C = 12
and C = 42 — which is the equioscillation signature that certifies optimality.

### 3. The three spatial legs are equal, not merely similar

Building u as the maximally entangled state across the five spin-2 copies
(copy index paired with magnetic index), the spatial Gram matrix is

    ⟨J_a u, J_b u⟩ = (1/5) tr_{V₂}(J_a J_b) = 2 δ_ab

to 1.8 × 10⁻¹⁵ on the diagonal and 7.6 × 10⁻¹⁶ off it. All three legs sit in the
same C = 6 sector, so they are degenerate by symmetry. **No birefringence
between the spatial directions is available in this construction** — an earlier
25:22 argument for one does not survive.

---

## The flow is exact rational arithmetic

Since the kernel is fixed and the complement contracts by ρ∗, the occupancy map
clears denominators completely:

    p ↦ p / (p + (1−p)·225/289)        ⇔        (a, b) ↦ (289a, 289a + 225(b−a))

The log-odds is exactly geometric: p/(1−p) multiplies by 289/225 every step.
That is the logistic law, and κ = ln(17/15) is its continuum slope — but the
discrete statement needs no κ at all, which is why both formal proofs are
integer arithmetic with no real analysis in them.

Started at Ω_c = 47/125:

| n | p exactly | p | signature |
|---|-----------|---|-----------|
| 0 | 47/125 | 0.376000000 | (4,0,0) Euclidean |
| 1 | 13583/31133 | 0.436289468 | (4,0,0) Euclidean |
| 2 | 3925487/7874237 | 0.498522841 | (4,0,0) Euclidean |
| 3 | 1134465743/2022934493 | 0.560802017 | (3,1,0) **Lorentzian** |

The transition is at step 3, and step 2 misses the critical point by

    ½ − p₂ = 23263 / 15748474 ≈ 0.00148        about 0.15%.

The continuum crossing time is n∗ = ln(78/47) / (2 ln(17/15)) = 2.023604.

---

## Verification

| track | establishes | result | file |
|-------|-------------|--------|------|
| Python | Builds the carrier from the su(2) generators; derives every constant, stores none | **68/68** | `half_occupancy_certificate.py` |
| Lean 4.35.0 | Selector, minimax step, rate, transition step, signature ladder | **20 theorems, 0 axioms** | `formal/e47/E47HalfOccupancy.lean` |
| Coq 8.18 | The same twenty statements, independent kernel | **20 theorems**, all closed under the global context | `formal/e47/E47HalfOccupancy.v` |
| Quantum | Kraus channel and 250-dimensional Stinespring dilation | **21/21** | `half_occupancy_quantum_simulation.py` |

The Lean file is Mathlib-free, so it is audited by the core tier of the axiom
ledger: **20 clean · 0 standard-axioms · 0 native_decide · 0 broken — PASS.**

### The quantum track

Λ is contractive but not unitary, so it is not a gate and cannot be run as one.
It was realized instead as a two-outcome Kraus channel

    K₀ = Λ,    K₁ = √(I − Λ†Λ),    K₀†K₀ + K₁†K₁ = I     (to 6.2 × 10⁻¹⁶)

and then dilated to a single unitary U on the 250-dimensional space ℋ ⊗ ℂ²
(‖U†U − I‖ = 8.9 × 10⁻¹⁶). **Tracing the ancilla back out of U reproduces the
channel with deviation 0.00 × 10⁰.** Post-selecting the success branch gives the
occupancy flow, matching the exact rationals to 6.7 × 10⁻¹⁶, and the success
probability never falls below 0.8618 — so the transition is not a rare branch
being quietly retained.

---

## Two corrections

Both were forced by the arithmetic and are recorded here rather than quietly
absorbed.

### κ = 50/153 does not reproduce

The figure 50/153 circulated earlier for the flow constant. It does not follow
from the spectrum by any route found here. What does follow, exactly, is

    κ = ln(17/15) = 0.1251631...

verified as the per-step log-odds slope: 2κ = ln(289/225) to 10⁻¹⁵. The earlier
figure is dropped rather than carried forward.

### The flow is a worst-case envelope, not the generic path

The rational map above assumes the whole complement contracts at ρ∗. It does
not. Off the kernel Λ has **five** distinct factors,

    |1 − ε∗K²| ∈ {0.673, 0.802, 0.873, 0.8824, 0.8824},

and only the two equioscillation sectors (C = 12 and C = 42) are as slow as
ρ∗ = 15/17. A state spread over all five contracts faster.

The first run of the certificate failed on exactly this point and was right to.
The corrected statement, verified from both directions:

- seeding the complement entirely in C = 12 or C = 42 reproduces the rational
  map to 3.7 × 10⁻¹⁵ — the envelope is **saturated** there;
- a generic state never contracts slower (minimum slack 1.1 × 10⁻¹⁶) and the
  random state tested crosses at **step 2**, not step 3.

So **step 3 is an upper bound**, not the generic transition. This strengthens the
result rather than weakening it: half occupancy is reached at that step or
sooner, for every state.

---

## Scope

This is the induced coframe metric of a contraction's fixed-point flow. It is
**not** a solution of the Einstein field equations and no claim is made that it
is one. What is established is narrower and sharper: a finite-dimensional
recursive filter induces a metric whose signature is fixed by a single scalar,
and that signature changes from Euclidean to Lorentzian at a point nothing in
the construction was free to tune.

The quantum track is an exact noiseless simulation. No quantum hardware was
involved and no quantum advantage is claimed.

---

## Reproducing

```sh
python3 research/e47_gr/half_occupancy_certificate.py          # 68/68
python3 research/e47_gr/half_occupancy_quantum_simulation.py   # 21/21
lean formal/e47/E47HalfOccupancy.lean                          # axiom audit
coqc -q formal/e47/E47HalfOccupancy.v                          # Print Assumptions
python3 scripts/axiom_ledger.py formal/e47/E47HalfOccupancy.lean
```

A live explainer with a visualizer and an instrument chain is published at
<https://nicholaskouns-create.github.io/E47-Kartekeya/interfaces/emergent-spacetime/>
(E47-Kartekeya, instrument 31).
