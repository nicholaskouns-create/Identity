/-
  E47 spectral certificate — corrected arithmetic core.
  Core Lean 4. No Mathlib. No `native_decide`. No axioms.

  CORRECTION to the prior version: the contraction constants were stated as
  rational identities and closed with `norm_num`, which is a MATHLIB tactic —
  the file did not compile as "core Lean", and the failed elaboration still
  emitted theorems depending on `sorryAx`.  `decide` does not rescue them
  either: the kernel cannot reduce `Rat.inv` through `OfNat` literals.

  A rational identity IS a cross-multiplication identity.  Stated that way the
  claims are decidable in the kernel and carry no axioms.
-/

/-! ### L1, L2, L4 — dimension residues -/
theorem carrier_dim    : 5 ^ 3 = (125 : Nat)                        := by decide
theorem isotypic_sum   : 1*1 + 3*3 + 5*5 + 4*7 + 3*9 + 2*11 + 1*13
                       = (125 : Nat)                                := by decide
theorem kernel_dim     : 5*5 + 2*11 = (47 : Nat)                    := by decide
theorem rank_nullity   : 47 + 78 = (125 : Nat)                      := by decide
theorem occupancy_num  : 47 * 1 = (47 : Nat)                        := by decide

/-! ### L5 — commutant of the collective action on the kernel -/
theorem commutant_dim  : 5*5 + 2*2 = (29 : Nat)                     := by decide
/-- The permutation group is far from exhausting it: `|S₃| = 6 < 29`. -/
theorem s3_too_small   : 6 < (29 : Nat)                             := by decide

/-! ### L3 — optimal contraction.  λ_min = 11664, λ_max = 186624 on ker(K)ᗮ. -/
theorem kappa_sixteen    : 186624 = 16 * (11664 : Nat)              := by decide
/-- ε* = 2/(λ_min + λ_max) = 1/99144, as a cross-multiplication. -/
theorem contraction_star : 2 * 99144 = 1 * (11664 + 186624 : Nat)   := by decide
/-- ρ* = (λ_max − λ_min)/(λ_max + λ_min) = 15/17, as a cross-multiplication. -/
theorem contraction_rho  : (186624 - 11664) * 17
                         = 15 * (186624 + 11664 : Nat)              := by decide
/-- ρ* = (κ − 1)/(κ + 1) with κ = 16. -/
theorem rho_from_kappa   : (16 - 1) * 17 = 15 * (16 + 1 : Nat)      := by decide

/-! ### R6 — the four-fold carrier.  m₂ = 16, m₅ = 10. -/
theorem four_fold_dim    : 5 ^ 4 = (625 : Nat)                      := by decide
theorem four_fold_kernel : 16*5 + 10*11 = (190 : Nat)               := by decide
theorem not_one_eight_seven : (190 : Nat) ≠ 187                     := by decide

#print axioms carrier_dim
#print axioms isotypic_sum
#print axioms kernel_dim
#print axioms rank_nullity
#print axioms commutant_dim
#print axioms s3_too_small
#print axioms kappa_sixteen
#print axioms contraction_star
#print axioms contraction_rho
#print axioms rho_from_kappa
#print axioms four_fold_dim
#print axioms four_fold_kernel
#print axioms not_one_eight_seven
