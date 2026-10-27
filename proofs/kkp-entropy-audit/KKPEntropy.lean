import Mathlib

namespace KKPEntropy

theorem ratio_exact : (47 : ℚ) / 125 = 47 / 125 := by norm_num

theorem ratio_decimal : (47 : ℚ) / 125 = 376 / 1000 := by norm_num

def gl (alpha beta x : ℚ) : ℚ := alpha * x + beta * x^2

theorem gl_stationary_example_a : gl (-752/1000) 1 (376/1000) = -(376/1000)^2 := by
  norm_num [gl]

theorem gl_stationary_example_b : gl (-4/10) 1 (2/10) = -(2/10)^2 := by
  norm_num [gl]

theorem gl_different_minima : (376/1000 : ℚ) ≠ 2/10 := by norm_num

end KKPEntropy
