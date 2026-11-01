import Tensor125
/-!
  E47 concrete weight-3 Casimir block. Imported generator entries come
  from the canonical Tensor125.lean. The 10x10 model is checked against
  genuine 125-term products, and the full weight-3 column complement is
  checked for zero. Diagonalization is an exact bounded certificate.
  This is NOT the global 125-dimensional spectral theorem.
-/
set_option maxRecDepth 8192
set_option maxHeartbeats 0

namespace E47ConcreteWeight3
abbrev Mat10 := Fin 10 → Fin 10 → Int
def idx10 (n : Nat) : Fin 10 := ⟨n % 10, Nat.mod_lt n (by decide)⟩
def blockIndex (i : Fin 10) : Fin 125 :=
  E47Tensor125.idx (([3, 7, 11, 15, 27, 31, 35, 51, 55, 75] : List Nat).getD i.val 0)
def fullCasimir (i j : Fin 125) : Int :=
  E47Tensor125.mulEntry E47Tensor125.totalDown E47Tensor125.totalUp i j +
  (if i = j then E47Tensor125.totalZ i i *
    (E47Tensor125.totalZ i i + 1) else 0)
def concrete : Mat10 := fun i j => fullCasimir (blockIndex i) (blockIndex j)
def rows : List (List Int) := [
  [18, 4, 0, 0, 4, 0, 0, 0, 0, 0],
  [6, 22, 6, 0, 4, 4, 0, 0, 0, 0],
  [0, 6, 22, 6, 0, 4, 4, 0, 0, 0],
  [0, 0, 4, 18, 0, 0, 4, 0, 0, 0],
  [6, 4, 0, 0, 22, 4, 0, 6, 0, 0],
  [0, 6, 6, 0, 6, 24, 6, 6, 6, 0],
  [0, 0, 4, 6, 0, 4, 22, 0, 6, 0],
  [0, 0, 0, 0, 6, 4, 0, 22, 4, 6],
  [0, 0, 0, 0, 0, 4, 6, 4, 22, 6],
  [0, 0, 0, 0, 0, 0, 0, 4, 4, 18]
]
def model : Mat10 := fun i j => (rows.getD i.val []).getD j.val 0
def mul10 (X Y : Mat10) (i j : Fin 10) : Int :=
  ((List.range 10).map fun k => X i (idx10 k) * Y (idx10 k) j).sum
def sRows : List (List Int) := [
  [-2, -4, -4, -2, 2, 2, 4, -1, 1, 1],
  [3, 4, 2, 0, -1, 5, 1, -1, 0, 3],
  [-3, -2, 0, 0, -1, -3, 3, 1, -3, 3],
  [2, 0, 0, 0, 2, -6, 6, 1, -2, 1],
  [0, 2, 4, 3, 2, -4, 1, -2, 3, 3],
  [0, -3, -3, 0, -3, 3, -12, 0, 0, 6],
  [0, 2, 0, 0, 2, 0, 0, 2, -3, 3],
  [0, 0, -2, -3, 0, -6, 3, -1, 3, 3],
  [0, 0, 2, 0, 0, 6, 0, 1, 0, 3],
  [0, 0, 0, 2, 0, 0, 6, 0, 1, 1]
]
def bRows : List (List Int) := [
  [-22, 66, -154, 308, -44, 88, -154, -44, 66, -22],
  [-66, 88, -22, -231, -22, -66, 253, 88, -187, 99],
  [-66, -22, 88, 99, 88, -66, -187, -22, 253, -231],
  [-22, -44, -44, -22, 66, 88, 66, -154, -154, 308],
  [162, -72, -138, 63, 126, -30, 159, -72, 27, -135],
  [54, 42, -24, -45, -24, -10, 9, -46, 53, 21],
  [18, 36, 36, 18, -30, -40, -30, 14, 14, 84],
  [-264, -352, -176, 0, -176, 0, 176, 176, 352, 264],
  [-88, -176, -176, -88, 0, 0, 0, 176, 176, 176],
  [24, 48, 48, 24, 48, 64, 48, 48, 48, 24]
]
def eigenvalues : List Int := [12, 12, 12, 12, 20, 20, 20, 30, 30, 42]
def S : Mat10 := fun i j => (sRows.getD i.val []).getD j.val 0
def B : Mat10 := fun i j => (bRows.getD i.val []).getD j.val 0
def spectralD : Mat10 := fun i j =>
  if i = j then eigenvalues.getD i.val 0 else 0
def quarticResidual (X : Mat10) (i j : Fin 10) : Int :=
  mul10 (mul10 (mul10 X X) X) X i j -
  104 * mul10 (mul10 X X) X i j +
  3804 * mul10 X X i j - 57600 * X i j +
  (if i = j then 302400 else 0)

theorem complete_weight3_set :
    ∀ n : Fin 125,
      (E47Tensor125.totalZ n n = 3 ↔
        n.val ∈ ([3, 7, 11, 15, 27, 31, 35, 51, 55, 75] : List Nat)) := by decide

theorem concrete_entries :
    ∀ i j : Fin 10, concrete i j = model i j := by decide

theorem block_column_invariance :
    ∀ i : Fin 10, ∀ n : Fin 125,
      E47Tensor125.totalZ n n ≠ 3 →
        fullCasimir n (blockIndex i) = 0 := by decide

theorem model_diagonalization :
    ∀ i j : Fin 10, mul10 model S i j = mul10 S spectralD i j := by decide

theorem left_inverse_scaled :
    ∀ i j : Fin 10, mul10 B S i j = (if i = j then 1320 else 0) := by decide

theorem right_inverse_scaled :
    ∀ i j : Fin 10, mul10 S B i j = (if i = j then 1320 else 0) := by decide

theorem model_quartic_annihilator :
    ∀ i j : Fin 10, quarticResidual model i j = 0 := by decide

theorem concrete_quartic_annihilator :
    ∀ i j : Fin 10, quarticResidual concrete i j = 0 := by
  intro i j
  simpa [quarticResidual, mul10, concrete_entries] using
    (model_quartic_annihilator i j)

def mutant : Mat10 := fun i j =>
  model i j + (if i.val = 1 ∧ j.val = 1 then 1 else 0)
theorem mutant_rejected : quarticResidual mutant 1 1 ≠ 0 := by decide
end E47ConcreteWeight3

#print axioms E47ConcreteWeight3.complete_weight3_set
#print axioms E47ConcreteWeight3.concrete_entries
#print axioms E47ConcreteWeight3.block_column_invariance
#print axioms E47ConcreteWeight3.model_diagonalization
#print axioms E47ConcreteWeight3.left_inverse_scaled
#print axioms E47ConcreteWeight3.right_inverse_scaled
#print axioms E47ConcreteWeight3.concrete_quartic_annihilator
#print axioms E47ConcreteWeight3.mutant_rejected
