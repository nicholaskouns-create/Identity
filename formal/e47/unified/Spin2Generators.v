(* Concrete spin-2 five-by-five integer matrices, lane #15.
   All proofs enumerate the 25 matrix entries, without matrix assumptions. *)
From Coq Require Import ZArith Lia.
Open Scope Z_scope.

Definition mat5 := nat -> nat -> Z.

Definition z : mat5 := fun i j =>
  if Nat.eqb i j then 2 - Z.of_nat i else 0.

Definition up : mat5 := fun i j =>
  if Nat.eqb (S i) j
  then Z.of_nat j * (5 - Z.of_nat j)
  else 0.

Definition down : mat5 := fun i j =>
  if Nat.eqb i (S j) then 1 else 0.

Definition mul (a b : mat5) : mat5 := fun i j =>
  a i 0 * b 0 j + a i 1 * b 1 j + a i 2 * b 2 j +
  a i 3 * b 3 j + a i 4 * b 4 j.

Definition casimir : mat5 := fun i j =>
  mul z z i j + z i j + mul down up i j.

Theorem commutator_z_up : forall i j : nat,
  (i < 5)%nat -> (j < 5)%nat ->
  mul z up i j - mul up z i j = up i j.
Proof.
  intros i j Hi Hj.
  destruct i as [|[|[|[|[|i]]]]]; try lia;
  destruct j as [|[|[|[|[|j]]]]]; try lia;
  vm_compute; reflexivity.
Qed.

Theorem commutator_z_down : forall i j : nat,
  (i < 5)%nat -> (j < 5)%nat ->
  mul z down i j - mul down z i j = - down i j.
Proof.
  intros i j Hi Hj.
  destruct i as [|[|[|[|[|i]]]]]; try lia;
  destruct j as [|[|[|[|[|j]]]]]; try lia;
  vm_compute; reflexivity.
Qed.

Theorem commutator_up_down : forall i j : nat,
  (i < 5)%nat -> (j < 5)%nat ->
  mul up down i j - mul down up i j = 2 * z i j.
Proof.
  intros i j Hi Hj.
  destruct i as [|[|[|[|[|i]]]]]; try lia;
  destruct j as [|[|[|[|[|j]]]]]; try lia;
  vm_compute; reflexivity.
Qed.

Theorem spin2_casimir_scalar : forall i j : nat,
  (i < 5)%nat -> (j < 5)%nat ->
  casimir i j = if Nat.eqb i j then 6 else 0.
Proof.
  intros i j Hi Hj.
  destruct i as [|[|[|[|[|i]]]]]; try lia;
  destruct j as [|[|[|[|[|j]]]]]; try lia;
  vm_compute; reflexivity.
Qed.
