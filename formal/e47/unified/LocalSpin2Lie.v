(* Independent exact 5x5 spin-2 factor certificate.
   This proves the factor brackets and C=6I using actual five-term products.
   It does not claim a formal tensor lift to the full 125x125 Casimir. *)
From Coq Require Import ZArith Arith Bool List.
Import ListNotations.
Open Scope Z_scope.

Module E47LocalSpin2.
Definition Mat5 := nat -> nat -> Z.
Definition z (i j : nat) : Z :=
  if Nat.eqb i j then 2 - Z.of_nat i else 0.
Definition up (i j : nat) : Z :=
  if Nat.eqb (S i) j then Z.of_nat j * (5 - Z.of_nat j) else 0.
Definition down (i j : nat) : Z :=
  if Nat.eqb i (S j) then 1 else 0.
Definition mulEntry (A B : Mat5) (i j : nat) : Z :=
  fold_right Z.add 0 (map (fun k => A i k * B k j) (seq 0 5)).
Definition bracket (A B : Mat5) (i j : nat) : Z :=
  mulEntry A B i j - mulEntry B A i j.
Definition casimir (i j : nat) : Z :=
  mulEntry down up i j + mulEntry z z i j + z i j.
Definition allPairs (p : nat -> nat -> bool) : bool :=
  forallb (fun i => forallb (p i) (seq 0 5)) (seq 0 5).

Theorem z_up_all_entries :
  allPairs (fun i j => Z.eqb (bracket z up i j) (up i j)) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem z_down_all_entries :
  allPairs (fun i j => Z.eqb (bracket z down i j) (- down i j)) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem up_down_all_entries :
  allPairs (fun i j => Z.eqb (bracket up down i j) (2 * z i j)) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem local_casimir_is_six :
  allPairs (fun i j => Z.eqb (casimir i j)
    (if Nat.eqb i j then 6 else 0)) = true.
Proof. vm_compute. reflexivity. Qed.

Definition mutantUp (i j : nat) : Z :=
  up i j + (if andb (Nat.eqb i 0%nat) (Nat.eqb j 1%nat) then 1 else 0).
Theorem negative_control_rejected :
  Z.eqb (bracket mutantUp down 0%nat 0%nat) (2 * z 0%nat 0%nat) = false.
Proof. vm_compute. reflexivity. Qed.

End E47LocalSpin2.
Print Assumptions E47LocalSpin2.z_up_all_entries.
Print Assumptions E47LocalSpin2.z_down_all_entries.
Print Assumptions E47LocalSpin2.up_down_all_entries.
Print Assumptions E47LocalSpin2.local_casimir_is_six.
Print Assumptions E47LocalSpin2.negative_control_rejected.
