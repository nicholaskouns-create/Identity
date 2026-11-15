/-!
E47 weight-count generating-function certificate.
Finite coefficient and state-count bridge; no Mathlib.
-/
namespace E47WeightCounts
set_option maxRecDepth 4096
set_option maxHeartbeats 0

def a (n : Fin 125) : Nat := n.val / 25
def b (n : Fin 125) : Nat := (n.val / 5) % 5
def c (n : Fin 125) : Nat := n.val % 5

def w (i : Fin 125) : Int :=
  6 - (a i : Int) - (b i : Int) - (c i : Int)

def dimV (weight : Int) : Nat :=
  ((List.range 125).filter (fun k =>
    if h : k < 125 then w ⟨k, h⟩ == weight else false)).length

def ind5 (k : Nat) : Int := if k < 5 then 1 else 0

def polyCubeCoeff (n : Nat) : Int :=
  ((List.range (n + 1)).map (fun i =>
    ((List.range (i + 1)).map (fun j =>
      ind5 j * ind5 (i - j) * ind5 (n - i))).sum)).sum

def numCoeff (k : Nat) : Int :=
  match k with
  | 0 => 1
  | 5 => -3
  | 10 => 3
  | 15 => -1
  | _ => 0

def negBinom3 (m : Nat) : Int :=
  ((m + 2 : Int) * (m + 1 : Int)) / 2

def gfClosedCoeff (n : Nat) : Int :=
  ((List.range (n + 1)).map (fun k => numCoeff k * negBinom3 (n - k))).sum

theorem polyCube_eq_gfClosed :
    ∀ n : Fin 16, polyCubeCoeff n.val = gfClosedCoeff n.val := by
  decide

theorem dimV_eq_gfClosed :
    ∀ offset : Fin 13,
      let weight : Int := (offset.val : Int) - 6
      (dimV weight : Int) = gfClosedCoeff (6 - weight).toNat := by
  decide

theorem dimV_seven : dimV 7 = 0 := by decide

def d (weight : Int) : Nat := dimV weight - dimV (weight + 1)

theorem weight_values :
    dimV 0 = 19 ∧ dimV 1 = 18 ∧ dimV 2 = 15 ∧ dimV 3 = 10 ∧
    dimV 4 = 6 ∧ dimV 5 = 3 ∧ dimV 6 = 1 ∧ dimV 7 = 0 := by
  decide

theorem highest_weight_counts :
    d 0 = 1 ∧ d 1 = 3 ∧ d 2 = 5 ∧ d 3 = 4 ∧
    d 4 = 3 ∧ d 5 = 2 ∧ d 6 = 1 := by
  decide

theorem total_irrep_dim :
    ((List.range 7).map (fun j => d (j : Int) * (2 * j + 1))).sum = 125 := by
  decide

theorem kernel_dim_47 :
    d 2 * (2 * 2 + 1) + d 5 * (2 * 5 + 1) = 47 := by
  decide

end E47WeightCounts
#print axioms E47WeightCounts.polyCube_eq_gfClosed
#print axioms E47WeightCounts.dimV_eq_gfClosed
#print axioms E47WeightCounts.kernel_dim_47
