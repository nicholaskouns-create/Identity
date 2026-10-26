/-
  Odds contraction for the E47 filter Gamma = I - K^2/99144.
  Self-contained: core Lean 4 only, no Mathlib, no declared axioms, no sorry.
  Companion to E47OddsContraction.v (same statements, integers only).
  `#print axioms` at the end of the file: the pure-`decide` theorems use none;
  odds_one_step, equality_case_12/42 and odds_bound_on_example use Lean's
  built-in propext and Quot.sound; odds_k_steps additionally uses
  Classical.choice (via core `simp`/`omega`). No axiom is declared here.

  WHAT IS FORMALIZED HERE
  Model: the diagonal (Hermitian) eigenbasis picture. The Casimir levels are
  c in {0,2,6,12,20,30,42}; the kernel levels of K = (C-6)(C-30) are {6,30};
  Gamma acts on the level-c eigenspace as the scalar g(c) = 1 - K(c)^2/99144,
  K(c) = (c-6)(c-30). Write D = 99144 and num(c) = D - K(c)^2, so g = num/D.
  A "state" is a function giving, per level c, the squared-norm mass m_c >= 0.
  One Gamma step multiplies the mass at level c by g(c)^2 = num(c)^2 / D^2.
  To stay in integers the step is stored UNSCALED: `step m c = num(c)^2 * m c`,
  and the true mass after k steps is `iter k m c / D^(2k)` (one common
  denominator for every level, so ratios of masses are unaffected).
  Define in := m_6 + m_30 and out := m_0 + m_2 + m_12 + m_20 + m_42.
  Proved, in exact integer arithmetic:
  (1) g(6) = g(30) = 1: num(6) = num(30) = D (Gamma is the identity on E47).
  (2) For each off-kernel level c: 289 * num(c)^2 <= 225 * D^2, i.e.
      g(c)^2 <= 225/289 = (15/17)^2. Equality exactly at c = 12 and c = 42
      (17*num(12) = 15*D, 17*num(42) = -15*D, so |g| = 15/17), strict at
      c = 0, 2, 20. Note 289/225 = (17/15)^2.
  (3) One step: in' = D^2 * in and 289 * out' <= 225 * D^2 * out; hence the
      cross-multiplied odds bound 289 * out' * in <= 225 * out * in'.
      k steps: 289^k * out_k * in_0 <= 225^k * out_0 * in_k, where
      in_k = D^(2k) * in_0 and out_k, in_k carry the same scale D^(2k). Since
      the odds R/(1-R) with R = out/(in+out) equal out/in, this says
      odds_k <= odds_0 * (225/289)^k, stated and proved in cross-multiplied
      integer form. (The identity R/(1-R) = out/in itself is proved in the Coq
      companion over Q; this Lean file does not restate it, because core Lean
      has no rational-field tactics.)
      Equality case: mass only at c = 12 (or only at c = 42) plus kernel mass
      gives 289 * out' = 225 * D^2 * out.
  (4) Concrete counterexample to the NAIVE bound R_1 <= R_0 * (225/289):
      kernel mass 1 at c = 6, off-kernel mass 100 at c = 12. Then
      289 * out' * (in + out) > 225 * out * (in' + out') in integers, i.e. the
      naive bound on R fails at k = 1, while the odds bound (3) holds.

  WHAT IS NOT FORMALIZED
  * This is a theorem about the diagonal eigenbasis model (Hermitian form,
    Gamma diagonal with the eigenvalues above, masses as squared norms of the
    components in each Casimir eigenspace). The link from the 125x125 integer
    matrix model to that Hermitian form (diagonal rescaling making the model
    orthogonal, spectral decomposition, the identification of squared norms
    with level masses) is NOT formalized here.
  * Masses are nonnegative integers (or rationals after a common scaling).
    States are arbitrary nonnegative level masses; no particular vector in the
    125-dimensional space is constructed.
-/

namespace OddsContraction

def K (c : Int) : Int := (c - 6) * (c - 30)
def D : Int := 99144
/-- Gamma eigenvalue at Casimir level c is `num c / D`. -/
def num (c : Int) : Int := D - K c * K c

def offLevels : List Int := [0, 2, 12, 20, 42]

/-- 289/225 = (17/15)^2 -/
theorem ratio_squares : (289 : Int) = 17 * 17 ∧ (225 : Int) = 15 * 15 := by decide

/-! ### (1) identity on E47 -/

theorem num_kernel : num 6 = D ∧ num 30 = D := by decide

theorem num_values :
    num 0 = 66744 ∧ num 2 = 86600 ∧ num 12 = 87480 ∧ num 20 = 79544 ∧ num 42 = -87480 := by
  decide

/-! ### (2) contraction off the kernel -/

theorem off_contraction :
    ∀ c ∈ offLevels, 289 * (num c * num c) ≤ 225 * (D * D) := by decide

theorem off_equality_iff :
    ∀ c ∈ offLevels, (289 * (num c * num c) = 225 * (D * D) ↔ (c = 12 ∨ c = 42)) := by
  decide

theorem off_strict :
    ∀ c ∈ offLevels, c ≠ 12 → c ≠ 42 → 289 * (num c * num c) < 225 * (D * D) := by
  decide

theorem abs_ratio_fifteen_seventeenths :
    17 * num 12 = 15 * D ∧ 17 * num 42 = -(15 * D) := by decide

/-! ### (3) vector level: diagonal eigenbasis model -/

abbrev Mass := Int → Int
def Nonneg (m : Mass) : Prop := ∀ c, 0 ≤ m c

/-- Unscaled Gamma step on squared-norm masses: true mass = this / D^2. -/
def step (m : Mass) : Mass := fun c => num c * num c * m c

def inm (m : Mass) : Int := m 6 + m 30
def outm (m : Mass) : Int := m 0 + m 2 + m 12 + m 20 + m 42

theorem sq_nonneg' (x : Int) : 0 ≤ x * x := by
  rcases Int.le_total 0 x with h | h
  · exact Int.mul_nonneg h h
  · have := Int.mul_nonneg (Int.neg_nonneg_of_nonpos h) (Int.neg_nonneg_of_nonpos h)
    rwa [Int.neg_mul_neg] at this

theorem step_nonneg (m : Mass) (h : Nonneg m) : Nonneg (step m) := by
  intro c
  unfold step
  exact Int.mul_nonneg (sq_nonneg' _) (h c)

theorem step_in (m : Mass) : inm (step m) = D * D * inm m := by
  unfold inm step
  have h6 : num 6 = D := num_kernel.1
  have h30 : num 30 = D := num_kernel.2
  rw [h6, h30, Int.mul_add]

theorem step_out (m : Mass) (h : Nonneg m) :
    289 * outm (step m) ≤ 225 * (D * D) * outm m := by
  unfold outm step
  obtain ⟨n0, n2, n12, n20, n42⟩ := num_values
  rw [n0, n2, n12, n20, n42]
  have h0 := h 0
  have h2 := h 2
  have h12 := h 12
  have h20 := h 20
  have h42 := h 42
  unfold D
  omega

/-- One step, cross-multiplied odds bound: 289 * out' * in <= 225 * out * in'. -/
theorem odds_one_step (m : Mass) (h : Nonneg m) :
    289 * outm (step m) * inm m ≤ 225 * outm m * inm (step m) := by
  have h1 := step_out m h
  have hin : 0 ≤ inm m := by
    have := h 6
    have := h 30
    unfold inm
    omega
  rw [step_in]
  have h2 := Int.mul_le_mul_of_nonneg_right h1 hin
  calc 289 * outm (step m) * inm m
      = (289 * outm (step m)) * inm m := rfl
    _ ≤ (225 * (D * D) * outm m) * inm m := h2
    _ = 225 * outm m * (D * D * inm m) := by
        simp only [Int.mul_assoc, Int.mul_comm, Int.mul_left_comm]

def iter : Nat → Mass → Mass
  | 0, m => m
  | k + 1, m => step (iter k m)

theorem iter_nonneg (k : Nat) (m : Mass) (h : Nonneg m) : Nonneg (iter k m) := by
  induction k with
  | zero => exact h
  | succ k ih => exact step_nonneg _ ih

theorem iter_in (k : Nat) (m : Mass) : inm (iter k m) = (D * D) ^ k * inm m := by
  induction k with
  | zero => simp [iter]
  | succ k ih =>
    show inm (step (iter k m)) = _
    rw [step_in, ih, Int.pow_succ]
    simp only [Int.mul_assoc, Int.mul_comm]

/-- k steps, unscaled out_k: 289^k * out_k <= 225^k * D^(2k) * out_0. -/
theorem iter_out (k : Nat) (m : Mass) (h : Nonneg m) :
    289 ^ k * outm (iter k m) ≤ 225 ^ k * (D * D) ^ k * outm m := by
  induction k with
  | zero => simp [iter]
  | succ k ih =>
    show 289 ^ (k + 1) * outm (step (iter k m)) ≤ _
    have hs := step_out (iter k m) (iter_nonneg k m h)
    have p289 : (0 : Int) ≤ 289 ^ k := Int.pow_nonneg (by decide)
    have p225 : (0 : Int) ≤ 225 * (D * D) := by unfold D; decide
    have h1 := Int.mul_le_mul_of_nonneg_left hs p289
    have h2 := Int.mul_le_mul_of_nonneg_left ih p225
    calc 289 ^ (k + 1) * outm (step (iter k m))
        = 289 ^ k * (289 * outm (step (iter k m))) := by
          rw [Int.pow_succ]; simp only [Int.mul_assoc, Int.mul_comm]
      _ ≤ 289 ^ k * (225 * (D * D) * outm (iter k m)) := h1
      _ = 225 * (D * D) * (289 ^ k * outm (iter k m)) := by
          simp only [Int.mul_assoc, Int.mul_comm, Int.mul_left_comm]
      _ ≤ 225 * (D * D) * (225 ^ k * (D * D) ^ k * outm m) := h2
      _ = 225 ^ (k + 1) * (D * D) ^ (k + 1) * outm m := by
          rw [Int.pow_succ, Int.pow_succ]
          simp only [Int.mul_assoc, Int.mul_comm, Int.mul_left_comm]

/-- k steps, cross-multiplied odds bound:
    289^k * out_k * in_0 <= 225^k * out_0 * in_k, with in_k = D^(2k) * in_0. -/
theorem odds_k_steps (k : Nat) (m : Mass) (h : Nonneg m) :
    289 ^ k * outm (iter k m) * inm m ≤ 225 ^ k * outm m * inm (iter k m) := by
  rw [iter_in]
  have hin : 0 ≤ inm m := by
    have := h 6
    have := h 30
    unfold inm
    omega
  have h2 := Int.mul_le_mul_of_nonneg_right (iter_out k m h) hin
  calc 289 ^ k * outm (iter k m) * inm m
      ≤ 225 ^ k * (D * D) ^ k * outm m * inm m := h2
    _ = 225 ^ k * outm m * ((D * D) ^ k * inm m) := by
        simp only [Int.mul_assoc, Int.mul_comm, Int.mul_left_comm]

/-- Equality case: mass only at c = 12 (plus kernel mass). -/
theorem equality_case_12 (m : Mass) (h0 : m 0 = 0) (h2 : m 2 = 0) (h20 : m 20 = 0)
    (h42 : m 42 = 0) :
    289 * outm (step m) = 225 * (D * D) * outm m := by
  unfold outm step
  obtain ⟨n0, n2, n12, n20, n42⟩ := num_values
  rw [n0, n2, n12, n20, n42, h0, h2, h20, h42]
  unfold D
  omega

/-- Equality case: mass only at c = 42 (plus kernel mass). -/
theorem equality_case_42 (m : Mass) (h0 : m 0 = 0) (h2 : m 2 = 0) (h12 : m 12 = 0)
    (h20 : m 20 = 0) :
    289 * outm (step m) = 225 * (D * D) * outm m := by
  unfold outm step
  obtain ⟨n0, n2, n12, n20, n42⟩ := num_values
  rw [n0, n2, n12, n20, n42, h0, h2, h12, h20]
  unfold D
  omega

/-! ### (4) the naive bound on R fails -/

/-- kernel mass 1 at c = 6, off-kernel mass 100 at c = 12 -/
def mEx : Mass := fun c => if c = 6 then 1 else if c = 12 then 100 else 0

theorem mEx_nonneg : Nonneg mEx := by
  intro c
  unfold mEx
  split <;> (try split) <;> omega

/-- R_1 > R_0 * (225/289), cross-multiplied with positive denominators:
    R_1 = out'/(in'+out'), R_0 = out/(in+out); the claim is
    289 * out' * (in+out) > 225 * out * (in'+out'). -/
theorem naive_bound_fails :
    inm mEx = 1 ∧ outm mEx = 100 ∧
    225 * outm mEx * (inm (step mEx) + outm (step mEx))
      < 289 * outm (step mEx) * (inm mEx + outm mEx) := by
  decide

/-- ... while the odds bound holds on the same state. -/
theorem odds_bound_on_example :
    289 * outm (step mEx) * inm mEx ≤ 225 * outm mEx * inm (step mEx) :=
  odds_one_step mEx mEx_nonneg

end OddsContraction

#print axioms OddsContraction.num_kernel
#print axioms OddsContraction.off_contraction
#print axioms OddsContraction.off_equality_iff
#print axioms OddsContraction.off_strict
#print axioms OddsContraction.abs_ratio_fifteen_seventeenths
#print axioms OddsContraction.odds_one_step
#print axioms OddsContraction.odds_k_steps
#print axioms OddsContraction.equality_case_12
#print axioms OddsContraction.equality_case_42
#print axioms OddsContraction.naive_bound_fails
#print axioms OddsContraction.odds_bound_on_example
