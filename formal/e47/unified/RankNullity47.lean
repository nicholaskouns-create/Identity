/-
  E47-CORE-002: rank and kernel as OUTPUTS.

  E47-CORE-001 (Core47.lean) defines `carrier := 125` and `kernel := 47`
  and then checks 47 + 78 = 125. Nothing is derived there; the numerals are
  the input. This module removes that.

  The only inputs here are
    (1) the coupling 2 (x) 2 (x) 2, which produces the spin content, and
    (2) the annihilating polynomial p(x) = (x - 6)(x - 30).

  125, 47 and 78 are then computed. The dimension identity is proved for
  EVERY spin content and EVERY annihilating predicate, by induction, and
  only afterwards specialised to E47. No numeral occurs in that theorem.

  Self-contained: no Mathlib, no imports.
-/

namespace E47RankNullity

/-! ## Input 1 - the coupling 2 (x) 2 (x) 2

    Same construction as formal/e47/E47Spectral.lean, repeated here so the
    module compiles standalone under scripts/site_validate.py. -/

def rangeFromTo (lo hi : Nat) : List Nat :=
  (List.range (hi + 1)).filter fun j => lo ≤ j

/-- Clebsch-Gordan support: j1 (x) j2 decomposes over |j1-j2| .. j1+j2. -/
def couple (j1 j2 : Nat) : List Nat :=
  rangeFromTo (max (j1 - j2) (j2 - j1)) (j1 + j2)

/-- Every irreducible appearing in 2 (x) 2 (x) 2, listed with multiplicity. -/
def threeSpin2 : List Nat :=
  (couple 2 2).foldl (fun acc j => acc ++ couple j 2) []

/-- The carrier as a list of blocks: one entry `(j, 2j+1)` per copy of spin j.
    Nothing is written by hand; this is exactly the coupling output. -/
def blocks : List (Nat × Nat) :=
  threeSpin2.map fun j => (j, 2 * j + 1)

/-! ## Input 2 - the annihilating polynomial -/

/-- su(2) Casimir eigenvalue on spin j. -/
def casimir (j : Nat) : Int := (j : Int) * ((j : Int) + 1)

/-- p(x) = (x - 6)(x - 30); K = p(C). -/
def p (x : Int) : Int := (x - 6) * (x - 30)

/-- A block lies in ker K exactly when p kills its Casimir eigenvalue. -/
def annihilated (j : Nat) : Bool := p (casimir j) == 0

/-! ## Dimension bookkeeping -/

def keep (b : Bool) (m : Nat) : Nat := bif b then m else 0
def drop (b : Bool) (m : Nat) : Nat := bif b then 0 else m

/-- A block is counted on exactly one side. Axiom-free. -/
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

/-! ## The general theorem

    Rank-nullity for a graded carrier. True of ANY list of blocks. No
    numeral appears in the statement or the proof. -/

theorem rank_nullity : ∀ l : List (Nat × Nat), rankDim l + kerDim l = dim l
  | []          => rfl
  | (j, m) :: t => by
      have ih := rank_nullity t
      have hb := drop_add_keep (annihilated j) m
      show drop (annihilated j) m + rankDim t
           + (keep (annihilated j) m + kerDim t) = m + dim t
      omega

/-! ## Read-outs

    Each numeral below is the RESULT of evaluating the definitions above
    on the coupling output. None is used as an input anywhere. -/

/-- The coupling gives 19 irreducibles. -/
theorem block_count : blocks.length = 19 := by decide

/-- The spins p annihilates are exactly j = 2 and j = 5. -/
theorem annihilated_spins :
    (List.range 7).filter annihilated = [2, 5] := by decide

/-- Carrier dimension, computed from the coupling. -/
theorem carrier_eq : dim blocks = 125 := by decide

/-- dim ker K, computed. This is the 47. -/
theorem kernel_eq : kerDim blocks = 47 := by decide

/-- rank K, computed. This is the 78, and it was never written down. -/
theorem rank_eq : rankDim blocks = 78 := by decide

/-- The dimension identity, obtained from the general theorem. -/
theorem dimension_identity :
    rankDim blocks + kerDim blocks = dim blocks :=
  rank_nullity blocks

/-- The same identity in numerals. Each side still carries its derivation:
    this is `rank_nullity`, rewritten through the three read-outs, not a
    decision on literals. -/
theorem dimension_identity_numeric : (78 : Nat) + 47 = 125 := by
  rw [← rank_eq, ← kernel_eq, ← carrier_eq]
  exact rank_nullity blocks

/-- Agreement with E47-CORE-001's hand-written constants, stated as a check
    on them rather than an assumption. -/
theorem agrees_with_core001 :
    kerDim blocks = 47 ∧ dim blocks = 125 ∧ rankDim blocks = 78 := by decide

end E47RankNullity

-- Audit the dependencies in CI output.
#print axioms E47RankNullity.rank_nullity
#print axioms E47RankNullity.dimension_identity
#print axioms E47RankNullity.kernel_eq
#print axioms E47RankNullity.rank_eq
#print axioms E47RankNullity.dimension_identity_numeric
#print axioms E47RankNullity.carrier_eq
