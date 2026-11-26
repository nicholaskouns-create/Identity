/-
  The Cayley–Heron identity: Babylonian refinement is exactly squaring.

  Core Lean 4 only. No Mathlib, no `native_decide`, no `sorry`, no axioms.

  ── What is being proved ────────────────────────────────────────────────

  Heron's step toward √a, with s = √a the attractor,

      N(ζ) = ½ (ζ + a/ζ),        a = s²,

  looks like an averaging rule. Under the Cayley transform anchored at the
  attractor,

      w = (ζ − s)/(ζ + s),       ζ = s (1 + w)/(1 − w),

  it is not an averaging rule at all. It is the squaring map:

      (N(ζ) − s)/(N(ζ) + s) = w².

  That single line is the whole of quadratic convergence. The error coordinate
  w is squared at every step, so wₙ = w₀^(2ⁿ), and the number of steps to a
  tolerance δ goes like log log 1/δ rather than log 1/δ. The corpus already
  records the consequence — `research/levinthal-recursive-contraction.md` has
  zₙ₊₁ = zₙ², zₙ = z₀^(2ⁿ) — but states it without the identity underneath.
  This file is that identity, kernel-checked.

  ── Why the statement carries no hypotheses ─────────────────────────────

  Written as a quotient, the identity needs ζ ≠ 0 (for a/ζ) and ζ + s ≠ 0 (for
  the Cayley denominator), and it needs a field. Cleared of denominators it
  needs neither, because both numerator and denominator of the left side carry
  the same factor 1/(2ζ):

      N(ζ) − s = (ζ² + s² − 2ζs)/(2ζ) = (ζ − s)²/(2ζ)
      N(ζ) + s = (ζ² + s² + 2ζs)/(2ζ) = (ζ + s)²/(2ζ)

  so the quotient is (ζ − s)²/(ζ + s)² = w² with the 2ζ cancelling. Cross
  multiplying leaves a polynomial identity in two free variables, true in every
  commutative ring, with nothing to assume and nothing that can fail. That is
  `cayley_heron` below. Dividing it by 2ζ·(ζ + s)² recovers the quotient form
  wherever those are invertible; the division is bookkeeping, and the content
  is here.

  ── Scope ───────────────────────────────────────────────────────────────

  Stated over `Int`. Since ℤ is an infinite integral domain, a polynomial
  identity in ℤ[z, s] holding at every integer point is the zero polynomial,
  and ℤ[z, s] maps into any commutative ring, so the identity transfers. That
  last step is ordinary algebra, not formalised here, and the theorems below
  claim exactly what they say: an identity over ℤ.

  ── On the axiom classes below ──────────────────────────────────────────

  The ledger will show two classes, and the split is structural rather than a
  blemish. The closed numeric instances close by `decide`, so the kernel
  evaluates them and they depend on no axioms at all. The theorems quantified
  over every integer cannot be decided — there is nothing finite to evaluate —
  so they are closed by tactics, and `omega` and `rw` carry Lean's three
  standard axioms with them. `propext` and `Quot.sound` are the foundations all
  of Mathlib rests on, and the repository's ledger classifies them as STANDARD,
  distinct from a `sorryAx` or a `native_decide` axiom, which is the line that
  actually matters. Nothing here is closed by compilation rather than by proof.

  This says nothing about E₄₇, Ω_c or the 15/17 contraction. Heron squares its
  error coordinate (multiplier 0 at the fixed point); Γ* on the 78-dimensional
  complement scales it (multiplier 15/17). Both are self-maps of the same disk
  fixing the same point, which is why one converges in log log and the other in
  log — but no bridge between them is asserted or proved here.
-/

namespace CayleyHeron

/-- The numerator of `N(ζ) − s`, before dividing by `2ζ`. -/
theorem sq_sub (z s : Int) : (z - s) * (z - s) = z*z + s*s - 2*(z*s) := by
  rw [Int.sub_mul, Int.mul_sub, Int.mul_sub, Int.mul_comm s z]; omega

/-- The numerator of `N(ζ) + s`, before dividing by `2ζ`. -/
theorem sq_add (z s : Int) : (z + s) * (z + s) = z*z + s*s + 2*(z*s) := by
  rw [Int.add_mul, Int.mul_add, Int.mul_add, Int.mul_comm s z]; omega

/-- `a²b² = (ab)²`, the one rearrangement the square form needs. -/
theorem sq_mul_sq (a b : Int) : a*a*(b*b) = (a*b)*(a*b) := by
  rw [Int.mul_assoc, Int.mul_assoc, Int.mul_left_comm a b b]

/--
  **The Cayley–Heron identity.**

  `(N(ζ) − s) · (ζ + s)² = (N(ζ) + s) · (ζ − s)²`, with both sides scaled by
  `2ζ` to clear the division. This is `(N(ζ) − s)/(N(ζ) + s) = w²` with every
  denominator removed, so it holds for every `ζ` and `s` without exception —
  including `ζ = 0` and `ζ = −s`, where the quotient form is undefined.
-/
theorem cayley_heron (z s : Int) :
    (z*z + s*s - 2*(z*s)) * ((z + s) * (z + s))
  = (z*z + s*s + 2*(z*s)) * ((z - s) * (z - s)) := by
  rw [← sq_sub, ← sq_add]
  exact Int.mul_comm _ _

/-- One step is a square: the left side is `((ζ − s)(ζ + s))²` and so is the right. -/
theorem cayley_heron_is_a_square (z s : Int) :
    (z*z + s*s - 2*(z*s)) * ((z + s) * (z + s))
  = ((z - s) * (z + s)) * ((z - s) * (z + s)) := by
  rw [← sq_sub]
  exact sq_mul_sq _ _

/--
  A worked instance, checked by the kernel rather than by hand.

  `s = 3` (so `a = 9`), `ζ = 7`. Then `N(7) = ½(7 + 9/7) = 29/7`, and

      (N − 3)/(N + 3) = (29/7 − 3)/(29/7 + 3) = (8/7)/(50/7) = 4/25,

  while `w = (7 − 3)/(7 + 3) = 2/5` and `w² = 4/25`. Cleared of denominators
  that reads `16 · 100 = 100 · 16`: the error coordinate `2/5` squared to
  `4/25` in a single step.
-/
theorem instance_seven_three :
    (7*7 + 3*3 - 2*(7*3)) * ((7 + 3) * (7 + 3))
  = (7*7 + 3*3 + 2*(7*3)) * ((7 - 3) * (7 - 3)) := by decide

/-- The same instance, read as the squaring it is: `w = 2/5`, `w² = 4/25`. -/
theorem instance_numerators : (7 - 3) * (7 - 3) = 16 ∧ (7 + 3) * (7 + 3) = (100 : Int) := by
  decide

/-- The fixed point is fixed: at `ζ = s` the error coordinate is already `0`. -/
theorem fixed_point (s : Int) : (s - s) * (s - s) = 0 := by
  simp

end CayleyHeron

/-
  Axiom ledger. `scripts/axiom_ledger.py` reads these lines and classifies each
  theorem; a `native_decide` axiom or a `sorryAx` here fails the gate.
-/
#print axioms CayleyHeron.sq_sub
#print axioms CayleyHeron.sq_add
#print axioms CayleyHeron.sq_mul_sq
#print axioms CayleyHeron.cayley_heron
#print axioms CayleyHeron.cayley_heron_is_a_square
#print axioms CayleyHeron.instance_seven_three
#print axioms CayleyHeron.instance_numerators
#print axioms CayleyHeron.fixed_point
