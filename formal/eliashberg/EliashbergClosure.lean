import Mathlib

namespace EliashbergClosure
variable (lambda omega : ℝ)

def spectralWeight : ℝ := lambda * omega / 2

theorem coupling_closure (hω : omega ≠ 0) :
    2 * spectralWeight lambda omega / omega = lambda := by
  unfold spectralWeight
  field_simp
  ring

theorem logarithmic_moment (hλ : lambda ≠ 0) (hω : 0 < omega) :
    Real.exp ((2 / lambda) * spectralWeight lambda omega *
      Real.log omega / omega) = omega := by
  have hw : omega ≠ 0 := ne_of_gt hω
  have h : (2 / lambda) * spectralWeight lambda omega / omega = 1 := by
    unfold spectralWeight
    field_simp
    ring
  rw [← mul_div_assoc] at h
  have heq : (2 / lambda) * spectralWeight lambda omega * Real.log omega / omega = Real.log omega := by
    rw [mul_div_assoc, h, one_mul]
  rw [heq, Real.exp_log hω]

theorem second_moment (hλ : lambda ≠ 0) :
    (2 / lambda) * spectralWeight lambda omega * omega = omega ^ 2 := by
  unfold spectralWeight
  field_simp
  ring
end EliashbergClosure
