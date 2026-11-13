(* Canonical 125-state spin-2 triple tensor: exact weight-4 Casimir block.
   All six basis indices and every entry come from Tensor125's 125-term
   matrix products. No eigenvalue is assumed in constructing the block. *)
From Coq Require Import List Arith ZArith Bool.
From E47 Require Import Tensor125.
Import ListNotations.
Open Scope Z_scope.

Module E47ConcreteWeight4.

Definition blockIndex (i : nat) : nat :=
  nth i [2%nat;6%nat;10%nat;26%nat;30%nat;50%nat] 0%nat.
Definition fullCasimir (i j : nat) : Z :=
  mulEntry totalDown totalUp i j +
  (if Nat.eqb i j then totalZ i i * (totalZ i i + 1) else 0).
Definition concrete (i j : nat) : Z :=
  fullCasimir (blockIndex i) (blockIndex j).
Definition rows : list (list Z) :=
  [[26;4;0;4;0;0];
   [6;28;6;4;4;0];
   [0;4;26;0;4;0];
   [6;4;0;28;4;6];
   [0;4;6;4;28;6];
   [0;0;0;4;4;26]].
Definition model (i j : nat) : Z := nth j (nth i rows []) 0.
Definition mul6 (A B : nat -> nat -> Z) (i j : nat) : Z :=
  fold_right Z.add 0 (map (fun k => A i k * B k j) (seq 0 6)).
Definition sRows : list (list Z) :=
  [[2;4;2;-1;0;1];
   [-3;-3;0;0;-1;2];
   [2;0;0;1;-1;1];
   [0;-3;-3;-1;1;2];
   [0;3;0;1;0;2];
   [0;0;2;0;1;1]].
Definition bRows : list (list Z) :=
  [[45;-105;210;60;-105;45];
   [60;-30;-105;-30;135;-105];
   [45;60;45;-105;-105;210];
   [-330;-110;165;-110;220;165];
   [-165;-220;-165;110;110;330];
   [75;100;75;100;100;75]].
Definition S (i j : nat) : Z := nth j (nth i sRows []) 0.
Definition B (i j : nat) : Z := nth j (nth i bRows []) 0.
Definition spectralD (i j : nat) : Z :=
  if Nat.eqb i j then
    (if Nat.ltb i 3 then 20 else if Nat.ltb i 5 then 30 else 42)
  else 0.
Definition cubicResidual (A : nat -> nat -> Z) (i j : nat) : Z :=
  mul6 (mul6 A A) A i j - 92 * mul6 A A i j +
  2700 * A i j - (if Nat.eqb i j then 25200 else 0).
Definition all6 (p : nat -> nat -> bool) : bool :=
  forallb (fun i => forallb (fun j => p i j) (seq 0 6)) (seq 0 6).
Definition weight4Member (n : nat) : bool :=
  orb (Nat.eqb n 2%nat)
    (orb (Nat.eqb n 6%nat)
      (orb (Nat.eqb n 10%nat)
        (orb (Nat.eqb n 26%nat)
          (orb (Nat.eqb n 30%nat) (Nat.eqb n 50%nat))))).
Definition weight4Check : bool :=
  forallb (fun n => Bool.eqb (Z.eqb (totalZ n n) 4)
    (weight4Member n)) (seq 0 125).
Theorem complete_weight4_set : weight4Check = true.
Proof. vm_compute. reflexivity. Qed.
Theorem concrete_entries :
  all6 (fun i j => Z.eqb (concrete i j) (model i j)) = true.
Proof. vm_compute. reflexivity. Qed.
Definition blockColumnCheck : bool :=
  forallb (fun i => forallb (fun n =>
    if Z.eqb (totalZ n n) 4 then true
    else Z.eqb (fullCasimir n (blockIndex i)) 0)
    (seq 0 125)) (seq 0 6).
Theorem block_column_invariance : blockColumnCheck = true.
Proof. vm_compute. reflexivity. Qed.
Theorem model_diagonalization :
  all6 (fun i j => Z.eqb (mul6 model S i j) (mul6 S spectralD i j)) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem left_inverse_scaled :
  all6 (fun i j => Z.eqb (mul6 B S i j)
    (if Nat.eqb i j then 825 else 0)) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem right_inverse_scaled :
  all6 (fun i j => Z.eqb (mul6 S B i j)
    (if Nat.eqb i j then 825 else 0)) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem concrete_cubic_annihilator :
  all6 (fun i j => Z.eqb (cubicResidual concrete i j) 0) = true.
Proof. vm_compute. reflexivity. Qed.
Definition mutant (i j : nat) : Z :=
  model i j + (if (Nat.eqb i 1%nat && Nat.eqb j 1%nat)%bool then 1 else 0).
Theorem mutant_rejected :
  negb (Z.eqb (cubicResidual mutant 1%nat 1%nat) 0) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions complete_weight4_set.
Print Assumptions concrete_entries.
Print Assumptions block_column_invariance.
Print Assumptions model_diagonalization.
Print Assumptions left_inverse_scaled.
Print Assumptions right_inverse_scaled.
Print Assumptions concrete_cubic_annihilator.
Print Assumptions mutant_rejected.
End E47ConcreteWeight4.
