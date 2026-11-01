/-
  Fibonacci-Lucas tower meets the E47 kernel blocks.
  Self-contained: core Lean 4 only, no Mathlib, no declared axioms, no sorry.
  Companion to E47TowerKernel.v (same statements). It re-states the Fibonacci
  and Lucas definitions of TowerIdentity.v and the weight-counting definitions
  of E47WeightAlgebra.lean, unchanged, so it compiles on its own with `lean`.
  `#print axioms` at the end of the file reports no axioms for the computed
  facts (n = 5 values, kernel blocks, multiplicities, rank, bounded
  uniqueness). The general-n theorems (tower_spin_identity, fib_luc_shift_odd,
  tower_identity_n5, shift_identity_m3) use Lean's three built-in axioms
  propext, Classical.choice and Quot.sound, through core `grind`/`omega`. No
  axiom is declared here.

  WHAT IS FORMALIZED HERE
  * fib, luc as in TowerIdentity.v, and the general induction theorem
    L_n^2 - 5 F_n^2 = -4 for odd n, giving J(J+1) = 5 j(j+1) whenever
    2j+1 = F_n and 2J+1 = L_n with n odd (all odd n).
  * At n = 5: F_5 = 5, L_5 = 11, F_3 = 2, so j = (F_5-1)/2 = 2 and
    J = (L_5-1)/2 = 5, and J(J+1) = 30 = 5 * 6 = 5 j(j+1).
  * The kernel rank identity 47 = F_5*F_5 + F_3*L_5 = 25 + 22, and
    D(n) = F_n^2 + F_{n-2} L_n evaluates to 47 at n = 5.
  * The tower spins j = 2, J = 5 are exactly the kernel blocks of the weight
    algebra (the filter of lam = 0 over spins 0..6 is [2, 5]); mult 2 = 5 = F_5,
    mult 5 = 2 = F_3; block dimensions 2j+1 = F_5 = 5 and 2J+1 = L_5 = 11; the
    Casimir values 6 and 30 = 5*6 are the two roots of K = (C-6)(C-30).
  * A general identity for all odd m: F_m * L_{m+2} = F_{m+1} * L_{m+1} + 1
    (for even m the sign is -1). At m = 3 this is 22 = 21 + 1.
  * Bounded uniqueness: for n = 0..30 the only n for which 2j+1 = F_n,
    2J+1 = L_n have integer (floor-half) solutions with both lam(j(j+1)) and
    lam(J(J+1)) vanishing is n = 5. This is a finite check, not a proof for
    all n.

  WHAT IS NOT FORMALIZED
  * The 125-by-125 matrices are not defined in this file. "Kernel blocks" means
    the scalar function lam on Casimir values j(j+1), as in E47WeightAlgebra.
    The sl2 facts that spin-j summands number w(j) - w(j+1) and that C acts as
    j(j+1) on them are textbook input stated in E47WeightAlgebra, not proved here.
  * Nothing says why tower index n = 5 should be physically selected. It is a
    numerical coincidence that is now machine-checked, not a theorem that the
    kernel must come from the tower.
  * D(n) = 47 is a computation at n = 5 only; D(n) is not claimed to be the
    kernel rank for other n.
-/

namespace TowerKernel

set_option maxRecDepth 100000

/-! ### Fibonacci and Lucas (as in TowerIdentity.v) -/

def fib : Nat → Int
  | 0 => 0
  | 1 => 1
  | n + 2 => fib (n + 1) + fib n

def luc : Nat → Int
  | 0 => 2
  | 1 => 1
  | n + 2 => luc (n + 1) + luc n

/-- (-1)^n as an Int. -/
def sgn : Nat → Int
  | 0 => 1
  | n + 1 => - sgn n

theorem fib_succ_succ (n : Nat) : fib (n + 2) = fib (n + 1) + fib n := rfl
theorem luc_succ_succ (n : Nat) : luc (n + 2) = luc (n + 1) + luc n := rfl

theorem sgn_parity (n : Nat) :
    (n % 2 = 0 → sgn n = 1) ∧ (n % 2 = 1 → sgn n = -1) := by
  induction n with
  | zero => decide
  | succ n ih =>
    have hs : sgn (n + 1) = - sgn n := rfl
    obtain ⟨h0, h1⟩ := ih
    constructor <;> intro h <;> omega

theorem invariants (n : Nat) :
    luc n * luc n - 5 * (fib n * fib n) = 4 * sgn n ∧
    luc (n + 1) * luc (n + 1) - 5 * (fib (n + 1) * fib (n + 1)) = -4 * sgn n ∧
    luc n * luc (n + 1) - 5 * (fib n * fib (n + 1)) = 2 * sgn n := by
  induction n with
  | zero => decide
  | succ n ih =>
    obtain ⟨h0, h1, h2⟩ := ih
    have hs : sgn (n + 1) = - sgn n := rfl
    rw [hs, luc_succ_succ, fib_succ_succ]
    refine ⟨?_, ?_, ?_⟩ <;> grind

theorem lucas_fibonacci_odd (n : Nat) (hodd : n % 2 = 1) :
    luc n * luc n - 5 * (fib n * fib n) = -4 := by
  have h := (invariants n).1
  have hs := (sgn_parity n).2 hodd
  rw [hs] at h
  omega

theorem tower_spin_identity (n : Nat) (j J : Int) (hodd : n % 2 = 1)
    (hj : 2 * j + 1 = fib n) (hJ : 2 * J + 1 = luc n) :
    J * (J + 1) = 5 * (j * (j + 1)) := by
  have h := lucas_fibonacci_odd n hodd
  rw [← hj, ← hJ] at h
  grind

/-- F_{m+1} L_{m+1} - F_m L_{m+2} = (-1)^m, for every m. -/
theorem pair_defect (m : Nat) :
    fib (m + 1) * luc (m + 1) - fib m * luc (m + 2) = sgn m := by
  induction m with
  | zero => decide
  | succ m ih =>
    have hs : sgn (m + 1) = - sgn m := rfl
    rw [hs, luc_succ_succ (m + 1), fib_succ_succ m, luc_succ_succ m] at *
    grind

/-- For odd m: F_m * L_{m+2} = F_{m+1} * L_{m+1} + 1. -/
theorem fib_luc_shift_odd (m : Nat) (hodd : m % 2 = 1) :
    fib m * luc (m + 2) = fib (m + 1) * luc (m + 1) + 1 := by
  have h := pair_defect m
  have hs := (sgn_parity m).2 hodd
  rw [hs] at h
  omega

/-! ### Weight algebra (as in E47WeightAlgebra.lean) -/

def vals : List Int := [-2, -1, 0, 1, 2]

def triples : List (Int × Int × Int) :=
  vals.flatMap fun a => vals.flatMap fun b => vals.map fun c => (a, b, c)

def w (m : Int) : Nat :=
  triples.countP fun t => decide (t.1 + t.2.1 + t.2.2 = m)

def mult (j : Nat) : Nat := w j - w (j + 1)

def casimir (j : Nat) : Nat := j * (j + 1)

def lam (c : Int) : Int := (c - 6) * (c - 30)

def kernelDim : Nat :=
  (((List.range 7).filter fun j => decide (lam (casimir j : Nat) = 0)).map
    fun j => mult j * (2 * j + 1)).sum

theorem multiplicities : (List.range 7).map mult = [1, 3, 5, 4, 3, 2, 1] := by decide

theorem kernel_blocks_are_spin2_spin5 :
    (List.range 7).filter (fun j => decide (lam (casimir j : Nat) = 0)) = [2, 5] := by
  decide

theorem kernel_dim_from_blocks : kernelDim = 47 := by decide

theorem kernel_rank_from_weights : (w 2 - w 3) * 5 + (w 5 - w 6) * 11 = 47 := by decide

/-! ### The link -/

theorem fib_5 : fib 5 = 5 := by decide
theorem luc_5 : luc 5 = 11 := by decide
theorem fib_3 : fib 3 = 2 := by decide
theorem luc_3 : luc 3 = 4 := by decide

def tower_j (n : Nat) : Int := (fib n - 1) / 2
def tower_J (n : Nat) : Int := (luc n - 1) / 2

theorem tower_spins_n5 : tower_j 5 = 2 ∧ tower_J 5 = 5 := by decide

theorem tower_exact_n5 :
    2 * tower_j 5 + 1 = fib 5 ∧ 2 * tower_J 5 + 1 = luc 5 := by decide

/-- J(J+1) = 5 j(j+1), from the general tower theorem at n = 5. -/
theorem tower_identity_n5 :
    tower_J 5 * (tower_J 5 + 1) = 5 * (tower_j 5 * (tower_j 5 + 1)) :=
  tower_spin_identity 5 (tower_j 5) (tower_J 5) (by decide)
    tower_exact_n5.1 tower_exact_n5.2

theorem tower_casimirs_n5 :
    tower_j 5 * (tower_j 5 + 1) = 6 ∧ tower_J 5 * (tower_J 5 + 1) = 30 := by decide

theorem thirty_is_five_times_six : (30 : Int) = 5 * 6 := by decide

/-- The two Casimir values of the tower are the two roots of K = (C-6)(C-30). -/
theorem tower_casimirs_are_kernel_roots :
    lam (tower_j 5 * (tower_j 5 + 1)) = 0 ∧ lam (tower_J 5 * (tower_J 5 + 1)) = 0 := by
  decide

/-- Kernel rank: 47 = F_5*F_5 + F_3*L_5 = 25 + 22. -/
theorem kernel_rank_from_tower : fib 5 * fib 5 + fib 3 * luc 5 = 47 := by decide

theorem kernel_rank_split : fib 5 * fib 5 = 25 ∧ fib 3 * luc 5 = 22 := by decide

def D (n : Nat) : Int := fib n * fib n + fib (n - 2) * luc n

theorem D_5 : D 5 = 47 := by decide

/-- The tower spins are exactly the kernel blocks of the weight algebra. -/
theorem tower_spins_are_kernel_blocks :
    (List.range 7).filter (fun j => decide (lam (casimir j : Nat) = 0))
      = [(tower_j 5).toNat, (tower_J 5).toNat] := by
  decide

/-- mult 2 = F_5 and mult 5 = F_3. -/
theorem multiplicities_are_fibonacci :
    (mult (tower_j 5).toNat : Int) = fib 5 ∧ (mult (tower_J 5).toNat : Int) = fib 3 := by
  decide

/-- Block dimensions: 2j+1 = F_5 and 2J+1 = L_5. -/
theorem block_dimensions_are_fib_luc :
    2 * tower_j 5 + 1 = fib 5 ∧ 2 * tower_J 5 + 1 = luc 5 := tower_exact_n5

/-- Kernel rank computed from the weight algebra equals D(5). -/
theorem kernel_dim_is_D5 : (kernelDim : Int) = D 5 := by decide

/-- Term by term: multiplicity * block dimension = F * (F or L). -/
theorem kernel_terms_match :
    ((mult 2 * (2 * 2 + 1) : Nat) : Int) = fib 5 * fib 5 ∧
    ((mult 5 * (2 * 5 + 1) : Nat) : Int) = fib 3 * luc 5 := by
  decide

/-- The general odd-m identity at m = 3 behind F_3 * L_5 = 22. -/
theorem shift_identity_m3 : fib 3 * luc 5 = fib 4 * luc 4 + 1 :=
  fib_luc_shift_odd 3 (by decide)

/-- Bounded uniqueness among n = 0..30 (a finite check, not a proof for all n). -/
def both_kernel (n : Nat) : Bool :=
  decide (2 * tower_j n + 1 = fib n) &&
  decide (2 * tower_J n + 1 = luc n) &&
  decide (lam (tower_j n * (tower_j n + 1)) = 0) &&
  decide (lam (tower_J n * (tower_J n + 1)) = 0)

theorem only_n5_below_31 : (List.range 31).filter both_kernel = [5] := by decide

end TowerKernel

#print axioms TowerKernel.tower_spin_identity
#print axioms TowerKernel.fib_luc_shift_odd
#print axioms TowerKernel.tower_identity_n5
#print axioms TowerKernel.tower_casimirs_are_kernel_roots
#print axioms TowerKernel.kernel_rank_from_tower
#print axioms TowerKernel.D_5
#print axioms TowerKernel.tower_spins_are_kernel_blocks
#print axioms TowerKernel.multiplicities_are_fibonacci
#print axioms TowerKernel.block_dimensions_are_fib_luc
#print axioms TowerKernel.kernel_dim_is_D5
#print axioms TowerKernel.kernel_terms_match
#print axioms TowerKernel.shift_identity_m3
#print axioms TowerKernel.only_n5_below_31
