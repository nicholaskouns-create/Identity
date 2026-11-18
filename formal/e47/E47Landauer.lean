/-
  E47Landauer.lean — the thermodynamic cost of projecting onto E47.

  Self-contained: core Lean 4 only, no Mathlib, no declared axioms, no sorry,
  no native_decide.  Every proof is `decide` or `rfl`.

  Claim being certified:
      S(I/125) - S(P/47) = ln(125/47) = -ln Omega_c = 1.4111954... bits

  Lean core has no reals, so the transcendental value is certified the honest
  way: by exact integer inequalities that bracket it.  For positive p, q,

      log2(125/47) > p/q   <->   47^q * 2^p < 125^q
      log2(125/47) < p/q   <->   125^q < 47^q * 2^p

  because log2(125/47) > p/q  <->  (125/47)^q > 2^p, and both sides are
  positive rationals cleared by multiplying through by 47^q.
-/

namespace E47Landauer

/-! ### 1.  The carrier and the kernel -/

def carrier  : Nat := 125          -- dim (V2 ⊗ V2 ⊗ V2)
def kernel   : Nat := 47           -- dim ker (C - 6I)(C - 30I)
def discarded: Nat := 78           -- the contracted complement

theorem rank_nullity : kernel + discarded = carrier := by decide

/-- `Omega_c = 47/125 = 0.376` exactly, cleared of denominators. -/
theorem omega_c_exact : kernel * 1000 = 376 * carrier := by decide

/-- The compression ratio whose logarithm is the entropy drop. -/
theorem compression_ratio : carrier = 125 ∧ kernel = 47 := by decide

/-! ### 2.  The entropy drop, bracketed to two decimal places

`DeltaS = ln(125/47)` nats `= log2(125/47)` bits.  The two certificates below
pin that number into the interval `(1.41, 1.42)`. -/

/-- `log2(125/47) > 141/100`, i.e. the cost exceeds 1.41 bits. -/
theorem cost_gt_141 : 47^100 * 2^141 < 125^100 := by decide

/-- `log2(125/47) < 142/100`, i.e. the cost is under 1.42 bits. -/
theorem cost_lt_142 : 125^100 < 47^100 * 2^142 := by decide

/-- Together: the erasure cost of enforcing E47 is strictly between
    1.41 and 1.42 bits. -/
theorem cost_in_bits : 47^100 * 2^141 < 125^100 ∧ 125^100 < 47^100 * 2^142 :=
  ⟨cost_gt_141, cost_lt_142⟩

/-- A coarser bracket, cheap to check by hand: between 1.4 and 1.5 bits. -/
theorem cost_coarse : 47^10 * 2^14 < 125^10 ∧ 125^10 < 47^10 * 2^15 := by decide

/-! ### 3.  The cost sees the ratio and nothing else

Doubling both carrier and kernel leaves every bracket unchanged.  The gap
`gamma = 11664`, the 78 discarded dimensions and the spectrum of `K` never
enter.  This is the content of "thermodynamics prices only `Omega_c`". -/

theorem scale_invariant_gt : 94^100 * 2^141 < 250^100 := by decide
theorem scale_invariant_lt : 250^100 < 94^100 * 2^142 := by decide

/-- The discarded count is not the cost.  78 dimensions are thrown away, yet
    the price is under 2 bits — the logarithm of a ratio, not a tally. -/
theorem cost_is_not_the_tally : 125^1 < 47^1 * 2^2 := by decide

/-! ### 4.  What is NOT claimed here

  * No real-number arithmetic: Lean core has none, so `ln` and `log2` appear
    only in comments, bracketed by the integer certificates above.
  * No physics.  The Landauer inequality `Q >= kT * DeltaS` is a theorem of
    statistical mechanics (Landauer 1961; Reeb & Wolf 2014), not of this file.
    This file certifies the combinatorial factor `DeltaS` only.
  * The bound presumes a deterministic reset from the maximally mixed state
    on the carrier to the maximally mixed state on the kernel. -/

end E47Landauer
