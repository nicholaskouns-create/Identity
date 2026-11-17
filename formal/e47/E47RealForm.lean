/- The real-form step of the E47 controllability argument.
   Pure Lean 4, no Mathlib, no sorry.

   Target:  g ⊆ u(n)  and  g + i·g = gl_n(C)   ⟹   g = u(n).

   The argument splits into four obligations:
     (1) scalar          x = -x ⟹ x = 0 over a field of characteristic 0
     (2) matrix          Y skew-Hermitian ⟹ iY Hermitian; Hermitian ∧ skew ⟹ 0,
                         hence  g ∩ i·g = {0}
     (3) complexification Φ : g ⊗_R C → g + i·g is onto, and (2) makes it injective
     (4) dimension       dim_R g = dim_C (g ⊗_R C) = n², and g ⊆ u(n) with
                         dim_R u(n) = n² forces equality

   Obligations (1) and (2) are proved here, in full, with no axioms beyond
   Lean's kernel basis.  They are the part that carries the real form:
   characteristic zero and skew-Hermiticity are what make the intersection
   trivial, and nothing about dimension is used to establish it.
   Obligation (3) is a routine consequence of (2) once a tensor product is
   available; obligation (4) is the only step that genuinely needs
   finite-dimensional linear algebra (finrank), which a stdlib-only
   development does not have.  Both are stated precisely at the end of this
   file and are NOT claimed as proved here.
-/
namespace E47RealForm

instance : Std.Associative (α := Rat) (· * ·) := ⟨Rat.mul_assoc⟩
instance : Std.Commutative (α := Rat) (· * ·) := ⟨Rat.mul_comm⟩

/- ====================== Obligation (1): the scalar step ================== -/

/-- Characteristic zero, via `x⁻¹` rather than the literal 2. -/
theorem self_neg_zero (x : Rat) (h : x = -x) : x = 0 := by
  apply Classical.byContradiction
  intro hx
  have h1 : x⁻¹ * x = 1 := Rat.inv_mul_cancel x hx
  have e  : x⁻¹ * x = x⁻¹ * -x := congrArg (x⁻¹ * ·) h
  have h2 : (1:Rat) = -1 := by
    calc (1:Rat) = x⁻¹ * x := h1.symm
      _ = x⁻¹ * -x         := e
      _ = -(x⁻¹ * x)       := Rat.mul_neg x⁻¹ x
      _ = -1               := by rw [h1]
  have h3 : (1:Rat).num = (-1:Rat).num := congrArg Rat.num h2
  exact absurd h3 (by decide)

/- ============ Gaussian rationals: a concrete complex scalar field ======== -/

structure GQ where
  re : Rat
  im : Rat

namespace GQ
def zero : GQ := ⟨0, 0⟩
def I    : GQ := ⟨0, 1⟩
def neg  (z : GQ) : GQ := ⟨-z.re, -z.im⟩
def mul  (z w : GQ) : GQ := ⟨z.re*w.re - z.im*w.im, z.re*w.im + z.im*w.re⟩
def cj   (z : GQ) : GQ := ⟨z.re, -z.im⟩

theorem ext {z w : GQ} (hr : z.re = w.re) (hi : z.im = w.im) : z = w := by
  cases z; cases w; simp_all

/-- The scalar step, transported to the complex scalars componentwise. -/
theorem self_neg_zero (z : GQ) (h : z = neg z) : z = zero :=
  ext (E47RealForm.self_neg_zero z.re (congrArg GQ.re h))
      (E47RealForm.self_neg_zero z.im (congrArg GQ.im h))
end GQ

/- =================== Obligation (2): the matrix step ===================== -/

abbrev CMat := Nat → Nat → GQ

def dagger (A : CMat) : CMat := fun i j => GQ.cj (A j i)
def smulI  (A : CMat) : CMat := fun i j => GQ.mul GQ.I (A i j)

def IsHerm (n : Nat) (A : CMat) : Prop :=
  ∀ i j, i < n → j < n → dagger A i j = A i j
def IsSkew (n : Nat) (A : CMat) : Prop :=
  ∀ i j, i < n → j < n → dagger A i j = GQ.neg (A i j)

/-- Multiplying a skew-Hermitian matrix by i yields a Hermitian matrix.
    This is the step that makes the two real subspaces meet only at 0. -/
theorem smulI_skew_isHerm (n : Nat) (Y : CMat) (hY : IsSkew n Y) :
    IsHerm n (smulI Y) := by
  intro i j hi hj
  have h := hY j i hj hi
  have hre : (Y i j).re = -(Y j i).re := congrArg GQ.re h
  have him : -(Y i j).im = -(Y j i).im := congrArg GQ.im h
  have him' : (Y i j).im = (Y j i).im := by
    have := congrArg (fun x : Rat => -x) him
    simpa using this
  show GQ.cj (GQ.mul GQ.I (Y j i)) = GQ.mul GQ.I (Y i j)
  apply GQ.ext
  · show (0 * (Y j i).re - 1 * (Y j i).im) = (0 * (Y i j).re - 1 * (Y i j).im)
    simp [him']
  · show -(0 * (Y j i).im + 1 * (Y j i).re) = (0 * (Y i j).im + 1 * (Y i j).re)
    simp [hre, Rat.zero_add]

/-- A matrix that is both Hermitian and skew-Hermitian vanishes. -/
theorem herm_skew_zero (n : Nat) (A : CMat)
    (hH : IsHerm n A) (hS : IsSkew n A) :
    ∀ i j, i < n → j < n → A i j = GQ.zero := by
  intro i j hi hj
  exact GQ.self_neg_zero (A i j) (((hH i j hi hj).symm).trans (hS i j hi hj))

/-- **Obligation (2), the boxed result:  g ∩ i·g = {0}.**
    If X is skew-Hermitian and X = i·Y for some skew-Hermitian Y,
    then X vanishes on the index range. -/
theorem real_form_inter_trivial (n : Nat) (X Y : CMat)
    (hX : IsSkew n X) (hY : IsSkew n Y)
    (hXY : ∀ i j, X i j = smulI Y i j) :
    ∀ i j, i < n → j < n → X i j = GQ.zero := by
  have hXH : IsHerm n X := by
    intro i j hi hj
    have hb := smulI_skew_isHerm n Y hY i j hi hj
    show GQ.cj (X j i) = X i j
    rw [hXY j i, hXY i j]
    exact hb
  exact herm_skew_zero n X hXH hX

/- ======================= Remaining obligations =========================== -/

/-  NOT PROVED HERE.  Stated so the gap is exact rather than vague.

    (3) Complexification.  With g a real Lie subalgebra of the skew-Hermitian
        matrices, the map
            Φ : g ⊗_R C → g + i·g,     Φ(X ⊗ (a + ib)) = aX + i b X
        is C-linear and surjective by construction, and injective by
        `real_form_inter_trivial` above.  Hence g ⊗_R C ≅ g + i·g.
        Formalizing this needs a tensor product over R.

    (4) Dimension.  Complexification preserves the numerical dimension:
            dim_R g = dim_C (g ⊗_R C) = n².
        With g ⊆ u(n) and dim_R u(n) = n², equality follows.
        Formalizing this needs finrank over a field, i.e. Mathlib.

    Only (4) is irreducibly dimension-theoretic.  (1) and (2), proved above,
    are what make the real form work; (3) is bookkeeping over a tensor
    product.  The E47 instance supplies the hypothesis of (4) through the
    exact rational commutator certificate.
-/

end E47RealForm
