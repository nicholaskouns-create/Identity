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


/-! Candidate Casimir spectral moments from the *computed* Z-weight counts.
The candidate eigenvalue/multiplicity pairs are a consistency constraint,
NOT an assertion that the concrete 125×125 Casimir has these eigenspaces.
A separate polynomial-annihilation/rank proof is required. -/
def candidateCasimirSpectrum : List (Nat × Nat) :=
  (List.range 7).map fun j =>
    (j * (j + 1), multiplicity j * (2 * j + 1))

theorem candidateCasimirSpectrum_exact :
    candidateCasimirSpectrum =
      [(0, 1), (2, 9), (6, 25), (12, 28),
       (20, 27), (30, 22), (42, 13)] := by
  decide

def candidateCasimirMoment (p : Nat) : Nat :=
  ((List.range 7).map fun j =>
    multiplicity j * (2 * j + 1) * (j * (j + 1)) ^ p).sum

theorem candidateCasimirMoments :
    candidateCasimirMoment 0 = 125 ∧
    candidateCasimirMoment 1 = 2250 ∧
    candidateCasimirMoment 2 = 58500 := by
  decide

theorem candidateCasimirFirstMomentMatchesConcreteTrace :
    (candidateCasimirMoment 1 : Int) =
      ((List.range 125).map (fun n => casimirDiag (idx n))).sum := by
  have h : candidateCasimirMoment 1 = 2250 := by decide
  rw [h]
  exact concrete_casimir_trace.symm

/-! ## First five complete columns of the third concrete Lie bracket

This is a bounded, compiler-checkable extension of the diagonal theorem.
Every row i of columns j = 0,1,2,3,4 uses the original 125-term
matrix multiplication, including off-diagonal entries. No spectral
assumption or surrogate diagonal operator is used. The remaining
120 columns remain obligations.
-/

def firstFiveColumn (j : Fin 5) : Fin 125 := idx j.val

theorem totalUp_down_bracket_first_five_columns :
    ∀ i : Fin 125, ∀ j : Fin 5,
      mulEntry totalUp totalDown i (firstFiveColumn j) -
        mulEntry totalDown totalUp i (firstFiveColumn j) =
          2 * totalZ i (firstFiveColumn j) := by
  decide


/-! ## Next five concrete third-bracket columns (5 through 9)

This theorem evaluates the genuine 125-term matrix products for all
125 rows and exactly five additional columns, without assuming the
full commutator identity. Together with the previous first-five-column
theorem, the first ten columns have finite certificates. The other
115 columns remain an open formal proof obligation.
-/

def nextFiveColumn (j : Fin 5) : Fin 125 := idx (5 + j.val)

theorem totalUp_down_bracket_next_five_columns :
    ∀ i : Fin 125, ∀ j : Fin 5,
      mulEntry totalUp totalDown i (nextFiveColumn j) -
        mulEntry totalDown totalUp i (nextFiveColumn j) =
          2 * totalZ i (nextFiveColumn j) := by
  decide



/-! ## Concrete third-bracket columns 10 through 14

Extends the actual 125-term products by 625 additional entry certificates,
with no imported Lie-bracket conclusion. Columns 15..124 remain pending.
-/ 

def columnsTenThroughFourteen (j : Fin 5) : Fin 125 := idx (10 + j.val)

theorem totalUp_down_bracket_columns_ten_through_fourteen :
    ∀ i : Fin 125, ∀ j : Fin 5,
      mulEntry totalUp totalDown i (columnsTenThroughFourteen j) -
        mulEntry totalDown totalUp i (columnsTenThroughFourteen j) =
          2 * totalZ i (columnsTenThroughFourteen j) := by
  decide


/-! Columns 15..19 are retained in Tensor125Columns15to19.lean,
    isolated to avoid the CI runner lifetime limit. -/

/-! The 25 five-column intervals partition all 125 column indices.
This arithmetic lemma is a bridge for aggregating separately compiled
concrete commutator certificates; it is not itself an integrated
commutator theorem. -/
def thirdBracketColumnPartition : List Nat :=
  (List.range 25).flatMap (fun block =>
    (List.range 5).map (fun offset => 5 * block + offset))

theorem thirdBracketColumnPartition_exact :
    thirdBracketColumnPartition = List.range 125 := by
  decide


/-! ## First concrete Casimir centrality block: [C,Z] columns 0..4

C = D*U + Z*(Z+I), with the *actual* 125-term D*U matrix product.
Since Z is diagonal, [C,Z]ᵢⱼ = (Zⱼⱼ-Zᵢᵢ)Cᵢⱼ.
The finite equality below checks every row and columns 0..4.
This is not the full 125-column centrality theorem, nor a spectral claim. -/

def concreteCasimirEntry (i j : Fin 125) : Int :=
  mulEntry totalDown totalUp i j +
    (if i = j then totalZ i i * (totalZ i i + 1) else 0)

theorem concreteCasimirZ_first_five_columns :
    ∀ i : Fin 125, ∀ j : Fin 5,
      (totalZ i i -
        totalZ (firstFiveColumn j) (firstFiveColumn j)) *
        concreteCasimirEntry i (firstFiveColumn j) = 0 := by
  decide

/-! ## Concrete Casimir centrality [C,Z], columns 5..9
The entry uses the same 125-term D*U product and diagonal Z correction
as the first block. All 125 rows are checked; no spectral assumption. -/
theorem concreteCasimirZ_next_five_columns :
    ∀ i : Fin 125, ∀ j : Fin 5,
      (totalZ i i -
        totalZ (nextFiveColumn j) (nextFiveColumn j)) *
        concreteCasimirEntry i (nextFiveColumn j) = 0 := by
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

#print axioms E47Tensor125.totalUp_down_bracket_first_five_columns

#print axioms E47Tensor125.totalUp_down_bracket_next_five_columns

#print axioms E47Tensor125.totalUp_down_bracket_columns_ten_through_fourteen



#print axioms E47Tensor125.thirdBracketColumnPartition_exact

#print axioms E47Tensor125.candidateCasimirSpectrum_exact
#print axioms E47Tensor125.candidateCasimirMoments
#print axioms E47Tensor125.candidateCasimirFirstMomentMatchesConcreteTrace

#print axioms E47Tensor125.concreteCasimirZ_first_five_columns
#print axioms E47Tensor125.concreteCasimirZ_next_five_columns
