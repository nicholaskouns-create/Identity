(* E47 paired bridge: exact three-factor tensor lift of the concrete
   125-state generators. The local 5-state operators are lifted with
   Kronecker deltas, then compared with Tensor125's literal entries.
   No full Lie-bracket or Casimir-spectrum claim is made here. *)
From Coq Require Import ZArith Arith Bool List.
Import ListNotations.
Open Scope Z_scope.
Module E47TensorLiftParity.
Definition Mat5 := nat -> nat -> Z.
Definition Mat125 := nat -> nat -> Z.
Definition a (n : nat) : nat := (n / 25)%nat.
Definition b (n : nat) : nat := ((n / 5) mod 5)%nat.
Definition c (n : nat) : nat := (n mod 5)%nat.
Definition delta (i j : nat) : Z := if Nat.eqb i j then 1 else 0.
Definition z5 (i j : nat) : Z :=
  if Nat.eqb i j then 2 - Z.of_nat i else 0.
Definition up5 (i j : nat) : Z :=
  if Nat.eqb (S i) j then Z.of_nat j * (5 - Z.of_nat j) else 0.
Definition down5 (i j : nat) : Z :=
  if Nat.eqb i (S j) then 1 else 0.
Definition lift (g : Mat5) (i j : nat) : Z :=
  g (a i) (a j) * delta (b i) (b j) * delta (c i) (c j) +
  delta (a i) (a j) * g (b i) (b j) * delta (c i) (c j) +
  delta (a i) (a j) * delta (b i) (b j) * g (c i) (c j).

(* Independently written literal counterparts of Tensor125.v. *)
Definition tensorZ (i j : nat) : Z :=
  if Nat.eqb i j then 6 - Z.of_nat (a i) - Z.of_nat (b i) - Z.of_nat (c i)
  else 0.
Definition tensorUp (i j : nat) : Z :=
  (if (Nat.eqb (S (a i)) (a j) && Nat.eqb (b i) (b j) && Nat.eqb (c i) (c j))%bool
    then Z.of_nat (a j) * (5 - Z.of_nat (a j)) else 0) +
  (if (Nat.eqb (a i) (a j) && Nat.eqb (S (b i)) (b j) && Nat.eqb (c i) (c j))%bool
    then Z.of_nat (b j) * (5 - Z.of_nat (b j)) else 0) +
  (if (Nat.eqb (a i) (a j) && Nat.eqb (b i) (b j) && Nat.eqb (S (c i)) (c j))%bool
    then Z.of_nat (c j) * (5 - Z.of_nat (c j)) else 0).
Definition tensorDown (i j : nat) : Z :=
  (if (Nat.eqb (a i) (S (a j)) && Nat.eqb (b i) (b j) && Nat.eqb (c i) (c j))%bool then 1 else 0) +
  (if (Nat.eqb (a i) (a j) && Nat.eqb (b i) (S (b j)) && Nat.eqb (c i) (c j))%bool then 1 else 0) +
  (if (Nat.eqb (a i) (a j) && Nat.eqb (b i) (b j) && Nat.eqb (c i) (S (c j)))%bool then 1 else 0).
Definition allPairs (p : nat -> nat -> bool) : bool :=
  forallb (fun i => forallb (p i) (seq 0 125)) (seq 0 125).

Theorem tensor_index_roundtrip :
  forallb (fun n => Nat.eqb (25 * a n + 5 * b n + c n)%nat n)
    (seq 0 125) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem tensor_z_is_three_factor_lift :
  allPairs (fun i j => Z.eqb (lift z5 i j) (tensorZ i j)) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem tensor_up_is_three_factor_lift :
  allPairs (fun i j => Z.eqb (lift up5 i j) (tensorUp i j)) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem tensor_down_is_three_factor_lift :
  allPairs (fun i j => Z.eqb (lift down5 i j) (tensorDown i j)) = true.
Proof. vm_compute. reflexivity. Qed.

Definition mutantUp5 (i j : nat) : Z :=
  up5 i j + (if (Nat.eqb i 0%nat && Nat.eqb j 1%nat)%bool then 1 else 0).
Theorem mutated_local_generator_rejected :
  Z.eqb (lift mutantUp5 0%nat 25%nat) (tensorUp 0%nat 25%nat) = false.
Proof. vm_compute. reflexivity. Qed.
End E47TensorLiftParity.
Print Assumptions E47TensorLiftParity.tensor_index_roundtrip.
Print Assumptions E47TensorLiftParity.tensor_z_is_three_factor_lift.
Print Assumptions E47TensorLiftParity.tensor_up_is_three_factor_lift.
Print Assumptions E47TensorLiftParity.tensor_down_is_three_factor_lift.
Print Assumptions E47TensorLiftParity.mutated_local_generator_rejected.
