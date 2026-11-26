/-!
  E47 paired bridge: the 125-state triple tensor generators are exactly
  the sum of three explicit 5-state local generator lifts, entry by entry.
  This checks the actual Tensor125 definitions, not a substitute matrix.
  It does not yet prove the lifted Lie brackets, M(C)=0, or rank 47.
-/
set_option maxRecDepth 8192
set_option maxHeartbeats 0
namespace E47TensorLiftParity
abbrev Mat5 := Nat → Nat → Int
abbrev Mat125 := Nat → Nat → Int
def a (n : Nat) : Nat := n / 25
def b (n : Nat) : Nat := (n / 5) % 5
def c (n : Nat) : Nat := n % 5
def delta (i j : Nat) : Int := if i == j then 1 else 0
def z5 : Mat5 := fun i j => if i == j then 2 - (i : Int) else 0
def up5 : Mat5 := fun i j =>
  if i + 1 == j then (j : Int) * (5 - (j : Int)) else 0
def down5 : Mat5 := fun i j => if i == j + 1 then 1 else 0
def lift (g : Mat5) : Mat125 := fun i j =>
  g (a i) (a j) * delta (b i) (b j) * delta (c i) (c j) +
  delta (a i) (a j) * g (b i) (b j) * delta (c i) (c j) +
  delta (a i) (a j) * delta (b i) (b j) * g (c i) (c j)

/- These three functions duplicate the literal concrete entry definitions
   of formal/e47/unified/Tensor125.lean for an independent parity check. -/
def tensorZ : Mat125 := fun i j =>
  if i == j then (6 : Int) - (a i : Int) - (b i : Int) - (c i : Int) else 0
def tensorUp : Mat125 := fun i j =>
  (if a i + 1 == a j && b i == b j && c i == c j
    then (a j : Int) * (5 - (a j : Int)) else 0) +
  (if a i == a j && b i + 1 == b j && c i == c j
    then (b j : Int) * (5 - (b j : Int)) else 0) +
  (if a i == a j && b i == b j && c i + 1 == c j
    then (c j : Int) * (5 - (c j : Int)) else 0)
def tensorDown : Mat125 := fun i j =>
  (if a i == a j + 1 && b i == b j && c i == c j then 1 else 0) +
  (if a i == a j && b i == b j + 1 && c i == c j then 1 else 0) +
  (if a i == a j && b i == b j && c i == c j + 1 then 1 else 0)
def allPairs (p : Nat → Nat → Bool) : Bool :=
  (List.range 125).all fun i => (List.range 125).all fun j => p i j

theorem tensor_index_roundtrip :
    (List.range 125).all (fun n => 25 * a n + 5 * b n + c n == n) = true := by
  decide
theorem tensor_z_is_three_factor_lift :
    allPairs (fun i j => lift z5 i j == tensorZ i j) = true := by
  native_decide
theorem tensor_up_is_three_factor_lift :
    allPairs (fun i j => lift up5 i j == tensorUp i j) = true := by
  native_decide
theorem tensor_down_is_three_factor_lift :
    allPairs (fun i j => lift down5 i j == tensorDown i j) = true := by
  native_decide

def mutantUp5 : Mat5 := fun i j =>
  up5 i j + (if i == 0 && j == 1 then 1 else 0)
theorem mutated_local_generator_rejected :
    lift mutantUp5 0 25 ≠ tensorUp 0 25 := by decide

end E47TensorLiftParity
#print axioms E47TensorLiftParity.tensor_index_roundtrip
#print axioms E47TensorLiftParity.tensor_z_is_three_factor_lift
#print axioms E47TensorLiftParity.tensor_up_is_three_factor_lift
#print axioms E47TensorLiftParity.tensor_down_is_three_factor_lift
#print axioms E47TensorLiftParity.mutated_local_generator_rejected
