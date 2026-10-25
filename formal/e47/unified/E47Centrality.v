(* E47-CORE-004: Casimir centrality against the weight operator.
   Rocq/Coq mirror of formal/e47/unified/E47Centrality.lean.
   Proof Forge lane #17, the [C, Z] = 0 half.

   A brute-force enumeration of all 15625 entries of the 125-term product
   exhausts memory (measured in Lean: OOM-killed at 10 minutes). The proof
   here is structural instead, and is therefore stronger: the vanishing is
   derived from how the generators move weight.

   OPEN: [C,U] = 0 and [C,D] = 0 are NOT proved, so C is not shown central
   in the full algebra; and the identification of C's eigenspaces with the
   spin blocks (lane #19) remains open, hence so does
   dim ker (C-6I)(C-30I) = 47 for the full matrix. *)

From Coq Require Import List Arith ZArith Lia Bool.
Import ListNotations.
Open Scope Z_scope.

Module E47Centrality.

Definition aa (n : nat) : nat := Nat.div n 25.
Definition bb (n : nat) : nat := Nat.modulo (Nat.div n 5) 5.
Definition cc (n : nat) : nat := Nat.modulo n 5.

Definition w (i : nat) : Z :=
  6 - Z.of_nat (aa i) - Z.of_nat (bb i) - Z.of_nat (cc i).

Definition states : list nat := seq 0 125.

(* Raising adds one quantum in one factor; lowering removes one. *)
Definition totalUp (k j : nat) : Z :=
  (if andb (Nat.eqb (aa k + 1) (aa j))
      (andb (Nat.eqb (bb k) (bb j)) (Nat.eqb (cc k) (cc j)))
   then Z.of_nat (aa j) * (5 - Z.of_nat (aa j)) else 0) +
  (if andb (Nat.eqb (aa k) (aa j))
      (andb (Nat.eqb (bb k + 1) (bb j)) (Nat.eqb (cc k) (cc j)))
   then Z.of_nat (bb j) * (5 - Z.of_nat (bb j)) else 0) +
  (if andb (Nat.eqb (aa k) (aa j))
      (andb (Nat.eqb (bb k) (bb j)) (Nat.eqb (cc k + 1) (cc j)))
   then Z.of_nat (cc j) * (5 - Z.of_nat (cc j)) else 0).

Definition totalDown (i k : nat) : Z :=
  (if andb (Nat.eqb (aa i) (aa k + 1))
      (andb (Nat.eqb (bb i) (bb k)) (Nat.eqb (cc i) (cc k))) then 1 else 0) +
  (if andb (Nat.eqb (aa i) (aa k))
      (andb (Nat.eqb (bb i) (bb k + 1)) (Nat.eqb (cc i) (cc k))) then 1 else 0) +
  (if andb (Nat.eqb (aa i) (aa k))
      (andb (Nat.eqb (bb i) (bb k)) (Nat.eqb (cc i) (cc k + 1))) then 1 else 0).

(* The genuine 125-term product entry. *)
Definition mulEntry (A B : nat -> nat -> Z) (i j : nat) : Z :=
  fold_left Z.add (map (fun k => A i k * B k j) states) 0.

Definition casimirEntry (i j : nat) : Z :=
  mulEntry totalDown totalUp i j +
  (if Nat.eqb i j then w i * (w i + 1) else 0).

(* ---- structural lemmas, as decidable boolean checks ---------------------- *)

Definition downCheck : bool :=
  forallb (fun i => forallb (fun k =>
    implb (negb (Z.eqb (totalDown i k) 0)) (Z.eqb (w k) (w i + 1)))
    states) states.

Definition upCheck : bool :=
  forallb (fun k => forallb (fun j =>
    implb (negb (Z.eqb (totalUp k j) 0)) (Z.eqb (w k) (w j + 1)))
    states) states.

Lemma down_check_holds : downCheck = true.
Proof. vm_compute. reflexivity. Qed.

Lemma up_check_holds : upCheck = true.
Proof. vm_compute. reflexivity. Qed.

Lemma down_shifts_weight :
  forall i k, In i states -> In k states ->
  totalDown i k <> 0 -> w k = w i + 1.
Proof.
  intros i k Hi Hk Hne.
  pose proof down_check_holds as H.
  unfold downCheck in H.
  rewrite forallb_forall in H. specialize (H i Hi).
  rewrite forallb_forall in H. specialize (H k Hk).
  destruct (Z.eqb (totalDown i k) 0) eqn:E; simpl in H.
  - apply Z.eqb_eq in E. contradiction.
  - apply Z.eqb_eq. exact H.
Qed.

Lemma up_shifts_weight :
  forall k j, In k states -> In j states ->
  totalUp k j <> 0 -> w k = w j + 1.
Proof.
  intros k j Hk Hj Hne.
  pose proof up_check_holds as H.
  unfold upCheck in H.
  rewrite forallb_forall in H. specialize (H k Hk).
  rewrite forallb_forall in H. specialize (H j Hj).
  destruct (Z.eqb (totalUp k j) 0) eqn:E; simpl in H.
  - apply Z.eqb_eq in E. contradiction.
  - apply Z.eqb_eq. exact H.
Qed.

(* A left fold of additions over all-zero terms is zero. *)
Lemma fold_add_zero :
  forall (l : list nat) (g : nat -> Z) (acc : Z),
    (forall x, In x l -> g x = 0) ->
    fold_left Z.add (map g l) acc = acc.
Proof.
  induction l as [| x t IH]; intros g acc H; simpl.
  - reflexivity.
  - rewrite (H x (or_introl eq_refl)). rewrite Z.add_0_r.
    apply IH. intros y Hy. apply H. right. exact Hy.
Qed.

(* The structural step. *)
Theorem product_vanishes_across_weights :
  forall i j, In i states -> In j states ->
  w i <> w j -> mulEntry totalDown totalUp i j = 0.
Proof.
  intros i j Hi Hj Hij. unfold mulEntry.
  rewrite (fold_add_zero states (fun k => totalDown i k * totalUp k j) 0).
  - reflexivity.
  - intros k Hk.
    destruct (Z.eq_dec (totalDown i k) 0) as [Hd | Hd].
    + rewrite Hd. ring.
    + destruct (Z.eq_dec (totalUp k j) 0) as [Hu | Hu].
      * rewrite Hu. ring.
      * exfalso.
        pose proof (down_shifts_weight i k Hi Hk Hd) as H1.
        pose proof (up_shifts_weight k j Hk Hj Hu) as H2.
        apply Hij. lia.
Qed.

Theorem casimir_preserves_weight_spaces :
  forall i j, In i states -> In j states ->
  w i <> w j -> casimirEntry i j = 0.
Proof.
  intros i j Hi Hj Hij. unfold casimirEntry.
  rewrite (product_vanishes_across_weights i j Hi Hj Hij).
  destruct (Nat.eqb i j) eqn:E.
  - apply Nat.eqb_eq in E. subst. contradiction.
  - ring.
Qed.

(* Lane #17, the Z half: every entry of [C, Z] vanishes. *)
Definition commutatorCZ (i j : nat) : Z := casimirEntry i j * (w j - w i).

Theorem casimir_commutes_with_weight :
  forall i j, In i states -> In j states -> commutatorCZ i j = 0.
Proof.
  intros i j Hi Hj. unfold commutatorCZ.
  destruct (Z.eq_dec (w i) (w j)) as [He | Hne].
  - rewrite He. ring.
  - rewrite (casimir_preserves_weight_spaces i j Hi Hj Hne). ring.
Qed.

End E47Centrality.
