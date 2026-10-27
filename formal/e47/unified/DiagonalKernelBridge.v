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

End GeneralDiagonal.

Print Assumptions projector_idempotent.
Print Assumptions filter_projector_zero.
Print Assumptions projector_filter_zero.
Print Assumptions projector_commutes_diagonal.
Print Assumptions kernel_iff_projector_fixed.
