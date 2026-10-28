/- MC-121 additive bridge: generic diagonal polynomial selector and projector.
   The index type and eigenvalue function are arbitrary. Over Int, the
   no-zero-divisors property gives ker[(D-aI)(D-bI)] = im P_{a,b}.
   This is a theorem for a diagonal operator in a supplied eigenbasis.
   The spectral theorem and the concrete 125x125 Casimir diagonalization
   remain separate obligations (#17-#21). No diagonal surrogate is
   asserted to be the concrete Casimir. -/

namespace E47DiagonalSelector

variable {ι : Type}

def diagonal (e : ι → Int) (v : ι → Int) : ι → Int :=
  fun i => e i * v i

def filter (e : ι → Int) (a b : Int) (v : ι → Int) : ι → Int :=
  fun i => (e i - a) * (e i - b) * v i

def projector (e : ι → Int) (a b : Int) (v : ι → Int) : ι → Int :=
  fun i => if e i = a ∨ e i = b then v i else 0

theorem projector_idempotent (e : ι → Int) (a b : Int) (v : ι → Int) :
    projector e a b (projector e a b v) = projector e a b v := by
  funext i
  by_cases ha : e i = a
  · simp [projector, ha]
  by_cases hb : e i = b
  · simp [projector, hb]
  · simp [projector, ha, hb]

theorem filter_projector_zero (e : ι → Int) (a b : Int) (v : ι → Int) :
    ∀ i, filter e a b (projector e a b v) i = 0 := by
  intro i
  by_cases ha : e i = a
  · simp [filter, projector, ha]
  by_cases hb : e i = b
  · simp [filter, projector, hb]
  · simp [filter, projector, ha, hb]

theorem projector_filter_zero (e : ι → Int) (a b : Int) (v : ι → Int) :
    ∀ i, projector e a b (filter e a b v) i = 0 := by
  intro i
  by_cases ha : e i = a
  · simp [filter, projector, ha]
  by_cases hb : e i = b
  · simp [filter, projector, hb]
  · simp [filter, projector, ha, hb]

theorem projector_commutes_diagonal (e : ι → Int) (a b : Int) (v : ι → Int) :
    projector e a b (diagonal e v) = diagonal e (projector e a b v) := by
  funext i
  by_cases ha : e i = a
  · simp [projector, diagonal, ha]
  by_cases hb : e i = b
  · simp [projector, diagonal, hb]
  · simp [projector, diagonal, ha, hb]

theorem kernel_iff_projector_fixed (e : ι → Int) (a b : Int) (v : ι → Int) :
    (∀ i, filter e a b v i = 0) ↔ projector e a b v = v := by
  constructor
  · intro h
    funext i
    by_cases ha : e i = a
    · simp [projector, ha]
    by_cases hb : e i = b
    · simp [projector, hb]
    have hi := h i
    change (e i - a) * (e i - b) * v i = 0 at hi
    have hv : v i = 0 := by
      cases Int.mul_eq_zero.mp hi with
      | inl hprod =>
        cases Int.mul_eq_zero.mp hprod with
        | inl hleft => exact False.elim (ha (Int.eq_of_sub_eq_zero hleft))
        | inr hright => exact False.elim (hb (Int.eq_of_sub_eq_zero hright))
      | inr hvalue => exact hvalue
    simp [projector, ha, hb, hv]
  · intro h i
    have hi : projector e a b v i = v i :=
      congrArg (fun w : ι → Int => w i) h
    by_cases ha : e i = a
    · simp [filter, ha]
    by_cases hb : e i = b
    · simp [filter, hb]
    have hv : v i = 0 := by
      have hz : (0 : Int) = v i := by
        simpa [projector, ha, hb] using hi
      exact hz.symm
    simp [filter, hv]


/-! ## Additive MC-121 root-space splitting

For distinct roots, the two coordinate root projectors are orthogonal
and their sum is the two-root projector. A vector in the polynomial
kernel therefore splits into its two root-supported components.
The eigenbasis remains supplied, not derived from the concrete Casimir. -/

def rootProjector (e : ι → Int) (r : Int) (v : ι → Int) : ι → Int :=
  fun i => if e i = r then v i else 0

theorem root_projector_idempotent (e : ι → Int) (r : Int) (v : ι → Int) :
    rootProjector e r (rootProjector e r v) = rootProjector e r v := by
  funext i
  by_cases hr : e i = r
  · simp [rootProjector, hr]
  · simp [rootProjector, hr]

theorem distinct_root_projectors_orthogonal
    (e : ι → Int) (a b : Int) (hab : a ≠ b) (v : ι → Int) :
    rootProjector e a (rootProjector e b v) = fun _ => 0 := by
  funext i
  by_cases ha : e i = a
  · have hb : e i ≠ b := by
      intro h
      exact hab (ha.symm.trans h)
    simp [rootProjector, ha, hb]
  · simp [rootProjector, ha]

theorem distinct_root_projector_sum
    (e : ι → Int) (a b : Int) (hab : a ≠ b) (v : ι → Int) :
    projector e a b v =
      fun i => rootProjector e a v i + rootProjector e b v i := by
  funext i
  by_cases ha : e i = a
  · have hb : e i ≠ b := by
      intro h
      exact hab (ha.symm.trans h)
    simp [projector, rootProjector, ha, hb]
  · by_cases hb : e i = b
    · simp [projector, rootProjector, ha, hb]
    · simp [projector, rootProjector, ha, hb]

theorem kernel_distinct_root_split
    (e : ι → Int) (a b : Int) (hab : a ≠ b) (v : ι → Int)
    (hv : ∀ i, filter e a b v i = 0) :
    v = fun i => rootProjector e a v i + rootProjector e b v i := by
  calc
    v = projector e a b v := ((kernel_iff_projector_fixed e a b v).mp hv).symm
    _ = _ := distinct_root_projector_sum e a b hab v

end E47DiagonalSelector

#print axioms E47DiagonalSelector.projector_idempotent
#print axioms E47DiagonalSelector.filter_projector_zero
#print axioms E47DiagonalSelector.projector_filter_zero
#print axioms E47DiagonalSelector.projector_commutes_diagonal
#print axioms E47DiagonalSelector.kernel_iff_projector_fixed
#print axioms E47DiagonalSelector.root_projector_idempotent
#print axioms E47DiagonalSelector.distinct_root_projectors_orthogonal
#print axioms E47DiagonalSelector.distinct_root_projector_sum
#print axioms E47DiagonalSelector.kernel_distinct_root_split
