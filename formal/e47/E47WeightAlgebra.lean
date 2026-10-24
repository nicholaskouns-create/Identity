/-
  Weight-counting algebra behind the E47 spectral certificate.
  Self-contained: core Lean 4 only, no Mathlib, no declared axioms, no sorry.
  `#print axioms` at the end of the file reports no axioms for every checked
  theorem except two: lam_zero_iff uses Lean's built-in propext (via core Int
  lemmas), and pr_expanded (proved by core `grind`) uses Lean's three standard
  axioms propext, Classical.choice and Quot.sound. No axiom is declared here.

  WHAT IS FORMALIZED HERE
  * The carrier basis of H = V_2 (x) V_2 (x) V_2 is the set of triples (a,b,c)
    with a,b,c in {-2,..,2}. Total Jz is diagonal on this basis with eigenvalue
    a+b+c. `w m` is the number of basis triples with a+b+c = m.
  * w(0..6) = 19,18,15,10,6,3,1, w is symmetric, w vanishes outside -6..6, and
    the basis has 125 elements.
  * Multiplicity of spin j is defined as `mult j = w j - w (j+1)`. It evaluates
    to 1,3,5,4,3,2,1. The truncated Nat subtraction is justified by a proved
    monotonicity fact (w (j+1) <= w j for j <= 6).
  * The multiplicities reproduce the weight spectrum: w m = sum_{j >= |m|} mult j
    for every m in -6..6, and sum_j mult j * (2j+1) = 125.
  * For K = (C-6)(C-30) acting as the scalar lam(j(j+1)) on a spin-j block:
    lam(j(j+1)) = 0 iff j = 2 or j = 5, for ALL natural j.
  * kernel_rank_from_weights: (w 2 - w 3)*5 + (w 5 - w 6)*11 = 47.
  * The Gamma = I - K^2/99144 contraction numbers, computed from the above.
  * Scalar identities on the Casimir spectrum for the degree-six polynomial
    pr(x) = x(x-2)(x-12)(x-20)(x-31)(x-42): pr(c) = 0 at the nodes 0,2,12,20,42,
    pr(6) = pr(30) = 1814400 = 10!/2, and pr has the coefficients
    [1,-107,4088,-66940,430848,-624960,0] (checked for every integer x).
    So P = pr(C)/1814400 takes the value 1 on spin 2 and spin 5 blocks and 0 on
    the others, as a polynomial in the scalar C-value.

  WHAT IS NOT FORMALIZED
  * The 125-by-125 matrices Jx, Jy, Jz, C, K are not defined in this file, and
    nothing here is a theorem about those operators.
  * The following standard sl2 facts are taken as textbook input and appear only
    in this comment, not as axioms: (i) every finite-dimensional sl2 module
    splits into irreducible ladders, so the number of spin-j summands equals
    dim(weight j) - dim(weight j+1); (ii) the Casimir C = Jx^2+Jy^2+Jz^2 acts as
    j(j+1) on a spin-j summand. Given those two facts, the numbers proved here
    are exactly the multiplicities, the dimensions and the kernel rank. The
    matrices themselves are checked numerically in simulation/e47_tqgnn/.
-/

namespace WeightAlgebra

def vals : List Int := [-2, -1, 0, 1, 2]

set_option maxRecDepth 100000

/-- The weight window -6..6. -/
def window : List Int := (List.range 13).map fun (i : Nat) => (i : Int) - 6

/-- Basis of the carrier: m-values of the three spin-2 factors. -/
def triples : List (Int × Int × Int) :=
  vals.flatMap fun a => vals.flatMap fun b => vals.map fun c => (a, b, c)

/-- Weight count: number of basis triples with total Jz = m. -/
def w (m : Int) : Nat :=
  triples.countP fun t => decide (t.1 + t.2.1 + t.2.2 = m)

/-- Highest-weight multiplicity of spin j. -/
def mult (j : Nat) : Nat := w j - w (j + 1)

def casimir (j : Nat) : Nat := j * (j + 1)

def lam (c : Int) : Int := (c - 6) * (c - 30)

def gap (c : Int) : Nat := (99144 - lam c * lam c).natAbs

/-! ### 1. Weight counts -/

theorem basis_size : triples.length = 125 := by decide

theorem weight_counts :
    w 0 = 19 ∧ w 1 = 18 ∧ w 2 = 15 ∧ w 3 = 10 ∧ w 4 = 6 ∧ w 5 = 3 ∧ w 6 = 1 := by
  decide

theorem weight_symmetric :
    ∀ m ∈ window, w (-m) = w m := by
  decide

theorem weight_vanishes_outside : w 7 = 0 ∧ w (-7) = 0 := by decide

theorem weight_total :
    (window.map w).sum = 125 := by
  decide

/-- Every triple has total weight in -6..6, so no weight outside that window
    is missed by `weight_total`. -/
theorem weight_window :
    ∀ t ∈ triples, -6 ≤ t.1 + t.2.1 + t.2.2 ∧ t.1 + t.2.1 + t.2.2 ≤ 6 := by
  decide

/-! ### 2. Multiplicities -/

theorem weight_antitone :
    ∀ j ∈ List.range 7, w ((j : Int) + 1) ≤ w j := by
  decide

theorem multiplicities :
    (List.range 7).map mult = [1, 3, 5, 4, 3, 2, 1] := by
  decide

theorem dimension_identity :
    ((List.range 7).map fun j => mult j * (2 * j + 1)).sum = 125 := by
  decide

/-- The multiplicities reproduce the weight spectrum:
    w m = sum over spins j >= |m| of mult j. -/
def tailSum (m : Int) : Nat :=
  (((List.range 7).filter fun j => m.natAbs ≤ j).map mult).sum

theorem multiplicities_reproduce_weights :
    ∀ m ∈ window, w m = tailSum m := by
  decide

/-! ### 3. Casimir and kernel -/

theorem casimir_values :
    (List.range 7).map casimir = [0, 2, 6, 12, 20, 30, 42] := by decide

theorem lam_zero_on_range :
    ∀ j ∈ List.range 7, lam (casimir j : Nat) = 0 ↔ (j = 2 ∨ j = 5) := by
  decide

theorem casimir_ge_of_ge (j k : Nat) (h : k ≤ j) : k * (k + 1) ≤ j * (j + 1) :=
  Nat.mul_le_mul h (Nat.succ_le_succ h)

/-- For every natural j, (c-6)(c-30) = 0 with c = j(j+1) forces j = 2 or j = 5. -/
theorem lam_zero_iff (j : Nat) : lam ((casimir j : Nat) : Int) = 0 ↔ (j = 2 ∨ j = 5) := by
  constructor
  · intro h
    unfold lam at h
    rcases Int.mul_eq_zero.mp h with h6 | h30
    · have h6' : casimir j = 6 := Int.ofNat.inj (Int.sub_eq_zero.mp h6)
      match j, h6' with
      | 0, h' => exact absurd h' (by decide)
      | 1, h' => exact absurd h' (by decide)
      | 2, _ => exact Or.inl rfl
      | k + 3, h' =>
        have h3 : 3 * (3 + 1) ≤ casimir (k + 3) :=
          casimir_ge_of_ge (k + 3) 3 (Nat.le_add_left 3 k)
        rw [h'] at h3
        exact absurd h3 (by decide)
    · have h30' : casimir j = 30 := Int.ofNat.inj (Int.sub_eq_zero.mp h30)
      match j, h30' with
      | 0, h' => exact absurd h' (by decide)
      | 1, h' => exact absurd h' (by decide)
      | 2, h' => exact absurd h' (by decide)
      | 3, h' => exact absurd h' (by decide)
      | 4, h' => exact absurd h' (by decide)
      | 5, _ => exact Or.inr rfl
      | k + 6, h' =>
        have h6 : 6 * (6 + 1) ≤ casimir (k + 6) :=
          casimir_ge_of_ge (k + 6) 6 (Nat.le_add_left 6 k)
        rw [h'] at h6
        exact absurd h6 (by decide)
  · rintro (rfl | rfl) <;> decide

/-- Kernel rank, derived from the weight counts and not from stored multiplicities. -/
theorem kernel_rank_from_weights : (w 2 - w 3) * 5 + (w 5 - w 6) * 11 = 47 := by
  decide

/-- Same number, as the sum of block dimensions over spins where lam vanishes. -/
def kernelDim : Nat :=
  (((List.range 7).filter fun j => decide (lam (casimir j : Nat) = 0)).map
    fun j => mult j * (2 * j + 1)).sum

theorem kernel_dim_from_blocks : kernelDim = 47 := by decide

theorem kernel_blocks_are_spin2_spin5 :
    (List.range 7).filter (fun j => decide (lam (casimir j : Nat) = 0)) = [2, 5] := by
  decide

/-! ### 4. Gamma = I - K^2/99144 -/

theorem top_weight_gives_spin6 : w 6 ≠ 0 ∧ w 7 = 0 := by decide

/-- Denominator from the highest spin: lam(42)^2 * 17 = 99144 * 32. -/
theorem denominator_from_top_spin :
    lam (casimir 6 : Nat) * lam (casimir 6 : Nat) * 17 = 99144 * 32 := by
  decide

theorem gamma_is_one_on_kernel :
    ∀ j ∈ List.range 7, lam (casimir j : Nat) = 0 → gap (casimir j : Nat) = 99144 := by
  decide

/-- Off the kernel, Gamma contracts by at most 15/17, with equality at spins 3 and 6. -/
theorem gamma_contracts_off_kernel :
    ∀ j ∈ List.range 7, lam (casimir j : Nat) ≠ 0 →
      gap (casimir j : Nat) * 17 ≤ 15 * 99144 := by
  decide

theorem gamma_contraction_extremes :
    gap (casimir 3 : Nat) * 17 = 15 * 99144 ∧ gap (casimir 6 : Nat) * 17 = 15 * 99144 := by
  decide

/-! ### 5. The exact projector polynomial on the Casimir spectrum -/

/-- pr(x) = x (x-2) (x-12) (x-20) (x-31) (x-42). The five roots 0, 2, 12, 20, 42
    are the Casimir nodes outside the kernel. The sixth root 31 is not a node; it
    is chosen so that pr(6) = pr(30). These are scalar identities on the Casimir
    spectrum {0,2,6,12,20,30,42}. They say what P = pr(C)/1814400 does on each
    spin block, given that C acts as the scalar j(j+1) there (textbook input, see
    header). They are not a statement about the 125-by-125 matrix pr(C). -/
def pr (x : Int) : Int := x * (x - 2) * (x - 12) * (x - 20) * (x - 31) * (x - 42)

def nodes : List Int := (List.range 7).map fun (j : Nat) => ((casimir j : Nat) : Int)

theorem nodes_are_casimir_values : nodes = [0, 2, 6, 12, 20, 30, 42] := by decide

theorem pr_on_nodes : nodes.map pr = [0, 0, 1814400, 0, 0, 1814400, 0] := by decide

def fact : Nat → Nat
  | 0 => 1
  | n + 1 => (n + 1) * fact n

theorem pr_normalizer : (1814400 : Int) = ((fact 10 / 2 : Nat) : Int) := by decide

/-- Horner evaluation of a coefficient list, highest power first. -/
def peval (cs : List Int) (x : Int) : Int := cs.foldl (fun acc c => acc * x + c) 0

def pr_coeffs : List Int := [1, -107, 4088, -66940, 430848, -624960, 0]

/-- The coefficients are exact: the identity holds for every integer x.
    Proved with core `grind` (commutative-ring normalization). -/
theorem pr_expanded (x : Int) : pr x = peval pr_coeffs x := by
  simp only [pr, peval, pr_coeffs, List.foldl]
  grind

theorem pr_degree_six_monic : pr_coeffs.length = 7 ∧ pr_coeffs.head? = some 1 := by decide

end WeightAlgebra

#print axioms WeightAlgebra.basis_size
#print axioms WeightAlgebra.weight_counts
#print axioms WeightAlgebra.weight_symmetric
#print axioms WeightAlgebra.weight_total
#print axioms WeightAlgebra.weight_window
#print axioms WeightAlgebra.multiplicities
#print axioms WeightAlgebra.dimension_identity
#print axioms WeightAlgebra.multiplicities_reproduce_weights
#print axioms WeightAlgebra.lam_zero_iff
#print axioms WeightAlgebra.kernel_rank_from_weights
#print axioms WeightAlgebra.kernel_dim_from_blocks
#print axioms WeightAlgebra.gamma_contracts_off_kernel
#print axioms WeightAlgebra.pr_on_nodes
#print axioms WeightAlgebra.pr_normalizer
#print axioms WeightAlgebra.pr_expanded
#print axioms WeightAlgebra.pr_degree_six_monic
