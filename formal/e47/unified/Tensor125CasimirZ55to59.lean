/- Concrete 125-state triple tensor generator entries, in a weight basis. -/
set_option maxRecDepth 8192
set_option maxHeartbeats 0

namespace E47Tensor125
abbrev Mat125 := Fin 125 → Fin 125 → Int
def a (n : Fin 125) : Nat := n.val / 25
def b (n : Fin 125) : Nat := (n.val / 5) % 5
def c (n : Fin 125) : Nat := n.val % 5
def totalZ : Mat125 := fun i j =>
  if i = j then (6 : Int) - (a i : Int) - (b i : Int) - (c i : Int) else 0
def totalUp : Mat125 := fun i j =>
  (if a i + 1 = a j ∧ b i = b j ∧ c i = c j
    then (a j : Int) * (5 - (a j : Int)) else 0) +
  (if a i = a j ∧ b i + 1 = b j ∧ c i = c j
    then (b j : Int) * (5 - (b j : Int)) else 0) +
  (if a i = a j ∧ b i = b j ∧ c i + 1 = c j
    then (c j : Int) * (5 - (c j : Int)) else 0)
def totalDown : Mat125 := fun i j =>
  (if a i = a j + 1 ∧ b i = b j ∧ c i = c j then 1 else 0) +
  (if a i = a j ∧ b i = b j + 1 ∧ c i = c j then 1 else 0) +
  (if a i = a j ∧ b i = b j ∧ c i = c j + 1 then 1 else 0)
/-! ## Isolated Casimir-Z columns 55..59
The exact 125-state spin-2 generator definitions above are copied verbatim
from Tensor125.lean and checked byte-for-byte by CI. Isolating this block
bounds Lean elaboration cost; it does not assume the commutator or spectrum. -/

def idx (n : Nat) : Fin 125 :=
  ⟨n % 125, Nat.mod_lt n (by decide)⟩

def mulEntry (A B : Mat125) (i j : Fin 125) : Int :=
  ((List.range 125).map (fun k => A i (idx k) * B (idx k) j)).sum

def concreteCasimirEntry (i j : Fin 125) : Int :=
  mulEntry totalDown totalUp i j +
    (if i = j then totalZ i i * (totalZ i i + 1) else 0)

theorem concreteCasimirZ_columns_fiftyfive_through_fiftynine :
    ∀ i : Fin 125, ∀ j : Fin 5,
      (totalZ i i -
        totalZ (idx (55 + j.val)) (idx (55 + j.val))) *
        concreteCasimirEntry i (idx (55 + j.val)) = 0 := by
  decide

end E47Tensor125

#print axioms E47Tensor125.concreteCasimirZ_columns_fiftyfive_through_fiftynine
