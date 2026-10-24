/-!
# Concrete spin-2 generators over the integers (lane #15)

This module defines the actual five-by-five matrices in the nonorthonormal
weight basis k = 0,...,4.  All matrix products are finite sums of five
integer products; the universal Fin 5 × Fin 5 statements are decided by
Lean's kernel. No spectrum, Casimir eigenvalue, or rank is assumed.

Up |k⟩ = k(5-k)|k-1⟩; Down |k⟩ = |k+1⟩; Z |k⟩ = (2-k)|k⟩.
This is the one-factor input to the 125-by-125 triple-tensor construction.
-/
namespace E47Spin2

abbrev Mat5 := Fin 5 → Fin 5 → Int

def z : Mat5 := fun i j =>
  if i = j then 2 - (i.val : Int) else 0

def up : Mat5 := fun i j =>
  if i.val + 1 = j.val
  then (j.val : Int) * (5 - (j.val : Int))
  else 0

def down : Mat5 := fun i j =>
  if i.val = j.val + 1 then 1 else 0

def mul (a b : Mat5) : Mat5 := fun i j =>
  a i 0 * b 0 j + a i 1 * b 1 j + a i 2 * b 2 j +
  a i 3 * b 3 j + a i 4 * b 4 j

def casimir : Mat5 := fun i j =>
  mul z z i j + z i j + mul down up i j

theorem commutator_z_up :
    ∀ i j : Fin 5, mul z up i j - mul up z i j = up i j := by
  decide

theorem commutator_z_down :
    ∀ i j : Fin 5, mul z down i j - mul down z i j = -(down i j) := by
  decide

theorem commutator_up_down :
    ∀ i j : Fin 5, mul up down i j - mul down up i j = 2 * z i j := by
  decide

theorem spin2_casimir_scalar :
    ∀ i j : Fin 5, casimir i j = if i = j then 6 else 0 := by
  decide

end E47Spin2

-- Audit the four theorem dependencies in CI output.
#print axioms E47Spin2.commutator_z_up
#print axioms E47Spin2.commutator_z_down
#print axioms E47Spin2.commutator_up_down
#print axioms E47Spin2.spin2_casimir_scalar
