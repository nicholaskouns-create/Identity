(* E47 concrete 125-state third Lie bracket, sparse/dense bridge.
   Six possible tensor intermediates are enumerated for every entry.
   Row zero is separately checked with actual 125-term matrix products.
   Full-matrix sparse/dense parity is an independent Python witness, not
   a claimed Coq theorem. *)
From Coq Require Import ZArith Arith Bool List.
Import ListNotations.
Open Scope Z_scope.
Module E47ThirdBracketBridge.
Definition Mat125 := nat -> nat -> Z.
Definition a (n : nat) : nat := (n / 25)%nat.
Definition b (n : nat) : nat := ((n / 5) mod 5)%nat.
Definition c (n : nat) : nat := (n mod 5)%nat.
Definition z (i j : nat) : Z :=
  if Nat.eqb i j then 6 - Z.of_nat (a i) - Z.of_nat (b i) - Z.of_nat (c i) else 0.
Definition up (i j : nat) : Z :=
  (if (Nat.eqb (S (a i)) (a j) && Nat.eqb (b i) (b j) && Nat.eqb (c i) (c j))%bool
    then Z.of_nat (a j) * (5 - Z.of_nat (a j)) else 0) +
  (if (Nat.eqb (a i) (a j) && Nat.eqb (S (b i)) (b j) && Nat.eqb (c i) (c j))%bool
    then Z.of_nat (b j) * (5 - Z.of_nat (b j)) else 0) +
  (if (Nat.eqb (a i) (a j) && Nat.eqb (b i) (b j) && Nat.eqb (S (c i)) (c j))%bool
    then Z.of_nat (c j) * (5 - Z.of_nat (c j)) else 0).
Definition down (i j : nat) : Z :=
  (if (Nat.eqb (a i) (S (a j)) && Nat.eqb (b i) (b j) && Nat.eqb (c i) (c j))%bool then 1 else 0) +
  (if (Nat.eqb (a i) (a j) && Nat.eqb (b i) (S (b j)) && Nat.eqb (c i) (c j))%bool then 1 else 0) +
  (if (Nat.eqb (a i) (a j) && Nat.eqb (b i) (b j) && Nat.eqb (c i) (S (c j)))%bool then 1 else 0).
Definition mulEntry (A B : Mat125) (i j : nat) : Z :=
  fold_right Z.add 0 (map (fun k => A i k * B k j) (seq 0 125)).
Definition sparseUpDown (A : Mat125) (i j : nat) : Z :=
  A i (i+25)%nat * down (i+25)%nat j +
  A i (i+5)%nat * down (i+5)%nat j +
  A i (S i) * down (S i) j.
Definition sparseDownUp (A : Mat125) (i j : nat) : Z :=
  (if Nat.leb 25 i then down i (i-25)%nat * A (i-25)%nat j else 0) +
  (if Nat.leb 5 i then down i (i-5)%nat * A (i-5)%nat j else 0) +
  (if Nat.leb 1 i then down i (i-1)%nat * A (i-1)%nat j else 0).
Definition sparseBracket (A : Mat125) (i j : nat) : Z :=
  sparseUpDown A i j - sparseDownUp A i j.
Definition allPairs (p : nat -> nat -> bool) : bool :=
  forallb (fun i => forallb (p i) (seq 0 125)) (seq 0 125).
Theorem sparse_third_bracket_all_15625 :
  allPairs (fun i j => Z.eqb (sparseBracket up i j) (2 * z i j)) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem genuine_125_term_row_zero :
  forallb (fun j => Z.eqb (mulEntry up down 0%nat j -
    mulEntry down up 0%nat j) (2 * z 0%nat j)) (seq 0 125) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem sparse_dense_row_zero_parity :
  forallb (fun j => Z.eqb (sparseBracket up 0%nat j)
    (mulEntry up down 0%nat j - mulEntry down up 0%nat j))
    (seq 0 125) = true.
Proof. vm_compute. reflexivity. Qed.
Definition mutantUp (i j : nat) : Z :=
  up i j + (if (Nat.eqb i 0%nat && Nat.eqb j 25%nat)%bool then 1 else 0).
Theorem mutated_raising_generator_rejected :
  Z.eqb (sparseBracket mutantUp 0%nat 0%nat) (2 * z 0%nat 0%nat) = false.
Proof. vm_compute. reflexivity. Qed.
End E47ThirdBracketBridge.
Print Assumptions E47ThirdBracketBridge.sparse_third_bracket_all_15625.
Print Assumptions E47ThirdBracketBridge.genuine_125_term_row_zero.
Print Assumptions E47ThirdBracketBridge.sparse_dense_row_zero_parity.
Print Assumptions E47ThirdBracketBridge.mutated_raising_generator_rejected.
