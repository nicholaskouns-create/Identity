/- Exact Jacobi rationalization, arbitrary dimension.
   Pure Lean 4, no Mathlib, no axioms or sorry.
   The square-root data are represented by rᵢ with rᵢ*rᵢ=cᵢ.
   These theorems prove the four entry classes of S⁻¹ B S.
-/
namespace E47Jacobi
theorem upper_entry (s t r c : Rat)
    (ht : t * s = 1) (hr : r * r = c) :
    t * r * (s * r) = c := by
  calc
    t * r * (s * r) = (t * s) * (r * r) := by
      simp only [mul_assoc, mul_left_comm, mul_comm]
    _ = c := by rw [ht, hr]; simp

theorem lower_entry (sNext tNext s r : Rat)
    (hs : sNext = s * r) (ht : tNext * sNext = 1) :
    tNext * r * s = 1 := by
  calc
    tNext * r * s = tNext * sNext := by
      rw [hs]
      simp only [mul_assoc, mul_left_comm, mul_comm]
    _ = 1 := ht

theorem diagonal_entry (s t a : Rat) (ht : t * s = 1) :
    t * a * s = a := by
  calc
    t * a * s = (t * s) * a := by
      simp only [mul_assoc, mul_left_comm, mul_comm]
    _ = a := by rw [ht]; simp

theorem zero_entry (s t : Rat) : t * 0 * s = 0 := by simp

theorem jacobi_upper_all (n : Nat) (s t r c : Nat → Rat)
    (hinv : ∀ i, i < n → t i * s i = 1)
    (hroot : ∀ i, i + 1 < n → r i * r i = c i)
    (i : Nat) (hi : i + 1 < n) :
    t i * r i * (s i * r i) = c i :=
  upper_entry (s i) (t i) (r i) (c i)
    (hinv i (Nat.lt_trans (Nat.lt_succ_self i) hi)) (hroot i hi)

theorem jacobi_lower_all (n : Nat) (s t r : Nat → Rat)
    (hrec : ∀ i, i + 1 < n → s (i+1) = s i * r i)
    (hinv : ∀ i, i < n → t i * s i = 1)
    (i : Nat) (hi : i + 1 < n) :
    t (i+1) * r i * s i = 1 :=
  lower_entry (s (i+1)) (t (i+1)) (s i) (r i)
    (hrec i hi) (hinv (i+1) hi)
end E47Jacobi
