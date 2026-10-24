(* A finite-register 47-state membership oracle. This does NOT certify the
   spin-2 Casimir or its projector. *)
From Coq Require Import Arith Bool List Lia.
Import ListNotations.

Definition member (n : nat) : bool := n <? 47.
Definition gate (n : nat) (target : bool) : bool :=
  if member n then negb target else target.

Theorem gate_involution : forall n target,
  gate n (gate n target) = target.
Proof.
  intros n target. unfold gate, member.
  destruct (n <? 47); destruct target; reflexivity.
Qed.

Theorem gate_flips_member : forall n target,
  n < 47 -> gate n target = negb target.
Proof.
  intros n target H. unfold gate, member.
  apply Nat.ltb_lt in H. rewrite H. reflexivity.
Qed.

Theorem gate_fixes_nonmember : forall n target,
  47 <= n -> gate n target = target.
Proof.
  intros n target H. unfold gate, member.
  apply Nat.ltb_ge in H. rewrite H. reflexivity.
Qed.

Theorem encoded_basis_count :
  length (filter (fun n => n <? 47) (seq 0 256)) = 47.
Proof. vm_compute. reflexivity. Qed.
