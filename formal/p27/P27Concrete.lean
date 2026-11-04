import Mathlib
namespace P27Concrete
def p (i : Fin 64) : ℤ := if i.val < 26 then 1 else 0
def e (i : Fin 64) : ℤ := if i.val = 26 then 1 else 0
def p27 (i : Fin 64) : ℤ := p i + e i
def q27 (i : Fin 64) : ℤ := 1 - p27 i
theorem p27_boolean (i : Fin 64) : p27 i = 0 ∨ p27 i = 1 := by
  unfold p27 p e
  split_ifs <;> omega
theorem p27_idempotent (i : Fin 64) : p27 i * p27 i = p27 i := by
  rcases p27_boolean i with h | h <;> simp [h]
theorem q27_idempotent (i : Fin 64) : q27 i * q27 i = q27 i := by
  rcases p27_boolean i with h | h <;> simp [q27, h]
theorem p27_orthogonal (i : Fin 64) : p27 i * q27 i = 0 := by
  rcases p27_boolean i with h | h <;> simp [q27, h]
theorem halmos_involution (i : Fin 64) (x y : ℤ) :
  p27 i * (p27 i * x + q27 i * y) +
    q27 i * (q27 i * x - p27 i * y) = x ∧
  q27 i * (p27 i * x + q27 i * y) -
    p27 i * (q27 i * x - p27 i * y) = y := by
  rcases p27_boolean i with h | h <;>
    simp [q27, h] <;> constructor <;> ring
theorem contraction_denominator : (2 : ℕ)^40 = 1099511627776 := by norm_num
end P27Concrete
