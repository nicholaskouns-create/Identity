import Tensor125
/-!
  Exact top-two-weight block of the canonical 125-state spin-2 triple tensor.
  All concrete entries are obtained from Tensor125's genuine 125-term
  products. No eigenvalue, multiplicity or characteristic polynomial is
  supplied to the concrete-entry computation.

  Scope: the four states of weights 6 and 5 only. The other 121 states,
  full annihilator, full spectrum and kernel 47 remain separate obligations.
-/
set_option maxRecDepth 8192
set_option maxHeartbeats 0

namespace E47ConcreteTopWeight

abbrev Mat4 := Fin 4 → Fin 4 → Int

def idx4 (n : Nat) : Fin 4 :=
  ⟨n % 4, Nat.mod_lt n (by decide)⟩

def topIndex (i : Fin 4) : Fin 125 :=
  if i.val = 0 then 0 else if i.val = 1 then 1
  else if i.val = 2 then 5 else 25

/-- Restriction of the actual 125-term concrete Casimir, not a model. -/
def concrete : Mat4 := fun i j =>
  E47Tensor125.mulEntry E47Tensor125.totalDown E47Tensor125.totalUp
    (topIndex i) (topIndex j) +
  (if topIndex i = topIndex j then
    E47Tensor125.totalZ (topIndex i) (topIndex i) *
      (E47Tensor125.totalZ (topIndex i) (topIndex i) + 1) else 0)

/-- Explicit matrix recovered from the concrete generator products. -/
def model : Mat4 := fun i j =>
  if i.val = 0 then (if j.val = 0 then 42 else 0)
  else if j.val = 0 then 0
  else if i = j then 34 else 4

def mul4 (A B : Mat4) (i j : Fin 4) : Int :=
  ((List.range 4).map fun k => A i (idx4 k) * B (idx4 k) j).sum

def eigenvectors : List (List Int) :=
  [[1,0,0,0], [0,1,1,1], [0,1,-1,0], [0,1,0,-1]]
def scaledInverse : List (List Int) :=
  [[3,0,0,0], [0,1,1,1], [0,1,-2,1], [0,1,1,-2]]
def S : Mat4 := fun i j => (eigenvectors.getD i.val []).getD j.val 0
def B : Mat4 := fun i j => (scaledInverse.getD i.val []).getD j.val 0
def spectralD : Mat4 := fun i j =>
  if i = j then (if i.val < 2 then 42 else 30) else 0

def quadraticResidual (A : Mat4) (i j : Fin 4) : Int :=
  mul4 A A i j - 72 * A i j + (if i = j then 1260 else 0)

/-- The weight-6 and weight-5 states are precisely these four basis states. -/
theorem complete_top_weight_set :
    ∀ n : Fin 125,
      (E47Tensor125.totalZ n n ≥ 5 ↔
        (n = 0 ∨ n = 1 ∨ n = 5 ∨ n = 25)) := by decide

/-- Each of the sixteen block entries uses the canonical 125-term product. -/
theorem concrete_entries : ∀ i j : Fin 4, concrete i j = model i j := by decide

/-- Explicit diagonalization, with a two-sided integer inverse scaled by 3. -/
theorem model_diagonalization :
    ∀ i j : Fin 4, mul4 model S i j = mul4 S spectralD i j := by decide

theorem left_inverse_scaled :
    ∀ i j : Fin 4, mul4 B S i j = (if i = j then 3 else 0) := by decide

theorem right_inverse_scaled :
    ∀ i j : Fin 4, mul4 S B i j = (if i = j then 3 else 0) := by decide

theorem model_quadratic_annihilator :
    ∀ i j : Fin 4, quadraticResidual model i j = 0 := by decide

/-- The actual top-weight restriction satisfies (C-30I)(C-42I)=0. -/
theorem concrete_quadratic_annihilator :
    ∀ i j : Fin 4, quadraticResidual concrete i j = 0 := by
  intro i j
  simpa [quadraticResidual, mul4, concrete_entries] using
    (model_quadratic_annihilator i j)

/-- No spectrum is assumed: this is an exact concrete entry mutation. -/
def mutant : Mat4 := fun i j =>
  concrete i j + (if i.val = 1 ∧ j.val = 1 then 1 else 0)

theorem mutant_rejected : quadraticResidual mutant 1 1 ≠ 0 := by decide

end E47ConcreteTopWeight

#print axioms E47ConcreteTopWeight.complete_top_weight_set
#print axioms E47ConcreteTopWeight.concrete_entries
#print axioms E47ConcreteTopWeight.model_diagonalization
#print axioms E47ConcreteTopWeight.left_inverse_scaled
#print axioms E47ConcreteTopWeight.right_inverse_scaled
#print axioms E47ConcreteTopWeight.concrete_quadratic_annihilator
#print axioms E47ConcreteTopWeight.mutant_rejected
