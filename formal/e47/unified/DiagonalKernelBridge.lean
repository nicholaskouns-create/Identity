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

end E47DiagonalSelector

#print axioms E47DiagonalSelector.projector_idempotent
#print axioms E47DiagonalSelector.filter_projector_zero
#print axioms E47DiagonalSelector.projector_filter_zero
#print axioms E47DiagonalSelector.projector_commutes_diagonal
#print axioms E47DiagonalSelector.kernel_iff_projector_fixed
