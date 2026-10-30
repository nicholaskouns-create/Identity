import Mathlib
namespace E47Richardson
def eps : ℚ := 1 / 99144
def k2 : Fin 7 → ℚ := ![32400, 12544, 0, 11664, 19600, 0, 186624]
def multiplier (j : Fin 7) : ℚ := 1 - eps * k2 j
theorem step_minimax : eps = 2 / (11664 + 186624 : ℚ) := by norm_num [eps]
theorem stability_window : 0 < eps ∧ eps < (2 / 186624 : ℚ) := by norm_num [eps]
theorem slow_sector : multiplier 3 = 15 / 17 := by norm_num [multiplier, eps, k2]
theorem fast_sector : multiplier 6 = -(15 / 17) := by norm_num [multiplier, eps, k2]
theorem retained_two : multiplier 2 = 1 := by norm_num [multiplier, eps, k2]
theorem retained_five : multiplier 5 = 1 := by norm_num [multiplier, eps, k2]
theorem normalized_identity (k : ℚ) :
    1 - eps * k^2 = 1 - (32/17 : ℚ) * (k/432)^2 := by
  dsimp [eps]
  ring
/-! The five nonretained Casimir sectors, enumerated from k2.
    This finite bound does not itself identify the concrete Casimir spectrum. -/
theorem complement_envelope :
    |multiplier 0| ≤ (15 / 17 : ℚ) ∧
    |multiplier 1| ≤ (15 / 17 : ℚ) ∧
    |multiplier 3| ≤ (15 / 17 : ℚ) ∧
    |multiplier 4| ≤ (15 / 17 : ℚ) ∧
    |multiplier 6| ≤ (15 / 17 : ℚ) := by
  norm_num [multiplier, eps, k2]

theorem complement_bound_attained :
    |multiplier 3| = (15 / 17 : ℚ) ∧
    |multiplier 6| = (15 / 17 : ℚ) := by
  norm_num [multiplier, eps, k2]

end E47Richardson
