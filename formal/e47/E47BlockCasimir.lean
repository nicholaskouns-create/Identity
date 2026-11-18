/-
  E47BlockCasimir.lean — OP-2: the M_z-graded block decomposition of the
  125-dimensional carrier.

  STATUS: compiled clean on Lean 4.19.0 and 4.35.0. No Mathlib, no `sorry`,
  no `native_decide`, no custom axioms.

    fiber_lengths_match_blockDim : [propext, Quot.sound]
    sum_blockDims_eq_125         : [propext]
    sum_cubic_ops_eq_27761       : [propext]

  Grading the carrier by total magnetic weight M = a + b + c splits
  125 x 125 into thirteen independent integer blocks of dimensions

      1, 3, 6, 10, 15, 18, 19, 18, 15, 10, 6, 3, 1

  summing to 125, with 27,761 cubic operations against 1,953,125 for the
  undecomposed matrix — a factor of 70.4. All three figures are checked in
  kernel here and reproduced independently in
  validation/e47_polynomial_certificates.py.

  SCOPE. This file proves the combinatorics of the grading only. The
  subalgebra homomorphism theorem `toBlock_mul`, which is what would license
  replacing a 125 x 125 identity by thirteen block identities, is NOT here —
  it does not yet compile. See formal/e47/pending/E47BlockSubalgebra.lean.
-/

namespace E47BlockCasimir

abbrev BasisTriple := Fin 5 × Fin 5 × Fin 5

def totalWeight (t : BasisTriple) : Fin 13 :=
  ⟨t.1.val + t.2.1.val + t.2.2.val, by omega⟩

def allTriples : List BasisTriple :=
  (List.finRange 5).flatMap fun a =>
    (List.finRange 5).flatMap fun b =>
      (List.finRange 5).map fun c => (a, b, c)

def weightFiber (M : Fin 13) : List BasisTriple :=
  allTriples.filter (fun t => totalWeight t = M)

def blockDim : Fin 13 → Nat
  | 0  => 1  | 1  => 3  | 2  => 6  | 3  => 10 | 4  => 15 | 5  => 18
  | 6  => 19
  | 7  => 18 | 8  => 15 | 9  => 10 | 10 => 6  | 11 => 3  | 12 => 1

theorem fiber_lengths_match_blockDim :
    ∀ M : Fin 13, (weightFiber M).length = blockDim M := by
  decide

theorem sum_blockDims_eq_125 :
    (List.finRange 13).foldl (fun acc M => acc + blockDim M) 0 = 125 := by
  decide

theorem sum_cubic_ops_eq_27761 :
    (List.finRange 13).foldl (fun acc M => acc + (blockDim M) ^ 3) 0 = 27761 := by
  decide

end E47BlockCasimir

#print axioms E47BlockCasimir.fiber_lengths_match_blockDim
#print axioms E47BlockCasimir.sum_blockDims_eq_125
#print axioms E47BlockCasimir.sum_cubic_ops_eq_27761
