(* Exact weight-3 Casimir block imported from canonical Tensor125.v.
   All concrete entries use the full 125-term integer matrix product. *)
From Coq Require Import List Arith ZArith Bool Lia.
From E47 Require Import Tensor125.
Import ListNotations.
Open Scope Z_scope.
Module E47ConcreteWeight3.
Definition indices : list nat := [3%nat; 7%nat; 11%nat; 15%nat; 27%nat; 31%nat; 35%nat; 51%nat; 55%nat; 75%nat].
Definition blockIndex (i : nat) : nat := nth i indices 0%nat.
Definition fullCasimir (i j : nat) : Z :=
  mulEntry totalDown totalUp i j +
  (if Nat.eqb i j then totalZ i i * (totalZ i i + 1) else 0).
Definition concrete (i j : nat) : Z := fullCasimir (blockIndex i) (blockIndex j).
Definition rows : list (list Z) := [
  [18; 4; 0; 0; 4; 0; 0; 0; 0; 0];
  [6; 22; 6; 0; 4; 4; 0; 0; 0; 0];
  [0; 6; 22; 6; 0; 4; 4; 0; 0; 0];
  [0; 0; 4; 18; 0; 0; 4; 0; 0; 0];
  [6; 4; 0; 0; 22; 4; 0; 6; 0; 0];
  [0; 6; 6; 0; 6; 24; 6; 6; 6; 0];
  [0; 0; 4; 6; 0; 4; 22; 0; 6; 0];
  [0; 0; 0; 0; 6; 4; 0; 22; 4; 6];
  [0; 0; 0; 0; 0; 4; 6; 4; 22; 6];
  [0; 0; 0; 0; 0; 0; 0; 4; 4; 18]
].
Definition model (i j : nat) : Z := nth j (nth i rows []) 0.
Definition mul10 (X Y : nat -> nat -> Z) (i j : nat) : Z :=
  fold_right Z.add 0 (map (fun k => X i k * Y k j) (seq 0 10)).
Definition sRows : list (list Z) := [
  [-2; -4; -4; -2; 2; 2; 4; -1; 1; 1];
  [3; 4; 2; 0; -1; 5; 1; -1; 0; 3];
  [-3; -2; 0; 0; -1; -3; 3; 1; -3; 3];
  [2; 0; 0; 0; 2; -6; 6; 1; -2; 1];
  [0; 2; 4; 3; 2; -4; 1; -2; 3; 3];
  [0; -3; -3; 0; -3; 3; -12; 0; 0; 6];
  [0; 2; 0; 0; 2; 0; 0; 2; -3; 3];
  [0; 0; -2; -3; 0; -6; 3; -1; 3; 3];
  [0; 0; 2; 0; 0; 6; 0; 1; 0; 3];
  [0; 0; 0; 2; 0; 0; 6; 0; 1; 1]
].
Definition bRows : list (list Z) := [
  [-22; 66; -154; 308; -44; 88; -154; -44; 66; -22];
  [-66; 88; -22; -231; -22; -66; 253; 88; -187; 99];
  [-66; -22; 88; 99; 88; -66; -187; -22; 253; -231];
  [-22; -44; -44; -22; 66; 88; 66; -154; -154; 308];
  [162; -72; -138; 63; 126; -30; 159; -72; 27; -135];
  [54; 42; -24; -45; -24; -10; 9; -46; 53; 21];
  [18; 36; 36; 18; -30; -40; -30; 14; 14; 84];
  [-264; -352; -176; 0; -176; 0; 176; 176; 352; 264];
  [-88; -176; -176; -88; 0; 0; 0; 176; 176; 176];
  [24; 48; 48; 24; 48; 64; 48; 48; 48; 24]
].
Definition eigenvalues : list Z := [12; 12; 12; 12; 20; 20; 20; 30; 30; 42].
Definition S (i j : nat) : Z := nth j (nth i sRows []) 0.
Definition B (i j : nat) : Z := nth j (nth i bRows []) 0.
Definition spectralD (i j : nat) : Z :=
  if Nat.eqb i j then nth i eigenvalues 0 else 0.
Definition quarticResidual (X : nat -> nat -> Z) (i j : nat) : Z :=
  mul10 (mul10 (mul10 X X) X) X i j -
  104 * mul10 (mul10 X X) X i j +
  3804 * mul10 X X i j - 57600 * X i j +
  (if Nat.eqb i j then 302400 else 0).
Definition all10 (p : nat -> nat -> bool) : bool :=
  forallb (fun i => forallb (fun j => p i j) (seq 0 10)) (seq 0 10).
Definition weight3Check : bool :=
  forallb (fun n => Bool.eqb (Z.eqb (totalZ n n) 3)
    (existsb (Nat.eqb n) indices)) (seq 0 125).
Theorem complete_weight3_set : weight3Check = true.
Proof. vm_compute. reflexivity. Qed.
Theorem concrete_entries :
  all10 (fun i j => Z.eqb (concrete i j) (model i j)) = true.
Proof. vm_compute. reflexivity. Qed.
Definition blockColumnCheck : bool :=
  forallb (fun i => forallb (fun n =>
    if Z.eqb (totalZ n n) 3 then true
    else Z.eqb (fullCasimir n (blockIndex i)) 0)
    (seq 0 125)) (seq 0 10).
Theorem block_column_invariance : blockColumnCheck = true.
Proof. vm_compute. reflexivity. Qed.
Theorem model_diagonalization :
  all10 (fun i j => Z.eqb (mul10 model S i j) (mul10 S spectralD i j)) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem left_inverse_scaled :
  all10 (fun i j => Z.eqb (mul10 B S i j)
    (if Nat.eqb i j then 1320 else 0)) = true.
Proof. vm_compute. reflexivity. Qed.
Theorem right_inverse_scaled :
  all10 (fun i j => Z.eqb (mul10 S B i j)
    (if Nat.eqb i j then 1320 else 0)) = true.
Proof. vm_compute. reflexivity. Qed.
(* Bounded 10-state transport avoids repeatedly expanding 125-term
   Casimir products inside a quartic matrix polynomial. The exact concrete
   entry certificate above is retained and used, not replaced by a model
   assumption. *)
Lemma concrete_equals_model_in_block :
  forall i j, (i < 10)%nat -> (j < 10)%nat ->
    concrete i j = model i j.
Proof.
  intros i j Hi Hj.
  pose proof concrete_entries as H.
  unfold all10 in H.
  rewrite forallb_forall in H.
  assert (HinI : In i (seq 0 10)) by (apply in_seq; lia).
  specialize (H i HinI).
  rewrite forallb_forall in H.
  assert (HinJ : In j (seq 0 10)) by (apply in_seq; lia).
  specialize (H j HinJ).
  apply (proj1 (Z.eqb_eq _ _)) in H.
  exact H.
Qed.

Lemma mul10_ext :
  forall X Y X' Y' i j,
    (forall a b, (a < 10)%nat -> (b < 10)%nat -> X a b = X' a b) ->
    (forall a b, (a < 10)%nat -> (b < 10)%nat -> Y a b = Y' a b) ->
    (i < 10)%nat -> (j < 10)%nat ->
    mul10 X Y i j = mul10 X' Y' i j.
Proof.
  intros X Y X' Y' i j HX HY Hi Hj.
  unfold mul10.
  apply f_equal.
  apply map_ext_in.
  intros k Hk.
  assert (Hk10 : (k < 10)%nat) by (apply in_seq in Hk; lia).
  now rewrite (HX i k Hi Hk10), (HY k j Hk10 Hj).
Qed.

Lemma quarticResidual_ext :
  forall X Y i j,
    (forall a b, (a < 10)%nat -> (b < 10)%nat -> X a b = Y a b) ->
    (i < 10)%nat -> (j < 10)%nat ->
    quarticResidual X i j = quarticResidual Y i j.
Proof.
  intros X Y i j H Hi Hj.
  assert (H2 : forall a b, (a < 10)%nat -> (b < 10)%nat ->
    mul10 X X a b = mul10 Y Y a b).
  { intros a b Ha Hb. eapply mul10_ext; eauto. }
  assert (H3 : forall a b, (a < 10)%nat -> (b < 10)%nat ->
    mul10 (mul10 X X) X a b = mul10 (mul10 Y Y) Y a b).
  { intros a b Ha Hb. eapply mul10_ext; eauto. }
  assert (H4 : forall a b, (a < 10)%nat -> (b < 10)%nat ->
    mul10 (mul10 (mul10 X X) X) X a b =
    mul10 (mul10 (mul10 Y Y) Y) Y a b).
  { intros a b Ha Hb. eapply mul10_ext; eauto. }
  unfold quarticResidual.
  rewrite (H4 i j Hi Hj), (H3 i j Hi Hj).
  rewrite (H2 i j Hi Hj), (H i j Hi Hj).
  reflexivity.
Qed.

Lemma model_quartic_annihilator :
  all10 (fun i j => Z.eqb (quarticResidual model i j) 0) = true.
Proof. vm_compute. reflexivity. Qed.

Theorem concrete_quartic_annihilator :
  all10 (fun i j => Z.eqb (quarticResidual concrete i j) 0) = true.
Proof.
  unfold all10.
  rewrite forallb_forall.
  intros i Hi.
  rewrite forallb_forall.
  intros j Hj.
  pose proof model_quartic_annihilator as Hmodel.
  unfold all10 in Hmodel.
  rewrite forallb_forall in Hmodel.
  specialize (Hmodel i Hi).
  rewrite forallb_forall in Hmodel.
  specialize (Hmodel j Hj).
  assert (Hi10 : (i < 10)%nat) by (apply in_seq in Hi; lia).
  assert (Hj10 : (j < 10)%nat) by (apply in_seq in Hj; lia).
  rewrite (quarticResidual_ext concrete model i j
    concrete_equals_model_in_block Hi10 Hj10).
  exact Hmodel.
Qed.
Definition mutant (i j : nat) : Z :=
  model i j + (if (Nat.eqb i 1%nat && Nat.eqb j 1%nat)%bool then 1 else 0).
Theorem mutant_rejected :
  negb (Z.eqb (quarticResidual mutant 1%nat 1%nat) 0) = true.
Proof. vm_compute. reflexivity. Qed.
Print Assumptions complete_weight3_set.
Print Assumptions concrete_entries.
Print Assumptions block_column_invariance.
Print Assumptions model_diagonalization.
Print Assumptions left_inverse_scaled.
Print Assumptions right_inverse_scaled.
Print Assumptions concrete_quartic_annihilator.
Print Assumptions mutant_rejected.
End E47ConcreteWeight3.
