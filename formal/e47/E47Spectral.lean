/-
  Self-contained certificate for the scalar content of the E47 spectral engine.
  It does not import Mathlib and it does not formalize the 125-by-125 matrices.
  The Python reconstruction checks those matrices separately and checks that
  these same integers hold.
-/

def rangeFromTo (lo hi : Nat) : List Nat :=
  (List.range (hi + 1)).filter fun j => lo ≤ j

def couple (j1 j2 : Nat) : List Nat :=
  rangeFromTo (max (j1 - j2) (j2 - j1)) (j1 + j2)

def threeSpin2 : List Nat :=
  (couple 2 2).foldl (fun acc j => acc ++ couple j 2) []

def count (j : Nat) : List Nat → Nat
  | [] => 0
  | x :: xs => (if x = j then 1 else 0) + count j xs

def casimir (j : Nat) : Nat := j * (j + 1)

def lam (c : Int) : Int := (c - 6) * (c - 30)

def gap (c : Int) : Nat := (99144 - lam c * lam c).natAbs

theorem spin2_triple_multiplicities :
    count 0 threeSpin2 = 1 ∧ count 1 threeSpin2 = 3 ∧ count 2 threeSpin2 = 5
    ∧ count 3 threeSpin2 = 4 ∧ count 4 threeSpin2 = 3 ∧ count 5 threeSpin2 = 2
    ∧ count 6 threeSpin2 = 1 := by
  decide

theorem carrier_dimension :
    count 0 threeSpin2 * (2 * 0 + 1) + count 1 threeSpin2 * (2 * 1 + 1)
    + count 2 threeSpin2 * (2 * 2 + 1) + count 3 threeSpin2 * (2 * 3 + 1)
    + count 4 threeSpin2 * (2 * 4 + 1) + count 5 threeSpin2 * (2 * 5 + 1)
    + count 6 threeSpin2 * (2 * 6 + 1) = 125 := by
  decide

theorem casimir_nodes :
    (List.range 7).map casimir = [0, 2, 6, 12, 20, 30, 42] := by
  decide

theorem kernel_rank :
    count 2 threeSpin2 * (2 * 2 + 1) + count 5 threeSpin2 * (2 * 5 + 1) = 47 := by
  decide

theorem kernel_polynomial_vanishes : lam 6 = 0 ∧ lam 30 = 0 := by
  decide

theorem kernel_gamma_is_one : gap 6 = 99144 ∧ gap 30 = 99144 := by
  decide

theorem denominator_from_highest_weight :
    (42 - 6) * (42 - 30) * ((42 - 6) * (42 - 30)) * 17 = 99144 * 32 := by
  decide

theorem complement_contracts :
    gap 0 * 17 < 15 * 99144 ∧ gap 2 * 17 < 15 * 99144
    ∧ gap 12 * 17 = 15 * 99144 ∧ gap 20 * 17 < 15 * 99144
    ∧ gap 42 * 17 = 15 * 99144 := by
  decide
