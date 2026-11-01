/-!
  Independent local spin-2 certificate for the concrete E47 tensor factors.
  This is the 5-dimensional factor used by Tensor125. The full 125x125
  tensor lift and M(C)=0 remain separate formal obligations.
  Every matrix product below sums over the actual five basis indices.
-/
set_option maxRecDepth 8192
set_option maxHeartbeats 0
namespace E47LocalSpin2
abbrev Mat5 := Nat → Nat → Int
def z : Mat5 := fun i j => if i == j then 2 - (i : Int) else 0
def up : Mat5 := fun i j =>
  if i + 1 == j then (j : Int) * (5 - (j : Int)) else 0
def down : Mat5 := fun i j => if i == j + 1 then 1 else 0
def mulEntry (A B : Mat5) (i j : Nat) : Int :=
  ((List.range 5).map fun k => A i k * B k j).sum
def bracket (A B : Mat5) (i j : Nat) : Int :=
  mulEntry A B i j - mulEntry B A i j
def casimir (i j : Nat) : Int :=
  mulEntry down up i j + mulEntry z z i j + z i j
def allPairs (p : Nat → Nat → Bool) : Bool :=
  (List.range 5).all fun i => (List.range 5).all fun j => p i j

theorem z_up_all_entries :
    allPairs (fun i j => bracket z up i j == up i j) = true := by decide
theorem z_down_all_entries :
    allPairs (fun i j => bracket z down i j == -(down i j)) = true := by decide
theorem up_down_all_entries :
    allPairs (fun i j => bracket up down i j == 2 * z i j) = true := by decide
theorem local_casimir_is_six :
    allPairs (fun i j => casimir i j == if i == j then 6 else 0) = true := by decide

def mutantUp : Mat5 := fun i j =>
  up i j + if i == 0 && j == 1 then 1 else 0
theorem negative_control_rejected :
    bracket mutantUp down 0 0 ≠ 2 * z 0 0 := by decide

end E47LocalSpin2

#print axioms E47LocalSpin2.z_up_all_entries
#print axioms E47LocalSpin2.z_down_all_entries
#print axioms E47LocalSpin2.up_down_all_entries
#print axioms E47LocalSpin2.local_casimir_is_six
#print axioms E47LocalSpin2.negative_control_rejected
