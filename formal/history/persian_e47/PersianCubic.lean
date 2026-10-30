/- Modern comparison; not a transcription of al-Tusi's algorithm. -/
import Mathlib
namespace PersianCubic
def f (a c x : ℝ) : ℝ := x^3 - a*x^2 + c
def step (a c ω x : ℝ) : ℝ := x + ω * f a c x
theorem critical_value (a c : ℝ) : f a c (2*a/3) = c - 4*a^3/27 := by unfold f; ring
theorem critical_factor (a c x : ℝ) : f a c x - f a c (2*a/3) = (x-2*a/3)^2*(x+a/3) := by unfold f; ring
theorem fixed_root (a c ω r : ℝ) (hr : f a c r = 0) : step a c ω r = r := by simp [step, hr]
theorem error_identity (a c ω r e : ℝ) (hr : f a c r = 0) :
    step a c ω (r+e) - r =
      (1-ω*r*(2*a-3*r))*e + ω*(3*r-a)*e^2 + ω*e^3 := by
  unfold step f at *
  rw [show c = a*r^2-r^3 by nlinarith [hr]]
  ring
end PersianCubic
