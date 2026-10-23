(* Self-contained Rocq/Coq certificate for the same integers checked by
   E47Spectral.lean and simulation/e47_tqgnn/spectral.py.
   This file does not formalize the 125-by-125 carrier matrices. *)

From Coq Require Import List PeanoNat ZArith.
Import ListNotations.

Fixpoint seq_from (lo len : nat) : list nat :=
  match len with
  | 0 => []
  | S n => lo :: seq_from (S lo) n
  end.

Definition couple (j1 j2 : nat) : list nat :=
  let lo := Nat.max (j1 - j2) (j2 - j1) in
  seq_from lo (j1 + j2 - lo + 1).

Definition threeSpin2 : list nat :=
  flat_map (fun j => couple j 2) (couple 2 2).

Fixpoint count (j : nat) (xs : list nat) : nat :=
  match xs with
  | [] => 0
  | x :: t => (if Nat.eqb x j then 1 else 0) + count j t
  end.

Definition casimir (j : nat) : nat := j * (j + 1).

Lemma spin2_triple_multiplicities :
  count 0 threeSpin2 = 1 /\ count 1 threeSpin2 = 3 /\ count 2 threeSpin2 = 5 /\
  count 3 threeSpin2 = 4 /\ count 4 threeSpin2 = 3 /\ count 5 threeSpin2 = 2 /\
  count 6 threeSpin2 = 1.
Proof. vm_compute. repeat split; reflexivity. Qed.

Lemma carrier_dimension :
  count 0 threeSpin2 * (2 * 0 + 1) + count 1 threeSpin2 * (2 * 1 + 1) +
  count 2 threeSpin2 * (2 * 2 + 1) + count 3 threeSpin2 * (2 * 3 + 1) +
  count 4 threeSpin2 * (2 * 4 + 1) + count 5 threeSpin2 * (2 * 5 + 1) +
  count 6 threeSpin2 * (2 * 6 + 1) = 125.
Proof. vm_compute. reflexivity. Qed.

Lemma casimir_nodes :
  map casimir (seq 0 7) = [0; 2; 6; 12; 20; 30; 42].
Proof. vm_compute. reflexivity. Qed.

Lemma kernel_rank :
  count 2 threeSpin2 * (2 * 2 + 1) + count 5 threeSpin2 * (2 * 5 + 1) = 47.
Proof. vm_compute. reflexivity. Qed.

Open Scope Z_scope.

Definition lam (c : Z) : Z := (c - 6) * (c - 30).

Definition gap (c : Z) : Z := Z.abs (99144 - lam c * lam c).

Lemma kernel_polynomial_vanishes : lam 6 = 0 /\ lam 30 = 0.
Proof. vm_compute. split; reflexivity. Qed.

Lemma kernel_gamma_is_one : gap 6 = 99144 /\ gap 30 = 99144.
Proof. vm_compute. split; reflexivity. Qed.

Lemma denominator_from_highest_weight :
  (42 - 6) * (42 - 30) * ((42 - 6) * (42 - 30)) * 17 = 99144 * 32.
Proof. vm_compute. reflexivity. Qed.

Lemma complement_contracts :
  Z.ltb (gap 0 * 17) (15 * 99144) = true /\
  Z.ltb (gap 2 * 17) (15 * 99144) = true /\
  gap 12 * 17 = 15 * 99144 /\
  Z.ltb (gap 20 * 17) (15 * 99144) = true /\
  gap 42 * 17 = 15 * 99144.
Proof. vm_compute. repeat split; reflexivity. Qed.
