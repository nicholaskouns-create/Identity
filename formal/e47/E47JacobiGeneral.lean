/- Exact Jacobi rationalization, arbitrary dimension.
   Pure Lean 4, no Mathlib, no axioms or sorry.
   The square-root data are represented by rᵢ with rᵢ*rᵢ=cᵢ.
   These theorems prove the four entry classes of S⁻¹ B S,
   assemble them into a single all-entries similarity theorem,
   and establish that diagonal conjugation preserves products,
   differences and commutators -- the transport step that carries
   a rational commutator certificate back to the original pair.
-/
namespace E47Jacobi

/- `ac_rfl` needs these two instances to normalise products of `Rat`;
   core Lean registers neither, which is why the bare tactic fails. -/
instance : Std.Associative (α := Rat) (· * ·) := ⟨Rat.mul_assoc⟩
instance : Std.Commutative (α := Rat) (· * ·) := ⟨Rat.mul_comm⟩

/- ===================================================================
   Part 1.  The four entry classes.
   =================================================================== -/

theorem upper_entry (s t r c : Rat)
    (ht : t * s = 1) (hr : r * r = c) :
    t * r * (s * r) = c := by
  calc
    t * r * (s * r) = (t * s) * (r * r) := by
      ac_rfl
    _ = c := by rw [ht, hr]; simp

theorem lower_entry (sNext tNext s r : Rat)
    (hs : sNext = s * r) (ht : tNext * sNext = 1) :
    tNext * r * s = 1 := by
  calc
    tNext * r * s = tNext * sNext := by
      rw [hs]
      ac_rfl
    _ = 1 := ht

theorem diagonal_entry (s t a : Rat) (ht : t * s = 1) :
    t * a * s = a := by
  calc
    t * a * s = (t * s) * a := by
      ac_rfl
    _ = a := by rw [ht]; simp

theorem zero_entry (s t : Rat) : t * 0 * s = 0 := by simp

theorem jacobi_upper_all (n : Nat) (s t r c : Nat → Rat)
    (hinv : ∀ i, i < n → t i * s i = 1)
    (hroot : ∀ i, i + 1 < n → r i * r i = c i)
    (i : Nat) (hi : i + 1 < n) :
    t i * r i * (s i * r i) = c i :=
  upper_entry (s i) (t i) (r i) (c i)
    (hinv i (Nat.lt_trans (Nat.lt_succ_self i) hi)) (hroot i hi)

theorem jacobi_lower_all (n : Nat) (s t r : Nat → Rat)
    (hrec : ∀ i, i + 1 < n → s (i+1) = s i * r i)
    (hinv : ∀ i, i < n → t i * s i = 1)
    (i : Nat) (hi : i + 1 < n) :
    t (i+1) * r i * s i = 1 :=
  lower_entry (s (i+1)) (t (i+1)) (s i) (r i)
    (hrec i hi) (hinv (i+1) hi)

/- ===================================================================
   Part 2.  Matrices as index functions, and finite sums.
   =================================================================== -/

abbrev Mat := Nat → Nat → Rat

def sum : Nat → (Nat → Rat) → Rat
  | 0,     _ => 0
  | (n+1), f => sum n f + f n

theorem sum_congr : ∀ (n : Nat) (f g : Nat → Rat),
    (∀ i, i < n → f i = g i) → sum n f = sum n g
  | 0,     _, _, _ => rfl
  | (n+1), f, g, h => by
      simp only [sum]
      rw [sum_congr n f g (fun i hi => h i (Nat.lt_succ_of_lt hi)),
          h n (Nat.lt_succ_self n)]

theorem sum_mul_left : ∀ (c : Rat) (n : Nat) (f : Nat → Rat),
    c * sum n f = sum n (fun i => c * f i)
  | _, 0,     _ => by simp [sum]
  | c, (n+1), f => by simp only [sum, Rat.mul_add]; rw [sum_mul_left c n f]

theorem sum_mul_right : ∀ (c : Rat) (n : Nat) (f : Nat → Rat),
    sum n f * c = sum n (fun i => f i * c)
  | _, 0,     _ => by simp [sum]
  | c, (n+1), f => by simp only [sum, Rat.add_mul]; rw [sum_mul_right c n f]

def matmul (n : Nat) (A B : Mat) : Mat := fun i j => sum n (fun k => A i k * B k j)
def conj (s t : Nat → Rat) (A : Mat) : Mat := fun i j => t i * A i j * s j
def matsub (A B : Mat) : Mat := fun i j => A i j - B i j
def commutator (n : Nat) (A B : Mat) : Mat := matsub (matmul n A B) (matmul n B A)

/- ===================================================================
   Part 3.  Diagonal conjugation is an algebra homomorphism.
   `hst` is exactly invertibility of S on the index range.
   =================================================================== -/

theorem conj_mul (n : Nat) (s t : Nat → Rat) (hst : ∀ k, k < n → s k * t k = 1)
    (A B : Mat) (i j : Nat) :
    conj s t (matmul n A B) i j = matmul n (conj s t A) (conj s t B) i j := by
  show t i * sum n (fun k => A i k * B k j) * s j
     = sum n (fun k => (t i * A i k * s k) * (t k * B k j * s j))
  rw [sum_mul_left, sum_mul_right]
  apply sum_congr
  intro k hk
  have h : s k * t k = 1 := hst k hk
  calc t i * (A i k * B k j) * s j
      = (s k * t k) * (t i * (A i k * B k j) * s j) := by rw [h]; simp
    _ = (t i * A i k * s k) * (t k * B k j * s j)   := by ac_rfl

theorem conj_sub (s t : Nat → Rat) (A B : Mat) (i j : Nat) :
    conj s t (matsub A B) i j = matsub (conj s t A) (conj s t B) i j := by
  show t i * (A i j - B i j) * s j = t i * A i j * s j - t i * B i j * s j
  simp [Rat.sub_eq_add_neg, Rat.mul_add, Rat.add_mul, Rat.mul_neg, Rat.neg_mul]

/-- Similarity preserves commutators: the transport step. -/
theorem conj_commutator (n : Nat) (s t : Nat → Rat) (hst : ∀ k, k < n → s k * t k = 1)
    (A B : Mat) (i j : Nat) :
    conj s t (commutator n A B) i j
      = commutator n (conj s t A) (conj s t B) i j := by
  unfold commutator
  rw [conj_sub]
  show conj s t (matmul n A B) i j - conj s t (matmul n B A) i j
     = matmul n (conj s t A) (conj s t B) i j
       - matmul n (conj s t B) (conj s t A) i j
  rw [conj_mul n s t hst A B i j, conj_mul n s t hst B A i j]

/- ===================================================================
   Part 4.  The Jacobi matrices, and the all-entries similarity theorem.
   =================================================================== -/

/-- Symmetric tridiagonal B: diagonal aᵢ, both off-diagonals rᵢ. -/
def jacobiB (a r : Nat → Rat) : Mat := fun i j =>
  if i = j then a i else if j = i + 1 then r i else if i = j + 1 then r j else 0

/-- Rationalised B̃: diagonal aᵢ, upper cᵢ, lower 1. -/
def jacobiRat (a c : Nat → Rat) : Mat := fun i j =>
  if i = j then a i else if j = i + 1 then c i else if i = j + 1 then 1 else 0

/-- Every entry at once: S⁻¹ B S = B̃ on the index range, where
    S = diag(s), S⁻¹ = diag(t), s₀ = 1, sᵢ₊₁ = sᵢ rᵢ and rᵢ² = cᵢ. -/
theorem conj_jacobi_entry (n : Nat) (a r c s t : Nat → Rat)
    (hinv  : ∀ i, i < n → t i * s i = 1)
    (hrec  : ∀ i, i + 1 < n → s (i+1) = s i * r i)
    (hroot : ∀ i, i + 1 < n → r i * r i = c i)
    (i j : Nat) (hi : i < n) (hj : j < n) :
    conj s t (jacobiB a r) i j = jacobiRat a c i j := by
  show t i * (jacobiB a r i j) * s j = jacobiRat a c i j
  unfold jacobiB jacobiRat
  by_cases h1 : i = j
  · subst h1
    simp only [reduceIte]
    exact diagonal_entry (s i) (t i) (a i) (hinv i hi)
  · by_cases h2 : j = i + 1
    · subst h2
      simp only [h1, reduceIte]
      rw [hrec i hj]
      exact upper_entry (s i) (t i) (r i) (c i) (hinv i hi) (hroot i hj)
    · by_cases h3 : i = j + 1
      · subst h3
        simp only [h1, h2, reduceIte]
        exact lower_entry (s (j+1)) (t (j+1)) (s j) (r j) (hrec j hi) (hinv (j+1) hi)
      · simp only [h1, h2, h3, reduceIte]
        exact zero_entry (s j) (t i)

end E47Jacobi
