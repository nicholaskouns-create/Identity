/-!
  E47 explicit 125-state third Lie bracket, bounded sparse-to-dense bridge.
  The all-pairs theorem evaluates six structurally possible intermediate
  tensor states per entry. The separate row-zero theorem uses genuine
  125-term products. The remaining full-matrix sparse/dense equivalence
  is checked independently in exact Python, NOT claimed as formal here.
-/
set_option maxRecDepth 8192
set_option maxHeartbeats 0
namespace E47ThirdBracketBridge
abbrev Mat125 := Nat → Nat → Int
def a (n : Nat) : Nat := n / 25
def b (n : Nat) : Nat := (n / 5) % 5
def c (n : Nat) : Nat := n % 5
def z : Mat125 := fun i j =>
  if i == j then (6 : Int) - (a i : Int) - (b i : Int) - (c i : Int) else 0
def up : Mat125 := fun i j =>
  (if a i + 1 == a j && b i == b j && c i == c j
    then (a j : Int) * (5 - (a j : Int)) else 0) +
  (if a i == a j && b i + 1 == b j && c i == c j
    then (b j : Int) * (5 - (b j : Int)) else 0) +
  (if a i == a j && b i == b j && c i + 1 == c j
    then (c j : Int) * (5 - (c j : Int)) else 0)
def down : Mat125 := fun i j =>
  (if a i == a j + 1 && b i == b j && c i == c j then 1 else 0) +
  (if a i == a j && b i == b j + 1 && c i == c j then 1 else 0) +
  (if a i == a j && b i == b j && c i == c j + 1 then 1 else 0)
def mulEntry (A B : Mat125) (i j : Nat) : Int :=
  ((List.range 125).map fun k => A i k * B k j).sum
def sparseUpDown (A : Mat125) (i j : Nat) : Int :=
  A i (i+25) * down (i+25) j +
  A i (i+5) * down (i+5) j +
  A i (i+1) * down (i+1) j
def sparseDownUp (A : Mat125) (i j : Nat) : Int :=
  (if i >= 25 then down i (i-25) * A (i-25) j else 0) +
  (if i >= 5 then down i (i-5) * A (i-5) j else 0) +
  (if i >= 1 then down i (i-1) * A (i-1) j else 0)
def sparseBracket (A : Mat125) (i j : Nat) : Int :=
  sparseUpDown A i j - sparseDownUp A i j
def allPairs (p : Nat → Nat → Bool) : Bool :=
  (List.range 125).all fun i => (List.range 125).all fun j => p i j
theorem sparse_third_bracket_all_15625 :
    allPairs (fun i j => sparseBracket up i j == 2 * z i j) = true := by
  native_decide
theorem genuine_125_term_row_zero :
    (List.range 125).all (fun j =>
      mulEntry up down 0 j - mulEntry down up 0 j == 2 * z 0 j) = true := by
  native_decide
theorem sparse_dense_row_zero_parity :
    (List.range 125).all (fun j =>
      sparseBracket up 0 j == mulEntry up down 0 j - mulEntry down up 0 j) = true := by
  native_decide
def mutantUp : Mat125 := fun i j =>
  up i j + (if i == 0 && j == 25 then 1 else 0)
theorem mutated_raising_generator_rejected :
    sparseBracket mutantUp 0 0 ≠ 2 * z 0 0 := by decide
end E47ThirdBracketBridge
#print axioms E47ThirdBracketBridge.sparse_third_bracket_all_15625
#print axioms E47ThirdBracketBridge.genuine_125_term_row_zero
#print axioms E47ThirdBracketBridge.sparse_dense_row_zero_parity
#print axioms E47ThirdBracketBridge.mutated_raising_generator_rejected
