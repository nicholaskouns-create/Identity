(* Concrete 125-state spin-2 triple tensor, restricted to all weight-6 and
   weight-5 states. Import the canonical Tensor125 definitions; do not
   postulate a spectrum or alter the 125-term matrix multiplication.
   Scope: four-dimensional top-weight restriction only. *)
From Coq Require Import List Arith ZArith Bool Lia.
From E47 Require Import Tensor125.
Import ListNotations.
Open Scope Z_scope.

Module E47ConcreteTopWeight.

Definition topIndex (i : nat) : nat := nth i [0%nat; 1%nat; 5%nat; 25%nat] 0%nat.
Definition concrete (i j : nat) : Z :=
  mulEntry totalDown totalUp (topIndex i) (topIndex j) +
  (if Nat.eqb (topIndex i) (topIndex j) then
     totalZ (topIndex i) (topIndex i) * (totalZ (topIndex i) (topIndex i) + 1)
   else 0).
Definition model (i j : nat) : Z :=
  if Nat.eqb i 0 then (if Nat.eqb j 0 then 42 else 0)
  else if Nat.eqb j 0 then 0
  else if Nat.eqb i j then 34 else 4.
Definition mul4 (A B : nat -> nat -> Z) (i j : nat) : Z :=
  fold_right Z.add 0 (map (fun k => A i k * B k j) (seq 0 4)).
Definition eigenvectors : list (list Z) :=
  [[1;0;0;0]; [0;1;1;1]; [0;1;-1;0]; [0;1;0;-1]].
Definition scaledInverse : list (list Z) :=
  [[3;0;0;0]; [0;1;1;1]; [0;1;-2;1]; [0;1;1;-2]].
Definition S (i j : nat) : Z := nth j (nth i eigenvectors []) 0.
Definition B (i j : nat) : Z := nth j (nth i scaledInverse []) 0.
Definition spectralD (i j : nat) : Z :=
  if Nat.eqb i j then (if Nat.ltb i 2 then 42 else 30) else 0.
Definition quadraticResidual (A : nat -> nat -> Z) (i j : nat) : Z :=
  mul4 A A i j - 72 * A i j + (if Nat.eqb i j then 1260 else 0).
Definition all4 (p : nat -> nat -> bool) : bool :=
  forallb (fun i => forallb (fun j => p i j) (seq 0 4)) (seq 0 4).

Definition topWeightCheck : bool :=
  forallb (fun n =>
    Bool.eqb (Z.geb (totalZ n n) 5)
      (orb (Nat.eqb n 0%nat)
        (orb (Nat.eqb n 1%nat)
          (orb (Nat.eqb n 5%nat) (Nat.eqb n 25%nat))))) (seq 0 125).
Theorem complete_top_weight_set : topWeightCheck = true.
Proof. vm_compute. reflexivity. Qed.
Theorem concrete_entries :
  all4 (fun i j => Z.eqb (concrete i j) (model i j)) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem model_diagonalization :
  all4 (fun i j => Z.eqb (mul4 model S i j) (mul4 S spectralD i j)) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem left_inverse_scaled :
  all4 (fun i j => Z.eqb (mul4 B S i j) (if Nat.eqb i j then 3 else 0)) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem right_inverse_scaled :
  all4 (fun i j => Z.eqb (mul4 S B i j) (if Nat.eqb i j then 3 else 0)) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem concrete_quadratic_annihilator :
  all4 (fun i j => Z.eqb (quadraticResidual concrete i j) 0) = true.
Proof. vm_compute. reflexivity. Qed.
Definition mutant (i j : nat) : Z :=
  concrete i j + (if (Nat.eqb i 1%nat && Nat.eqb j 1%nat)%bool then 1 else 0).
Theorem mutant_rejected :
  negb (Z.eqb (quadraticResidual mutant 1%nat 1%nat) 0) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions complete_top_weight_set.
Print Assumptions concrete_entries.
Print Assumptions model_diagonalization.
Print Assumptions left_inverse_scaled.
Print Assumptions right_inverse_scaled.
Print Assumptions concrete_quadratic_annihilator.
Print Assumptions mutant_rejected.
End E47ConcreteTopWeight.
