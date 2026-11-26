(* MC-121 additive bridge: generic diagonal polynomial selector.
   Arbitrary index type I, integer eigenvalue function, and two roots.
   Exact statement: ker[(D-aI)(D-bI)] is the fixed space of P_{a,b}.
   This does not prove diagonalization of the concrete 125x125 Casimir. *)
From Coq Require Import ZArith Lia Ring.
Open Scope Z_scope.

Section GeneralDiagonal.
Context {I : Type}.
Variable eigen : I -> Z.
Variable a b : Z.

Definition diagonal (v : I -> Z) (i : I) : Z := eigen i * v i.
Definition filter (v : I -> Z) (i : I) : Z :=
  (eigen i - a) * (eigen i - b) * v i.
Definition projector (v : I -> Z) (i : I) : Z :=
  if Z.eq_dec (eigen i) a then v i
  else if Z.eq_dec (eigen i) b then v i else 0.

Theorem projector_idempotent :
  forall (v : I -> Z) (i : I), projector (projector v) i = projector v i.
Proof.
  intros v i. unfold projector.
  destruct (Z.eq_dec (eigen i) a) as [ha|ha]; [reflexivity|].
  destruct (Z.eq_dec (eigen i) b) as [hb|hb]; reflexivity.
Qed.

Theorem filter_projector_zero :
  forall (v : I -> Z) (i : I), filter (projector v) i = 0.
Proof.
  intros v i. unfold filter, projector.
  destruct (Z.eq_dec (eigen i) a) as [ha|ha].
  - rewrite ha. ring.
  - destruct (Z.eq_dec (eigen i) b) as [hb|hb].
    + rewrite hb. ring.
    + ring.
Qed.

Theorem projector_filter_zero :
  forall (v : I -> Z) (i : I), projector (filter v) i = 0.
Proof.
  intros v i. unfold projector, filter.
  destruct (Z.eq_dec (eigen i) a) as [ha|ha].
  - rewrite ha. ring.
  - destruct (Z.eq_dec (eigen i) b) as [hb|hb].
    + rewrite hb. ring.
    + reflexivity.
Qed.

Theorem projector_commutes_diagonal :
  forall (v : I -> Z) (i : I),
    projector (diagonal v) i = diagonal (projector v) i.
Proof.
  intros v i. unfold projector, diagonal.
  destruct (Z.eq_dec (eigen i) a) as [ha|ha]; [ring|].
  destruct (Z.eq_dec (eigen i) b) as [hb|hb]; ring.
Qed.

Theorem kernel_iff_projector_fixed :
  forall (v : I -> Z),
    (forall i, filter v i = 0) <-> (forall i, projector v i = v i).
Proof.
  intro v. split.
  - intros h i. unfold projector.
    destruct (Z.eq_dec (eigen i) a) as [ha|ha]; [reflexivity|].
    destruct (Z.eq_dec (eigen i) b) as [hb|hb]; [reflexivity|].
    specialize (h i). unfold filter in h.
    apply Z.mul_eq_0 in h.
    destruct h as [hprod|hv].
    + apply Z.mul_eq_0 in hprod.
      destruct hprod as [hleft|hright]; lia.
    + symmetry. exact hv.
  - intros h i. specialize (h i).
    unfold projector in h. unfold filter.
    destruct (Z.eq_dec (eigen i) a) as [ha|ha].
    + rewrite ha. ring.
    + destruct (Z.eq_dec (eigen i) b) as [hb|hb].
      * rewrite hb. ring.
      * assert (v i = 0) by lia.
        rewrite H. ring.
Qed.


(* Additive MC-121 root-space splitting for two distinct integer roots.
   These are coordinate projectors in a supplied eigenbasis, not a
   diagonalization of the concrete 125-by-125 Casimir. *)
Definition root_projector (r : Z) (v : I -> Z) (i : I) : Z :=
  if Z.eq_dec (eigen i) r then v i else 0.

Theorem root_projector_idempotent :
  forall (r : Z) (v : I -> Z) (i : I),
    root_projector r (root_projector r v) i = root_projector r v i.
Proof.
  intros r v i. unfold root_projector.
  destruct (Z.eq_dec (eigen i) r); reflexivity.
Qed.

Theorem distinct_root_projectors_orthogonal :
  a <> b -> forall (v : I -> Z) (i : I),
    root_projector a (root_projector b v) i = 0.
Proof.
  intros hab v i. unfold root_projector.
  destruct (Z.eq_dec (eigen i) a) as [ha|ha].
  - destruct (Z.eq_dec (eigen i) b) as [hb|hb].
    + exfalso. apply hab. lia.
    + reflexivity.
  - reflexivity.
Qed.

Theorem distinct_root_projector_sum :
  a <> b -> forall (v : I -> Z) (i : I),
    projector v i = root_projector a v i + root_projector b v i.
Proof.
  intros hab v i. unfold projector, root_projector.
  destruct (Z.eq_dec (eigen i) a) as [ha|ha].
  - destruct (Z.eq_dec (eigen i) b) as [hb|hb].
    + exfalso. apply hab. lia.
    + lia.
  - destruct (Z.eq_dec (eigen i) b) as [hb|hb]; lia.
Qed.

Theorem kernel_distinct_root_split :
  a <> b -> forall (v : I -> Z) (i : I),
    (forall j, filter v j = 0) ->
    v i = root_projector a v i + root_projector b v i.
Proof.
  intros hab v i hv.
  pose proof (proj1 (kernel_iff_projector_fixed v) hv i) as hp.
  pose proof (distinct_root_projector_sum hab v i) as hs.
  lia.
Qed.


(* MC-121 complementary-sector decomposition.
   P and Q are complementary coordinate projectors in a supplied
   eigenbasis. This does not identify the concrete Casimir eigenspaces. *)
Definition complement (v : I -> Z) (i : I) : Z :=
  if Z.eq_dec (eigen i) a then 0
  else if Z.eq_dec (eigen i) b then 0 else v i.

Theorem complement_idempotent :
  forall (v : I -> Z) (i : I),
    complement (complement v) i = complement v i.
Proof.
  intros v i. unfold complement.
  destruct (Z.eq_dec (eigen i) a); [reflexivity|].
  destruct (Z.eq_dec (eigen i) b); reflexivity.
Qed.

Theorem projector_complement_zero :
  forall (v : I -> Z) (i : I), projector (complement v) i = 0.
Proof.
  intros v i. unfold projector, complement.
  destruct (Z.eq_dec (eigen i) a); [reflexivity|].
  destruct (Z.eq_dec (eigen i) b); reflexivity.
Qed.

Theorem complement_projector_zero :
  forall (v : I -> Z) (i : I), complement (projector v) i = 0.
Proof.
  intros v i. unfold projector, complement.
  destruct (Z.eq_dec (eigen i) a); [reflexivity|].
  destruct (Z.eq_dec (eigen i) b); reflexivity.
Qed.

Theorem projector_complement_sum :
  forall (v : I -> Z) (i : I),
    projector v i + complement v i = v i.
Proof.
  intros v i. unfold projector, complement.
  destruct (Z.eq_dec (eigen i) a); [lia|].
  destruct (Z.eq_dec (eigen i) b); lia.
Qed.

Theorem filter_complement_eq_filter :
  forall (v : I -> Z) (i : I),
    filter (complement v) i = filter v i.
Proof.
  intros v i. unfold filter, complement.
  destruct (Z.eq_dec (eigen i) a) as [ha|ha].
  - rewrite ha. ring.
  - destruct (Z.eq_dec (eigen i) b) as [hb|hb].
    + rewrite hb. ring.
    + reflexivity.
Qed.

End GeneralDiagonal.

Print Assumptions projector_idempotent.
Print Assumptions filter_projector_zero.
Print Assumptions projector_filter_zero.
Print Assumptions projector_commutes_diagonal.
Print Assumptions kernel_iff_projector_fixed.
Print Assumptions root_projector_idempotent.
Print Assumptions distinct_root_projectors_orthogonal.
Print Assumptions distinct_root_projector_sum.
Print Assumptions kernel_distinct_root_split.
Print Assumptions complement_idempotent.
Print Assumptions projector_complement_zero.
Print Assumptions complement_projector_zero.
Print Assumptions projector_complement_sum.
Print Assumptions filter_complement_eq_filter.
