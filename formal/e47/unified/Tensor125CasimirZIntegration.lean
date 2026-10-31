import Lean
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
/-! ## Exact 25 × 5 column partition and conditional Casimir-Z assembly
The concrete five-column block proofs are separately compiled and archived.
This lemma proves their logical coverage without assuming the centrality
claim, importing a spectral theorem, or silently treating the 25 external
proof artifacts as a single Lean theorem. Full Lean assembly is still open. -/

def idx (n : Nat) : Fin 125 :=
  ⟨n % 125, Nat.mod_lt n (by decide)⟩

def mulEntry (A B : Mat125) (i j : Fin 125) : Int :=
  ((List.range 125).map (fun k => A i (idx k) * B (idx k) j)).sum

def concreteCasimirEntry (i j : Fin 125) : Int :=
  mulEntry totalDown totalUp i j +
    (if i = j then totalZ i i * (totalZ i i + 1) else 0)

theorem concreteCasimirZ_column_partition :
    ∀ j : Fin 125, ∃ block : Fin 25, ∃ offset : Fin 5,
      idx (5 * block.val + offset.val) = j := by
  intro j
  -- Construct witnesses rather than asking the kernel to infer a finite
  -- quantified Decidable instance. The division algorithm is exact.
  refine ⟨⟨j.val / 5, by omega⟩, ⟨j.val % 5, by omega⟩, ?_⟩
  apply Fin.ext
  dsimp [idx]
  omega

theorem concreteCasimirZ_full_from_block_hypotheses
    (h : ∀ block : Fin 25, ∀ offset : Fin 5, ∀ i : Fin 125,
      (totalZ i i -
        totalZ (idx (5 * block.val + offset.val))
          (idx (5 * block.val + offset.val))) *
        concreteCasimirEntry i (idx (5 * block.val + offset.val)) = 0) :
    ∀ i j : Fin 125,
      (totalZ i i - totalZ j j) * concreteCasimirEntry i j = 0 := by
  intro i j
  obtain ⟨block, offset, heq⟩ := concreteCasimirZ_column_partition j
  rw [← heq]
  exact h block offset i

end E47Tensor125

#print axioms E47Tensor125.concreteCasimirZ_column_partition
#print axioms E47Tensor125.concreteCasimirZ_full_from_block_hypotheses
