import Lean

/-!
Finite spectral model of the E47 projector identity.
The seven eigenvalue sectors have dimensions 1,9,25,28,27,22,13.
No assertion here constructs the concrete 125x125 SU(2) Casimir generators.
-/
namespace E47ProjectorEquality

def casimir (j : Nat) : Int := (j : Int) * ((j : Int) + 1)
def numerator (x : Int) : Int :=
  x * (x - 2) * (x - 12) * (x - 20) * (x - 31) * (x - 42)
def selected (j : Nat) : Bool := j == 2 || j == 5

/-- The complete seven-eigenvalue polynomial certificate. -/
theorem seven_sectors :
    ∀ j : Fin 7,
      numerator (casimir j.val) =
        if selected j.val then 1814400 else 0 := by
  decide

/-- A spectral-basis index labels each of the 125 basis vectors. -/
def spin (i : Fin 125) : Nat :=
  if i.val < 1 then 0
  else if i.val < 10 then 1
  else if i.val < 35 then 2
  else if i.val < 63 then 3
  else if i.val < 90 then 4
  else if i.val < 112 then 5
  else 6

/-- Exact polynomial/character agreement at every spectral basis index. -/
theorem all_125 :
    ∀ i : Fin 125,
      numerator (casimir (spin i)) =
        if selected (spin i) then 1814400 else 0 := by
  decide

def casimirNumerator (v : Fin 125 → Int) (i : Fin 125) : Int :=
  numerator (casimir (spin i)) * v i

def characterNumerator (v : Fin 125 → Int) (i : Fin 125) : Int :=
  if selected (spin i) then 1814400 * v i else 0

/-- Equality of the two scaled projectors on every vector of the
125-dimensional integral spectral coordinate module. -/
theorem full_projector_equality (v : Fin 125 → Int) :
    ∀ i : Fin 125, casimirNumerator v i = characterNumerator v i := by
  intro i
  simp only [casimirNumerator, characterNumerator]
  rw [all_125 i]
  by_cases h : selected (spin i) = true
  · simp [h]
  · simp [h]

end E47ProjectorEquality

#print axioms E47ProjectorEquality.seven_sectors
#print axioms E47ProjectorEquality.all_125
#print axioms E47ProjectorEquality.full_projector_equality
