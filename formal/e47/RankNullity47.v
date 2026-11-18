(*
   RankNullity47.v — the general rank-nullity identity for a graded carrier,
   with the E47 values as specialised read-outs. Coq companion to
   RankNullity47.lean.

   This is the second of the two instruments the Historical Accordance record
   declares but which had no file in the tree. It exists now.

   STATUS: PROVED. Compiled clean on Coq 8.18.0. Standard library only; no
   Admitted, no axioms. Print Assumptions returns "Closed under the global
   context" for all eight theorems -- strictly cleaner than the Lean
   companion, which carries propext and Quot.sound from its own foundations.

   Same design as the Lean file: no numeral occurs in `rank_nullity`; the
   seven isotypic sectors and the selector of K = (C - 6I)(C - 30I) appear
   only as an instance; and e47_rank_nullity is obtained by `apply
   rank_nullity`, not by recomputation.
*)

Require Import List ZArith Lia.
Import ListNotations.
Open Scope Z_scope.

Module RankNullity47.

(** A graded carrier is a list of sectors, each carrying an eigenvalue
    and a dimension. *)
Record Sector := { eigen : Z ; dim : nat }.
Definition Carrier := list Sector.

Fixpoint total (C : Carrier) : nat :=
  match C with
  | [] => 0%nat
  | s :: r => (dim s + total r)%nat
  end.

Definition nullity (P : Z -> bool) (C : Carrier) : nat :=
  total (filter (fun s => P (eigen s)) C).

Definition rank (P : Z -> bool) (C : Carrier) : nat :=
  total (filter (fun s => negb (P (eigen s))) C).

(** THE GENERAL IDENTITY. No numeral appears in this statement. *)
Theorem rank_nullity : forall (P : Z -> bool) (C : Carrier),
  (rank P C + nullity P C)%nat = total C.
Proof.
  intros P C. induction C as [| s r IH].
  - reflexivity.
  - unfold rank, nullity in *. simpl.
    destruct (P (eigen s)) eqn:H; simpl; lia.
Qed.

Theorem nullity_le_total : forall (P : Z -> bool) (C : Carrier),
  (nullity P C <= total C)%nat.
Proof. intros P C. pose proof (rank_nullity P C). lia. Qed.

Theorem rank_from_nullity : forall (P : Z -> bool) (C : Carrier),
  nullity P C = 47%nat -> total C = 125%nat -> rank P C = 78%nat.
Proof. intros P C Hn Ht. pose proof (rank_nullity P C). lia. Qed.

Theorem nullity_determined : forall (P : Z -> bool) (C : Carrier) (r : nat),
  rank P C = r -> nullity P C = (total C - r)%nat.
Proof. intros P C r Hr. pose proof (rank_nullity P C). lia. Qed.

(** * The E47 carrier as a specialised read-out.
    The numerals live here and nowhere in the general statement. *)

Definition e47Carrier : Carrier :=
  [ {| eigen := 0;  dim := 1  |} ;
    {| eigen := 2;  dim := 9  |} ;
    {| eigen := 6;  dim := 25 |} ;
    {| eigen := 12; dim := 28 |} ;
    {| eigen := 20; dim := 27 |} ;
    {| eigen := 30; dim := 22 |} ;
    {| eigen := 42; dim := 13 |} ].

(** The annihilating predicate of K = (C - 6I)(C - 30I). *)
Definition selK (x : Z) : bool := orb (Z.eqb x 6) (Z.eqb x 30).

Theorem selK_iff_selector : forall x : Z,
  selK x = true <-> (x - 6) * (x - 30) = 0.
Proof.
  intro x. unfold selK. split.
  - intro H. apply Bool.orb_true_iff in H. destruct H as [H | H];
    apply Z.eqb_eq in H; subst; ring.
  - intro H. apply Z.mul_eq_0 in H. apply Bool.orb_true_iff.
    destruct H as [H | H]; [left | right]; apply Z.eqb_eq; lia.
Qed.

Theorem e47_total   : total e47Carrier = 125%nat.
Proof. reflexivity. Qed.

Theorem e47_nullity : nullity selK e47Carrier = 47%nat.
Proof. reflexivity. Qed.

Theorem e47_rank    : rank selK e47Carrier = 78%nat.
Proof. reflexivity. Qed.

(** 78 + 47 = 125, obtained by SPECIALISING the general theorem. *)
Theorem e47_rank_nullity :
  (rank selK e47Carrier + nullity selK e47Carrier)%nat = total e47Carrier.
Proof. apply rank_nullity. Qed.

Theorem e47_78_add_47_eq_125 : (78 + 47)%nat = 125%nat.
Proof.
  pose proof e47_rank_nullity as H.
  rewrite e47_rank, e47_nullity, e47_total in H. exact H.
Qed.

(** The retained sectors are exactly j = 2 and j = 5, of dimensions 25 and 22. *)
Theorem e47_retained_sectors :
  filter (fun s => selK (eigen s)) e47Carrier
    = [ {| eigen := 6; dim := 25 |} ; {| eigen := 30; dim := 22 |} ].
Proof. reflexivity. Qed.

End RankNullity47.

Print Assumptions RankNullity47.rank_nullity.
Print Assumptions RankNullity47.nullity_le_total.
Print Assumptions RankNullity47.rank_from_nullity.
Print Assumptions RankNullity47.nullity_determined.
Print Assumptions RankNullity47.selK_iff_selector.
Print Assumptions RankNullity47.e47_rank_nullity.
Print Assumptions RankNullity47.e47_78_add_47_eq_125.
Print Assumptions RankNullity47.e47_retained_sectors.
