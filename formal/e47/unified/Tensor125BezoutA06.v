(* E47-A06: exact integer coefficient certificate for the polynomial
   Bezout identity. No matrix spectrum, annihilator or rank is assumed.
   Coefficients 0..6 use exact finite convolution; higher-degree
   coefficients are outside the stated bounded theorem. *)
From Coq Require Import ZArith Arith List Lia.
Import ListNotations.
Open Scope Z_scope.

Definition poly7 := nat -> Z.

Definition factor (r : Z) : poly7 := fun i =>
  if Nat.eqb i 0 then -r else if Nat.eqb i 1 then 1 else 0.

Definition pmul (p q : poly7) (i : nat) : Z :=
  List.fold_right Z.add 0
    (List.map (fun k => p k * q (i - k)%nat) (List.seq 0 (S i))).

Definition tPoly : poly7 :=
  pmul (pmul (pmul (pmul (pmul
    (factor 0) (factor 2)) (factor 12)) (factor 20)) (factor 31)) (factor 42).

Definition kPoly : poly7 := pmul (factor 6) (factor 30).

Definition qPoly : poly7 := fun i =>
  if Nat.eqb i 0 then 10080
  else if Nat.eqb i 1 then 5488
  else if Nat.eqb i 2 then -1352
  else if Nat.eqb i 3 then 71
  else if Nat.eqb i 4 then -1
  else 0.

Definition constant (n : Z) : poly7 :=
  fun i => if Nat.eqb i 0 then n else 0.

Theorem bezout_coefficients :
  forall i, (i < 7)%nat ->
    tPoly i + pmul kPoly qPoly i = constant 1814400 i.
Proof.
  intros i Hi.
  destruct i as [|i]; [vm_compute; reflexivity|].
  destruct i as [|i]; [vm_compute; reflexivity|].
  destruct i as [|i]; [vm_compute; reflexivity|].
  destruct i as [|i]; [vm_compute; reflexivity|].
  destruct i as [|i]; [vm_compute; reflexivity|].
  destruct i as [|i]; [vm_compute; reflexivity|].
  destruct i as [|i]; [vm_compute; reflexivity|].
  lia.
Qed.

Definition eval7 (p : poly7) (x : Z) : Z :=
  List.fold_right Z.add 0
    (List.map (fun i => p i * Z.pow x (Z.of_nat i)) (List.seq 0 7)).

Theorem selected_values :
  eval7 tPoly 6 = 1814400 /\ eval7 tPoly 30 = 1814400.
Proof. vm_compute; split; reflexivity. Qed.

Theorem bezout_evaluations :
  forall x : Z,
    eval7 (fun i => tPoly i + pmul kPoly qPoly i) x =
    eval7 (constant 1814400) x.
Proof.
  intro x.
  unfold eval7.
  f_equal.
  apply List.map_ext_in.
  intros i Hi.
  rewrite bezout_coefficients.
  - reflexivity.
  - apply List.in_seq in Hi. lia.
Qed.

Print Assumptions bezout_coefficients.
Print Assumptions selected_values.
Print Assumptions bezout_evaluations.
