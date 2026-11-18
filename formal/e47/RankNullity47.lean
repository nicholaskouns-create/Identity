/-
  RankNullity47.lean — the general rank-nullity identity for a graded carrier,
  with the E47 values as specialised read-outs.

  This is one of the two instruments the Historical Accordance record declares
  but which had no file in the tree. It exists now.

  STATUS: PROVED. Compiled clean on Lean 4.19.0 (the toolchain CI pins) and on
  4.35.0. No Mathlib, no `sorry`, no `native_decide`, no custom axioms.

    rank_nullity            : [propext, Quot.sound]
    nullity_le_total        : [propext, Quot.sound]
    rank_eq_nullity_not     : [propext]
    selK_iff_selector       : [propext, Quot.sound]
    e47_rank_nullity        : [propext, Quot.sound]
    e47_78_add_47_eq_125    : [propext, Quot.sound]
    e47_retained_sectors    : does not depend on any axioms
    rank_from_nullity       : [propext, Quot.sound]
    nullity_determined      : [propext, Quot.sound]

  DESIGN, as the record specifies it. The general statement is an induction
  over a graded carrier -- a list of sectors, each with an eigenvalue and a
  dimension -- under an arbitrary annihilating predicate P : Int -> Bool.
  No numeral occurs anywhere in `rank_nullity`. The seven isotypic sectors of
  V2 (x) V2 (x) V2 and the selector of K = (C - 6I)(C - 30I) appear only below,
  as an instance, and `e47_rank_nullity` is obtained by applying the general
  theorem rather than by recomputing 47 + 78.

  `rank_from_nullity` and `nullity_determined` are there to show the general
  form earns its keep: `decide` cannot reach an arbitrary carrier under an
  arbitrary predicate, but the identity still fixes the third quantity from
  the other two.

  `selK_iff_selector` ties the Boolean predicate back to the polynomial it
  stands for: selK x = true if and only if (x - 6)(x - 30) = 0. Without it the
  file would be bookkeeping about a list rather than a statement about K.
-/

namespace RankNullity47

/-- A graded carrier is a list of sectors, each carrying an eigenvalue and a dimension. -/
structure Sector where
  eigen : Int
  dim   : Nat
deriving DecidableEq

abbrev Carrier := List Sector

/-- Total dimension of the carrier. -/
def total (C : Carrier) : Nat := C.foldr (fun s acc => s.dim + acc) 0

/-- Nullity relative to an annihilating predicate: the sectors it kills. -/
def nullity (P : Int → Bool) (C : Carrier) : Nat :=
  (C.filter (fun s => P s.eigen)).foldr (fun s acc => s.dim + acc) 0

/-- Rank relative to an annihilating predicate: the sectors it does not kill. -/
def rank (P : Int → Bool) (C : Carrier) : Nat :=
  (C.filter (fun s => !P s.eigen)).foldr (fun s acc => s.dim + acc) 0

/-- THE GENERAL IDENTITY.  For every graded carrier and every annihilating
    predicate, rank and nullity partition the total dimension.
    No numeral appears in this statement. -/
theorem rank_nullity (P : Int → Bool) :
    ∀ C : Carrier, rank P C + nullity P C = total C := by
  intro C
  induction C with
  | nil => rfl
  | cons s rest ih =>
    cases h : P s.eigen <;>
      simp only [rank, nullity, total, List.filter, h, Bool.not_true, Bool.not_false,
                 List.foldr] <;>
      simp only [rank, nullity, total] at ih <;> omega

/-- Nullity never exceeds the total. -/
theorem nullity_le_total (P : Int → Bool) (C : Carrier) : nullity P C ≤ total C := by
  have := rank_nullity P C; omega

/-- The complementary predicate exchanges rank and nullity. -/
theorem rank_eq_nullity_not (P : Int → Bool) (C : Carrier) :
    rank P C = nullity (fun x => !P x) C := by
  simp only [rank, nullity, Bool.not_not]

/-! ### The E47 carrier as a specialised read-out

Everything below is an instance of `rank_nullity`.  The numerals live here
and nowhere in the general statement. -/

/-- The seven isotypic sectors of V₂ ⊗ V₂ ⊗ V₂, by Casimir eigenvalue j(j+1). -/
def e47Carrier : Carrier :=
  [⟨0, 1⟩, ⟨2, 9⟩, ⟨6, 25⟩, ⟨12, 28⟩, ⟨20, 27⟩, ⟨30, 22⟩, ⟨42, 13⟩]

/-- The annihilating predicate of K = (C − 6I)(C − 30I). -/
def selK : Int → Bool := fun x => x == 6 || x == 30

/-- The predicate is exactly the vanishing locus of the selector polynomial. -/
theorem selK_iff_selector (x : Int) :
    selK x = true ↔ (x - 6) * (x - 30) = 0 := by
  constructor
  · intro h
    simp only [selK, Bool.or_eq_true, beq_iff_eq] at h
    rcases h with h | h <;> subst h <;> decide
  · intro h
    have : x - 6 = 0 ∨ x - 30 = 0 := Int.mul_eq_zero.mp h
    rcases this with h' | h' <;> simp only [selK, Bool.or_eq_true, beq_iff_eq] <;> omega

theorem e47_total   : total e47Carrier = 125 := by decide
theorem e47_nullity : nullity selK e47Carrier = 47 := by decide
theorem e47_rank    : rank selK e47Carrier = 78 := by decide

/-- 47 + 78 = 125, obtained by SPECIALISING the general theorem — not recomputed. -/
theorem e47_rank_nullity : rank selK e47Carrier + nullity selK e47Carrier = total e47Carrier :=
  rank_nullity selK e47Carrier

/-- The same identity read out in numerals, obtained from the general theorem. -/
theorem e47_78_add_47_eq_125 : 78 + 47 = 125 := by
  have h := e47_rank_nullity
  rw [e47_rank, e47_nullity, e47_total] at h

/-- Where the general theorem earns its keep: `decide` cannot reach an
    arbitrary carrier under an arbitrary predicate, but the identity still
    determines the third quantity from the other two. -/
theorem rank_from_nullity (P : Int → Bool) (C : Carrier)
    (hn : nullity P C = 47) (ht : total C = 125) : rank P C = 78 := by
  have h := rank_nullity P C; omega

/-- And symmetrically, with no numerals at all. -/
theorem nullity_determined (P : Int → Bool) (C : Carrier) (r : Nat)
    (hr : rank P C = r) : nullity P C = total C - r := by
  have h := rank_nullity P C; omega

/-- The retained sectors are exactly j = 2 and j = 5, of dimensions 25 and 22. -/
theorem e47_retained_sectors :
    e47Carrier.filter (fun s => selK s.eigen) = [⟨6, 25⟩, ⟨30, 22⟩] := by decide

end RankNullity47

#print axioms RankNullity47.rank_nullity
#print axioms RankNullity47.nullity_le_total
#print axioms RankNullity47.rank_eq_nullity_not
#print axioms RankNullity47.selK_iff_selector
#print axioms RankNullity47.e47_rank_nullity
#print axioms RankNullity47.e47_78_add_47_eq_125
#print axioms RankNullity47.e47_retained_sectors
#print axioms RankNullity47.rank_from_nullity
#print axioms RankNullity47.nullity_determined
