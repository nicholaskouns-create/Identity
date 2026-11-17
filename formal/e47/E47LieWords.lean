/- Free bracket words, similarity transport, and spanning from an explicit
   inverse.  Pure Lean 4, no Mathlib, no sorry.

   Three results, in order:
     ITEM 1  `Word` / `eval` : the free bracket word on two generators,
             evaluated into n x n rational matrices.
     ITEM 2  `conj_eval` : diagonal similarity transports EVERY iterated
             commutator, by structural induction on the word.  This is the
             induction whose base case is `conj_commutator`.
     ITEM 3  `spanning_from_inverse` : if the coordinate matrix of a family
             of words admits an explicit right inverse N, then every matrix X
             is the rational combination of the words with coefficients
             N . X.  No determinant theory and no dimension theory is used;
             the inverse witness does all the work.

   Still not proved here: the real-form conclusion Lie_R{-iD,-iB} = u(n),
   which needs complexification and finrank.  See E47RealForm.lean for the
   two obligations of that argument which ARE closed.
-/
namespace E47LieWords
instance : Std.Associative (α := Rat) (· * ·) := ⟨Rat.mul_assoc⟩
instance : Std.Commutative (α := Rat) (· * ·) := ⟨Rat.mul_comm⟩
instance : Std.Associative (α := Rat) (· + ·) := ⟨Rat.add_assoc⟩
instance : Std.Commutative (α := Rat) (· + ·) := ⟨Rat.add_comm⟩

def sum : Nat → (Nat → Rat) → Rat
  | 0, _ => 0
  | (n+1), f => sum n f + f n

theorem sum_congr : ∀ (n : Nat) (f g : Nat → Rat),
    (∀ i, i < n → f i = g i) → sum n f = sum n g
  | 0, _, _, _ => rfl
  | (n+1), f, g, h => by
      simp only [sum]
      rw [sum_congr n f g (fun i hi => h i (Nat.lt_succ_of_lt hi)), h n (Nat.lt_succ_self n)]

theorem sum_zero : ∀ n : Nat, sum n (fun _ => (0:Rat)) = 0
  | 0 => rfl
  | (n+1) => by simp only [sum, sum_zero n]; exact Rat.add_zero 0

theorem sum_add : ∀ (n : Nat) (f g : Nat → Rat),
    sum n (fun i => f i + g i) = sum n f + sum n g
  | 0, _, _ => (Rat.add_zero 0).symm
  | (n+1), f, g => by simp only [sum, sum_add n f g]; ac_rfl

theorem sum_mul_left : ∀ (c : Rat) (n : Nat) (f : Nat → Rat),
    c * sum n f = sum n (fun i => c * f i)
  | _, 0, _ => by simp [sum]
  | c, (n+1), f => by simp only [sum, Rat.mul_add]; rw [sum_mul_left c n f]

theorem sum_mul_right : ∀ (c : Rat) (n : Nat) (f : Nat → Rat),
    sum n f * c = sum n (fun i => f i * c)
  | _, 0, _ => by simp [sum]
  | c, (n+1), f => by simp only [sum, Rat.add_mul]; rw [sum_mul_right c n f]

theorem sum_swap : ∀ (a b : Nat) (f : Nat → Nat → Rat),
    sum a (fun i => sum b (fun j => f i j)) = sum b (fun j => sum a (fun i => f i j))
  | 0, b, f => by simp only [sum]; exact (sum_zero b).symm
  | (a+1), b, f => by
      simp only [sum]
      rw [sum_swap a b f, ← sum_add b (fun j => sum a (fun i => f i j)) (fun j => f a j)]

theorem sum_skip : ∀ (n i : Nat) (g : Nat → Rat), n ≤ i →
    sum n (fun p => if i = p then g p else 0) = 0
  | 0, _, _, _ => rfl
  | (n+1), i, g, h => by
      have hne : ¬ (i = n) := by omega
      simp only [sum, sum_skip n i g (by omega), hne, reduceIte]
      exact Rat.add_zero 0

theorem sum_delta : ∀ (n i : Nat) (g : Nat → Rat), i < n →
    sum n (fun p => if i = p then g p else 0) = g i
  | 0, _, _, h => absurd h (by omega)
  | (n+1), i, g, h => by
      by_cases hi : i = n
      · have h0 : sum n (fun p => if i = p then g p else 0) = 0 :=
          sum_skip n i g (Nat.le_of_eq hi.symm)
        simp only [sum]
        rw [h0]
        simp only [hi, reduceIte]
        exact Rat.zero_add (g n)
      · have hlt : i < n := by omega
        have h1 := sum_delta n i g hlt
        simp only [sum, h1, hi, reduceIte]
        exact Rat.add_zero (g i)


abbrev Mat := Nat → Nat → Rat
def matmul (n : Nat) (A B : Mat) : Mat := fun i j => sum n (fun k => A i k * B k j)
def conj (s t : Nat → Rat) (A : Mat) : Mat := fun i j => t i * A i j * s j
def matsub (A B : Mat) : Mat := fun i j => A i j - B i j
def commutator (n : Nat) (A B : Mat) : Mat := matsub (matmul n A B) (matmul n B A)

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

theorem conj_commutator (n : Nat) (s t : Nat → Rat) (hst : ∀ k, k < n → s k * t k = 1)
    (A B : Mat) (i j : Nat) :
    conj s t (commutator n A B) i j = commutator n (conj s t A) (conj s t B) i j := by
  unfold commutator
  rw [conj_sub]
  show conj s t (matmul n A B) i j - conj s t (matmul n B A) i j
     = matmul n (conj s t A) (conj s t B) i j - matmul n (conj s t B) (conj s t A) i j
  rw [conj_mul n s t hst A B i j, conj_mul n s t hst B A i j]

/-- ITEM 1: the free bracket word on two generators. -/
inductive Word where
  | gA : Word
  | gB : Word
  | br : Word → Word → Word

def eval (n : Nat) (A B : Mat) : Word → Mat
  | .gA => A
  | .gB => B
  | .br u v => commutator n (eval n A B u) (eval n A B v)

theorem conj_commutator' (n : Nat) (s t : Nat → Rat) (hst : ∀ k, k < n → s k * t k = 1)
    (A B : Mat) :
    conj s t (commutator n A B) = commutator n (conj s t A) (conj s t B) := by
  funext i j; exact conj_commutator n s t hst A B i j

/-- ITEM 2: similarity transports EVERY iterated commutator, by structural induction. -/
theorem conj_eval (n : Nat) (s t : Nat → Rat) (hst : ∀ k, k < n → s k * t k = 1)
    (A B : Mat) (w : Word) :
    conj s t (eval n A B w) = eval n (conj s t A) (conj s t B) w := by
  induction w with
  | gA => rfl
  | gB => rfl
  | br u v ihu ihv =>
      show conj s t (commutator n (eval n A B u) (eval n A B v))
         = commutator n (eval n (conj s t A) (conj s t B) u)
                        (eval n (conj s t A) (conj s t B) v)
      rw [conj_commutator' n s t hst, ihu, ihv]

def sum2 (a b : Nat) (f : Nat → Nat → Rat) : Rat := sum a (fun p => sum b (fun q => f p q))

theorem delta_row (n i j p : Nat) (X : Mat) (hj : j < n) :
    sum n (fun q => (if i = p then (if j = q then (1:Rat) else 0) else 0) * X p q)
      = if i = p then X p j else 0 := by
  by_cases h : i = p
  · simp only [h, reduceIte]
    rw [sum_congr n _ (fun q => if j = q then X p q else 0)
          (by intro q _; by_cases hq : j = q <;> simp [hq])]
    exact sum_delta n j (fun q => X p q) hj
  · simp only [h, reduceIte]
    rw [sum_congr n _ (fun _ => (0:Rat)) (by intro q _; simp)]
    exact sum_zero n

/-- ITEM 3: an explicit right inverse of the coordinate matrix makes the words span.
    `hMN` is `M N = I` written without flattening: row (i,j), column (p,q). -/
theorem spanning_from_inverse (n m : Nat) (W : Nat → Mat) (N : Nat → Nat → Nat → Rat)
    (hMN : ∀ i j p q, sum m (fun k => N k p q * W k i j)
             = (if i = p then (if j = q then (1:Rat) else 0) else 0))
    (X : Mat) (i j : Nat) (hi : i < n) (hj : j < n) :
    sum m (fun k => sum2 n n (fun p q => N k p q * X p q) * W k i j) = X i j := by
  have stepA : ∀ k, sum2 n n (fun p q => N k p q * X p q) * W k i j
      = sum n (fun p => sum n (fun q => N k p q * X p q * W k i j)) := by
    intro k
    show sum n (fun p => sum n (fun q => N k p q * X p q)) * W k i j = _
    rw [sum_mul_right]
    exact sum_congr n _ _ (fun p _ => sum_mul_right (W k i j) n _)
  calc sum m (fun k => sum2 n n (fun p q => N k p q * X p q) * W k i j)
      = sum m (fun k => sum n (fun p => sum n (fun q => N k p q * X p q * W k i j))) :=
        sum_congr m _ _ (fun k _ => stepA k)
    _ = sum n (fun p => sum m (fun k => sum n (fun q => N k p q * X p q * W k i j))) :=
        sum_swap m n (fun k p => sum n (fun q => N k p q * X p q * W k i j))
    _ = sum n (fun p => sum n (fun q => sum m (fun k => N k p q * X p q * W k i j))) :=
        sum_congr n _ _ (fun p _ =>
          sum_swap m n (fun k q => N k p q * X p q * W k i j))
    _ = sum n (fun p => sum n (fun q =>
          (if i = p then (if j = q then (1:Rat) else 0) else 0) * X p q)) := by
        apply sum_congr; intro p _
        apply sum_congr; intro q _
        rw [sum_congr m _ (fun k => (N k p q * W k i j) * X p q) (by intro k _; ac_rfl)]
        rw [← sum_mul_right, hMN]
    _ = sum n (fun p => if i = p then X p j else 0) :=
        sum_congr n _ _ (fun p _ => delta_row n i j p X hj)
    _ = X i j := sum_delta n i (fun p => X p j) hi

end E47LieWords
