import Tensor125
/-!
  Concrete weight-4 Casimir block from the canonical 125-state spin-2 triple
  tensor. No spectral roots are used in constructing the entries.
  The six weight-4 states are checked exhaustively. The matrix's exact
  diagonalization is a bounded certificate, not a global spectral theorem.
-/
set_option maxRecDepth 8192
set_option maxHeartbeats 0

namespace E47ConcreteWeight4

abbrev Mat6 := Fin 6 → Fin 6 → Int

def idx6 (n : Nat) : Fin 6 :=
  ⟨n % 6, Nat.mod_lt n (by decide)⟩

def blockIndex (i : Fin 6) : Fin 125 :=
  E47Tensor125.idx (([2, 6, 10, 26, 30, 50] : List Nat).getD i.val 0)

def fullCasimir (i j : Fin 125) : Int :=
  E47Tensor125.mulEntry E47Tensor125.totalDown E47Tensor125.totalUp i j +
  (if i = j then E47Tensor125.totalZ i i *
    (E47Tensor125.totalZ i i + 1) else 0)

def concrete : Mat6 := fun i j => fullCasimir (blockIndex i) (blockIndex j)

def rows : List (List Int) :=
  [[26,4,0,4,0,0],
   [6,28,6,4,4,0],
   [0,4,26,0,4,0],
   [6,4,0,28,4,6],
   [0,4,6,4,28,6],
   [0,0,0,4,4,26]]
def model : Mat6 := fun i j => (rows.getD i.val []).getD j.val 0

def mul6 (A B : Mat6) (i j : Fin 6) : Int :=
  ((List.range 6).map fun k => A i (idx6 k) * B (idx6 k) j).sum

/-- Integer columns are independent eigenvectors, with eigenvalues
    20,20,20,30,30,42. The inverse is scaled by 825. -/
def sRows : List (List Int) :=
  [[2,4,2,-1,0,1],
   [-3,-3,0,0,-1,2],
   [2,0,0,1,-1,1],
   [0,-3,-3,-1,1,2],
   [0,3,0,1,0,2],
   [0,0,2,0,1,1]]
def bRows : List (List Int) :=
  [[45,-105,210,60,-105,45],
   [60,-30,-105,-30,135,-105],
   [45,60,45,-105,-105,210],
   [-330,-110,165,-110,220,165],
   [-165,-220,-165,110,110,330],
   [75,100,75,100,100,75]]
def S : Mat6 := fun i j => (sRows.getD i.val []).getD j.val 0
def B : Mat6 := fun i j => (bRows.getD i.val []).getD j.val 0
def spectralD : Mat6 := fun i j =>
  if i = j then (if i.val < 3 then 20 else if i.val < 5 then 30 else 42) else 0

def cubicResidual (A : Mat6) (i j : Fin 6) : Int :=
  mul6 (mul6 A A) A i j - 92 * mul6 A A i j +
  2700 * A i j - (if i = j then 25200 else 0)

theorem complete_weight4_set :
    ∀ n : Fin 125,
      (E47Tensor125.totalZ n n = 4 ↔
        (n = 2 ∨ n = 6 ∨ n = 10 ∨ n = 26 ∨ n = 30 ∨ n = 50)) := by decide

theorem concrete_entries :
    ∀ i j : Fin 6, concrete i j = model i j := by decide

/-- The actual Casimir has no outgoing entries from the six-dimensional
    weight-4 subspace. This checks genuine 125-term products. -/
theorem block_column_invariance :
    ∀ i : Fin 6, ∀ n : Fin 125,
      E47Tensor125.totalZ n n ≠ 4 → fullCasimir n (blockIndex i) = 0 := by decide

theorem model_diagonalization :
    ∀ i j : Fin 6, mul6 model S i j = mul6 S spectralD i j := by decide

theorem left_inverse_scaled :
    ∀ i j : Fin 6, mul6 B S i j = (if i = j then 825 else 0) := by decide

theorem right_inverse_scaled :
    ∀ i j : Fin 6, mul6 S B i j = (if i = j then 825 else 0) := by decide

theorem model_cubic_annihilator :
    ∀ i j : Fin 6, cubicResidual model i j = 0 := by decide

theorem concrete_cubic_annihilator :
    ∀ i j : Fin 6, cubicResidual concrete i j = 0 := by
  intro i j
  simpa [cubicResidual, mul6, concrete_entries] using
    (model_cubic_annihilator i j)

def mutant : Mat6 := fun i j =>
  model i j + (if i.val = 1 ∧ j.val = 1 then 1 else 0)

theorem mutant_rejected : cubicResidual mutant 1 1 ≠ 0 := by decide

end E47ConcreteWeight4

#print axioms E47ConcreteWeight4.complete_weight4_set
#print axioms E47ConcreteWeight4.concrete_entries
#print axioms E47ConcreteWeight4.block_column_invariance
#print axioms E47ConcreteWeight4.model_diagonalization
#print axioms E47ConcreteWeight4.left_inverse_scaled
#print axioms E47ConcreteWeight4.right_inverse_scaled
#print axioms E47ConcreteWeight4.concrete_cubic_annihilator
#print axioms E47ConcreteWeight4.mutant_rejected
