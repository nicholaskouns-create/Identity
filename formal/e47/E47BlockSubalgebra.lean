/-
  E47BlockSubalgebra.lean — OP-2 closed: the M_z-graded block decomposition is
  an algebra homomorphism on weight-preserving matrices.

  STATUS: PROVED. Compiled clean on Lean 4.19.0 (the toolchain CI pins) and on
  4.35.0. No Mathlib, no `sorry`, no `native_decide`, no custom axioms.

    map_get_finRange          : [propext, Quot.sound]
    foldl_eq_foldl_finRange   : [propext, Quot.sound]
    foldl_allTriples_eq_fiber : [propext, Quot.sound]
    toBlock_mul               : [propext, Classical.choice, Quot.sound]

  This supersedes the placeholder of the same name, which reported sorryAx.

  WHAT IT SAYS. For a matrix A that preserves total magnetic weight --
  A t1 t2 = 0 whenever totalWeight t1 /= totalWeight t2 -- block projection
  commutes with multiplication:

      toBlock M (A * B) = (toBlock M A) * (toBlock M B)

  So a 125 x 125 identity over the weight-preserving subalgebra may be replaced
  by thirteen independent block identities of dimensions
  (1,3,6,10,15,18,19,18,15,10,6,3,1): 27,761 cubic operations against
  1,953,125, a factor of 70.4. The Casimir C = (J1+J2+J3)^2 commutes with Jz
  and is therefore weight-preserving, so every polynomial in C qualifies.

  THE STEP THAT WAS MISSING, and what closed it. The placeholder failed on one
  index-translation lemma: that folding a sum over a list agrees with folding
  it over the list's positions. It is proved here in two moves --
  `map_get_finRange`, that reading a list off by position returns the list
  (by List.ext_getElem), and then List.foldl_map. The rewrite must pin
  (f := l.get) explicitly; left to infer, higher-order unification splits the
  composite the wrong way and absorbs the summand into the map.

  Two further repairs: `by_contra` is a Mathlib tactic and is unavailable here,
  replaced by Classical.byContradiction; and the final step needs
  List.get_eq_getElem applied to hypothesis and goal together, since simp
  normalises `.get` to `getElem` in only one of them.
-/

namespace E47BlockSubalgebra
abbrev BasisTriple := Fin 5 × Fin 5 × Fin 5
def totalWeight (t : BasisTriple) : Fin 13 := ⟨t.1.val + t.2.1.val + t.2.2.val, by omega⟩
def allTriples : List BasisTriple :=
  (List.finRange 5).flatMap fun a => (List.finRange 5).flatMap fun b =>
    (List.finRange 5).map fun c => (a, b, c)
def weightFiber (M : Fin 13) : List BasisTriple := allTriples.filter (fun t => totalWeight t = M)

theorem map_get_finRange {α : Type u} (l : List α) :
    (List.finRange l.length).map l.get = l := by
  apply List.ext_getElem
  · simp
  · intro i h₁ h₂; simp [List.getElem_map, List.getElem_finRange, List.get_eq_getElem]

theorem foldl_eq_foldl_finRange {α : Type u} {β : Type v}
    (l : List α) (g : α → β) (op : β → β → β) (init : β) :
    l.foldl (fun acc t => op acc (g t)) init
      = (List.finRange l.length).foldl (fun acc i => op acc (g (l.get i))) init := by
  rw [← List.foldl_map (f := l.get) (g := fun acc t => op acc (g t))
        (l := List.finRange l.length) (init := init), map_get_finRange]

abbrev Mat125 := BasisTriple → BasisTriple → Int
def IsWeightPreserving (A : Mat125) : Prop :=
  ∀ t1 t2 : BasisTriple, A t1 t2 ≠ 0 → totalWeight t1 = totalWeight t2
def mul125 (A B : Mat125) : Mat125 := fun t1 t3 =>
  allTriples.foldl (fun acc t2 => acc + A t1 t2 * B t2 t3) 0
abbrev BlockMat (M : Fin 13) := Fin (weightFiber M).length → Fin (weightFiber M).length → Int
def toBlock (M : Fin 13) (A : Mat125) : BlockMat M := fun i j =>
  A ((weightFiber M).get i) ((weightFiber M).get j)
def blockMul (M : Fin 13) (A B : BlockMat M) : BlockMat M := fun i k =>
  (List.finRange (weightFiber M).length).foldl (fun acc j => acc + A i j * B j k) 0

theorem foldl_allTriples_eq_fiber (M : Fin 13) (f : BasisTriple → Int)
    (hf : ∀ t : BasisTriple, totalWeight t ≠ M → f t = 0) :
    allTriples.foldl (fun acc t => acc + f t) 0
      = (weightFiber M).foldl (fun acc t => acc + f t) 0 := by
  unfold weightFiber
  have hgen : ∀ (l : List BasisTriple) (init : Int),
      l.foldl (fun acc t => acc + f t) init
        = (l.filter (fun t => totalWeight t = M)).foldl (fun acc t => acc + f t) init := by
    intro l
    induction l with
    | nil => intro init; rfl
    | cons x xs ih =>
      intro init
      by_cases hM : totalWeight x = M
      · simp [List.foldl, List.filter, hM, ih]
      · have hfx : f x = 0 := hf x hM
        simp [List.foldl, List.filter, hM, hfx, ih]
  exact hgen allTriples 0

theorem toBlock_mul (M : Fin 13) (A B : Mat125) (hA : IsWeightPreserving A) :
    toBlock M (mul125 A B) = blockMul M (toBlock M A) (toBlock M B) := by
  funext i k
  show allTriples.foldl
        (fun acc t2 => acc + A ((weightFiber M).get i) t2 * B t2 ((weightFiber M).get k)) 0
      = (List.finRange (weightFiber M).length).foldl
        (fun acc j => acc + A ((weightFiber M).get i) ((weightFiber M).get j)
                          * B ((weightFiber M).get j) ((weightFiber M).get k)) 0
  have ht1 : totalWeight ((weightFiber M).get i) = M := by
    have hmem : (weightFiber M).get i ∈ weightFiber M := List.get_mem _ _
    simp only [weightFiber, List.mem_filter, decide_eq_true_eq] at hmem
    exact hmem.2
  rw [foldl_allTriples_eq_fiber M
       (fun t2 => A ((weightFiber M).get i) t2 * B t2 ((weightFiber M).get k))]
  · exact foldl_eq_foldl_finRange (weightFiber M)
      (fun t2 => A ((weightFiber M).get i) t2 * B t2 ((weightFiber M).get k))
      (fun a b => a + b) 0
  · intro t2 ht2
    have hA0 : A ((weightFiber M).get i) t2 = 0 :=
      Classical.byContradiction (fun hne => ht2 ((hA _ t2 hne).symm.trans ht1))
    simp only [List.get_eq_getElem] at hA0 ⊢
    rw [hA0, Int.zero_mul]

end E47BlockSubalgebra
