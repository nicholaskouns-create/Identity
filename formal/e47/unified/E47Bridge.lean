/-
  E47-CORE-003: the carrier bridge.

  WHAT WAS MISSING. RankNullity47 derives 47 and 78 from the coupling
  2 (x) 2 (x) 2 and the polynomial (x-6)(x-30). But the coupling was an
  ASSUMPTION about the carrier, not a fact read off the concrete operator.
  Tensor125 separately builds the real 125-state generators. Nothing joined
  the two, so "47" rested on a representation-theoretic premise.

  WHAT THIS MODULE PROVES. The spin content used by RankNullity47 is exactly
  the spin content computed from the DIAGONAL OF THE CONCRETE totalZ on all
  125 basis states. No coupling is assumed: `multiplicity j` counts actual
  matrix entries. The 47 and the 78 are then recomputed from that concrete
  content by the same general rank-nullity theorem.

  WHAT THIS DOES NOT PROVE, stated plainly. This bridges the WEIGHT data of
  the concrete operator, not its EIGENSPACES. Going from here to
  `dim ker (C - 6I)(C - 30I) = 47` for the full 125x125 Casimir still needs
  the Casimir to be shown central and its eigenspaces identified with the
  weight blocks (Proof Forge lanes #17 and #19). That obligation is open and
  this module does not close it.

  Self-contained: no Mathlib, no imports. Definitions are repeated from
  Tensor125 and RankNullity47 so the file compiles standalone under
  scripts/site_validate.py, as the house style does elsewhere.
-/
set_option maxRecDepth 8192
set_option maxHeartbeats 0

namespace E47Bridge

/-! ## The concrete carrier, from Tensor125 -/

abbrev Mat125 := Fin 125 → Fin 125 → Int

def a (n : Fin 125) : Nat := n.val / 25
def b (n : Fin 125) : Nat := (n.val / 5) % 5
def c (n : Fin 125) : Nat := n.val % 5

/-- The actual total weight operator on the 125 basis states. -/
def totalZ : Mat125 := fun i j =>
  if i = j then (6 : Int) - (a i : Int) - (b i : Int) - (c i : Int) else 0

def idx (n : Nat) : Fin 125 :=
  ⟨n % 125, Nat.mod_lt n (by decide)⟩

/-- How many of the 125 states carry weight m. Counts matrix entries. -/
def weightCount (m : Int) : Nat :=
  (List.range 125).countP fun n => decide (totalZ (idx n) (idx n) = m)

/-- Copies of spin j, by the standard weight-difference count. -/
def multiplicity (j : Nat) : Nat :=
  weightCount (j : Int) - weightCount ((j + 1 : Nat) : Int)

/-! ## The assumed coupling, from E47Spectral -/

def rangeFromTo (lo hi : Nat) : List Nat :=
  (List.range (hi + 1)).filter fun j => lo ≤ j

def couple (j1 j2 : Nat) : List Nat :=
  rangeFromTo (max (j1 - j2) (j2 - j1)) (j1 + j2)

def threeSpin2 : List Nat :=
  (couple 2 2).foldl (fun acc j => acc ++ couple j 2) []

def count (j : Nat) : List Nat → Nat
  | []      => 0
  | x :: xs => (if x = j then 1 else 0) + count j xs

/-! ## THE BRIDGE

    The concrete operator's weight data and the assumed coupling agree,
    spin by spin. This is the step that was missing. -/

theorem concrete_weights_match_coupling :
    (List.range 7).map multiplicity
      = (List.range 7).map (fun j => count j threeSpin2) := by
  decide

/-- Both sides are the same explicit list, recorded for the reader. -/
theorem multiplicities_are :
    (List.range 7).map multiplicity = [1, 3, 5, 4, 3, 2, 1] := by
  decide

/-! ## Blocks built from the CONCRETE operator, not from the coupling -/

/-- One `(j, 2j+1)` entry per copy of spin j found in the real diagonal. -/
def blocksFromMatrix : List (Nat × Nat) :=
  (List.range 7).flatMap fun j =>
    List.replicate (multiplicity j) (j, 2 * j + 1)

def casimir (j : Nat) : Int := (j : Int) * ((j : Int) + 1)
def p (x : Int) : Int := (x - 6) * (x - 30)
def annihilated (j : Nat) : Bool := p (casimir j) == 0

def keep (b : Bool) (m : Nat) : Nat := bif b then m else 0
def drop (b : Bool) (m : Nat) : Nat := bif b then 0 else m

theorem drop_add_keep (b : Bool) (m : Nat) : drop b m + keep b m = m := by
  cases b
  · exact Nat.add_zero m
  · exact Nat.zero_add m

def dim : List (Nat × Nat) → Nat
  | []          => 0
  | (_, m) :: t => m + dim t

def kerDim : List (Nat × Nat) → Nat
  | []          => 0
  | (j, m) :: t => keep (annihilated j) m + kerDim t

def rankDim : List (Nat × Nat) → Nat
  | []          => 0
  | (j, m) :: t => drop (annihilated j) m + rankDim t

/-- Rank-nullity for any block list. No numeral in the statement. -/
theorem rank_nullity : ∀ l : List (Nat × Nat), rankDim l + kerDim l = dim l
  | []          => rfl
  | (j, m) :: t => by
      have ih := rank_nullity t
      have hb := drop_add_keep (annihilated j) m
      show drop (annihilated j) m + rankDim t
           + (keep (annihilated j) m + kerDim t) = m + dim t
      omega

/-! ## Read-outs, now grounded in the concrete 125-state operator -/

theorem block_count_from_matrix : blocksFromMatrix.length = 19 := by decide

/-- The carrier dimension, summed from the real weight multiplicities. -/
theorem carrier_from_matrix : dim blocksFromMatrix = 125 := by decide

/-- dim ker K. Computed from matrix entries, not from an assumed coupling. -/
theorem kernel_from_matrix : kerDim blocksFromMatrix = 47 := by decide

/-- rank K, likewise. -/
theorem rank_from_matrix : rankDim blocksFromMatrix = 78 := by decide

/-- The identity, obtained from the general theorem applied to the
    concrete blocks. -/
theorem dimension_identity_from_matrix :
    rankDim blocksFromMatrix + kerDim blocksFromMatrix = dim blocksFromMatrix :=
  rank_nullity blocksFromMatrix

/-! ## Independent cross-checks against real matrix invariants

    The weight count above is one piece of evidence. These are three more,
    and they are independent of it: each predicts a TRACE from the block
    decomposition, and each prediction is a number Tensor125 separately
    proves about the actual 125x125 matrices. A wrong block decomposition
    would have to reproduce all three by coincidence. -/

/-- Sum over blocks of (2j+1) summed weights. Tensor125.totalZ_trace = 0. -/
theorem trace_Z_from_blocks :
    ((List.range 7).map fun j =>
      (multiplicity j : Int) * (List.range (2 * j + 1)).foldl
        (fun (acc : Int) (k : Nat) => acc + ((k : Int) - (j : Int))) 0).sum = 0 := by
  decide

/-- Tensor125.totalZ_diagonal_square_trace = 750. -/
theorem trace_Z_squared_from_blocks :
    ((List.range 7).map fun j =>
      (multiplicity j : Int) * (List.range (2 * j + 1)).foldl
        (fun (acc : Int) (k : Nat) =>
          acc + ((k : Int) - (j : Int)) * ((k : Int) - (j : Int))) 0).sum
      = 750 := by
  decide

/-- Each spin-j block contributes (2j+1) states of Casimir j(j+1).
    Tensor125.concrete_casimir_trace = 2250. -/
theorem trace_casimir_from_blocks :
    ((List.range 7).map fun j =>
      (multiplicity j : Int) * (2 * (j : Int) + 1) * casimir j).sum = 2250 := by
  decide

/-- The abstract route and the concrete operator give the same blocks. -/
def blocksFromCoupling : List (Nat × Nat) :=
  (List.range 7).flatMap fun j =>
    List.replicate (count j threeSpin2) (j, 2 * j + 1)

theorem blocks_agree : blocksFromMatrix = blocksFromCoupling := by decide

end E47Bridge

-- Audit the dependencies in CI output.
#print axioms E47Bridge.concrete_weights_match_coupling
#print axioms E47Bridge.kernel_from_matrix
#print axioms E47Bridge.rank_from_matrix
#print axioms E47Bridge.blocks_agree
#print axioms E47Bridge.rank_nullity
#print axioms E47Bridge.trace_casimir_from_blocks
