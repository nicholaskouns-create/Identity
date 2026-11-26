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
/-! ## Isolated compiler certificate for third-bracket columns 75..79

Generator definitions are bytewise checked against Tensor125.lean in CI.
All 625 entries evaluate the genuine 125-term integer matrix products.
No prior bracket conclusion is imported as an assumption.
-/

def idx (n : Nat) : Fin 125 :=
  ⟨n % 125, Nat.mod_lt n (by decide)⟩

def mulEntry (A B : Mat125) (i j : Fin 125) : Int :=
  ((List.range 125).map (fun k => A i (idx k) * B (idx k) j)).sum

def columnsSeventyFiveThroughSeventyNine (j : Fin 5) : Fin 125 := idx (75 + j.val)

theorem totalUp_down_bracket_columns_seventyfive_through_seventynine :
    ∀ i : Fin 125, ∀ j : Fin 5,
      mulEntry totalUp totalDown i (columnsSeventyFiveThroughSeventyNine j) -
        mulEntry totalDown totalUp i (columnsSeventyFiveThroughSeventyNine j) =
          2 * totalZ i (columnsSeventyFiveThroughSeventyNine j) := by
  decide

end E47Tensor125

#print axioms E47Tensor125.totalUp_down_bracket_columns_seventyfive_through_seventynine
