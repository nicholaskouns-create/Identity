/- Concrete 125-state triple tensor generator entries, in a weight basis. -/
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
theorem highest_weight : totalZ 0 0 = 6 := by decide
theorem lowest_weight : totalZ 124 124 = -6 := by decide
theorem highest_raising_zero : ∀ i : Fin 125, totalUp i 0 = 0 := by decide
theorem lowest_lowering_zero : ∀ i : Fin 125, totalDown i 124 = 0 := by decide

/-! ## Concrete diagonal-weight bridge

These counts are computed from the actual 125-entry diagonal of totalZ,
not from a separately postulated spin decomposition. The block-dimension
identity below is combinatorial; connecting these blocks to eigenspaces
of the full 125-by-125 Casimir is a separate proof obligation (#17-#21).
-/

def idx (n : Nat) : Fin 125 :=
  ⟨n % 125, Nat.mod_lt n (by decide)⟩

def weightCount (m : Int) : Nat :=
  (List.range 125).countP fun n => decide (totalZ (idx n) (idx n) = m)

def multiplicity (j : Nat) : Nat :=
  weightCount (j : Int) - weightCount ((j + 1 : Nat) : Int)

theorem diagonal_weight_counts :
    (List.range 13).map (fun n => weightCount ((n : Int) - 6)) =
      [1, 3, 6, 10, 15, 18, 19, 18, 15, 10, 6, 3, 1] := by
  decide

theorem spin_multiplicities_from_diagonal :
    (List.range 7).map multiplicity = [1, 3, 5, 4, 3, 2, 1] := by
  decide

theorem dimension_from_diagonal :
    ((List.range 7).map fun j => multiplicity j * (2 * j + 1)).sum = 125 := by
  decide

theorem selected_block_dimension_from_diagonal :
    multiplicity 2 * 5 + multiplicity 5 * 11 = 47 := by
  decide

theorem totalZ_trace :
    ((List.range 125).map fun n => totalZ (idx n) (idx n)).sum = 0 := by
  decide

theorem totalZ_diagonal_square_trace :
    ((List.range 125).map fun n =>
      totalZ (idx n) (idx n) * totalZ (idx n) (idx n)).sum = 750 := by
  decide

end E47Tensor125

#print axioms E47Tensor125.diagonal_weight_counts
#print axioms E47Tensor125.spin_multiplicities_from_diagonal
#print axioms E47Tensor125.dimension_from_diagonal
#print axioms E47Tensor125.selected_block_dimension_from_diagonal
#print axioms E47Tensor125.totalZ_trace
#print axioms E47Tensor125.totalZ_diagonal_square_trace
