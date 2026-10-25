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
    (List.range 13).map (fun (n : Nat) => weightCount ((n : Int) - 6)) =
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


/-! ## Tensor weight-generator brackets, exact 125 × 125 entry certificates

For diagonal Z, (ZU - UZ)ᵢⱼ = (Zᵢᵢ - Zⱼⱼ)Uᵢⱼ.
The following certificates quantify over every pair of concrete basis indices.
The full U/D commutator and Casimir spectral polynomial remain separate
obligations. -/

theorem totalZ_up_bracket_entries :
    ∀ i j : Fin 125,
      (totalZ i i - totalZ j j) * totalUp i j = totalUp i j := by
  decide

theorem totalZ_down_bracket_entries :
    ∀ i j : Fin 125,
      (totalZ i i - totalZ j j) * totalDown i j = -(totalDown i j) := by
  decide


/-! ## Concrete matrix products: diagonal third bracket and Casimir trace

This uses the genuine 125-term matrix product, not a surrogate
weight-only expression. It certifies every diagonal entry of
[totalUp,totalDown] = 2 totalZ. The off-diagonal entries of this
third commutator remain an explicit separate obligation.
-/

def mulEntry (A B : Mat125) (i j : Fin 125) : Int :=
  ((List.range 125).map (fun k => A i (idx k) * B (idx k) j)).sum

theorem totalUp_down_bracket_diagonal :
    ∀ i : Fin 125,
      mulEntry totalUp totalDown i i -
        mulEntry totalDown totalUp i i = 2 * totalZ i i := by
  decide

def casimirDiag (i : Fin 125) : Int :=
  mulEntry totalDown totalUp i i +
    totalZ i i * (totalZ i i + 1)

theorem concrete_casimir_trace :
    ((List.range 125).map (fun n => casimirDiag (idx n))).sum = 2250 := by
  decide


/-! ## MC-300 / DBSK-C01: degree-two capacity, concrete weight-derived finite census

The seven sector dimensions below are derived from totalZ's 125-state
diagonal by the weight-counting definitions above. These certificates
enumerate all distinct sector pairs. They do NOT yet identify those
sectors with eigenspaces of the full concrete Casimir, nor prove the
general polynomial root-counting theorem. -/

def sectorDim (j : Fin 7) : Nat :=
  multiplicity j.val * (2 * j.val + 1)

theorem sector_dimensions_from_diagonal :
    (List.range 7).map (fun j => multiplicity j * (2 * j + 1)) =
      [1, 9, 25, 28, 27, 22, 13] := by
  decide

theorem every_single_sector_at_most_28 :
    ∀ j : Fin 7, sectorDim j ≤ 28 := by
  decide

theorem every_distinct_pair_at_most_55 :
    ∀ i j : Fin 7, i ≠ j → sectorDim i + sectorDim j ≤ 55 := by
  decide

theorem unique_maximal_quadratic_pair :
    ∀ i j : Fin 7, i ≠ j →
      (sectorDim i + sectorDim j = 55 ↔
        (i.val = 3 ∧ j.val = 4) ∨ (i.val = 4 ∧ j.val = 3)) := by
  decide

theorem canonical_e47_pair_dimension :
    sectorDim 2 + sectorDim 5 = 47 := by
  decide

end E47Tensor125

#print axioms E47Tensor125.totalZ_up_bracket_entries
#print axioms E47Tensor125.totalZ_down_bracket_entries
#print axioms E47Tensor125.diagonal_weight_counts
#print axioms E47Tensor125.spin_multiplicities_from_diagonal
#print axioms E47Tensor125.dimension_from_diagonal
#print axioms E47Tensor125.selected_block_dimension_from_diagonal
#print axioms E47Tensor125.totalZ_trace
#print axioms E47Tensor125.totalZ_diagonal_square_trace

#print axioms E47Tensor125.totalUp_down_bracket_diagonal
#print axioms E47Tensor125.concrete_casimir_trace

#print axioms E47Tensor125.sector_dimensions_from_diagonal
#print axioms E47Tensor125.every_single_sector_at_most_28
#print axioms E47Tensor125.every_distinct_pair_at_most_55
#print axioms E47Tensor125.unique_maximal_quadratic_pair
#print axioms E47Tensor125.canonical_e47_pair_dimension
