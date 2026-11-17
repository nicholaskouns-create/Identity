(* The real-form step of the E47 controllability argument.
   Coq standard library only; no axioms or Admitted.

   Target:  g <= u(n)  and  g + i*g = gl_n(C)   ->   g = u(n).

   Four obligations:
     (1) scalar           x = -x -> x = 0 in characteristic 0
     (2) matrix           Y skew-Hermitian -> iY Hermitian;
                          Hermitian /\ skew -> 0, hence g /\ i*g = {0}
     (3) complexification Phi : g (x)_R C -> g + i*g onto, injective by (2)
     (4) dimension        dim_R g = dim_C (g (x)_R C) = n^2; with g <= u(n)
                          and dim_R u(n) = n^2, equality follows

   (1) and (2) are proved here in full.  They are the part that carries the
   real form.  (3) needs a tensor product; (4) needs finrank.  Neither is
   claimed as proved here; both are stated precisely at the end.
*)
From Coq Require Import QArith Qring Arith Lia.
Open Scope Q_scope.
Module E47RealForm.

(* ================= Obligation (1): the scalar step ================= *)

Theorem self_neg_zero : forall x : Q, x == - x -> x == 0.
Proof.
  intros x H.
  assert (H2 : 2 * x == 0).
  { setoid_replace (2 * x) with (x + x) by ring.
    rewrite H at 1. ring. }
  setoid_replace x with ((2 * x) * (1#2)) by ring.
  rewrite H2. ring.
Qed.

(* ========= Gaussian rationals: a concrete complex scalar field ========= *)

Record GQ := mkGQ { gre : Q ; gim : Q }.

Definition GQeq (z w : GQ) : Prop := gre z == gre w /\ gim z == gim w.
Definition gzero : GQ := mkGQ 0 0.
Definition gneg (z : GQ) : GQ := mkGQ (- gre z) (- gim z).
Definition gcj  (z : GQ) : GQ := mkGQ (gre z) (- gim z).
Definition gImul (z : GQ) : GQ := mkGQ (- gim z) (gre z).   (* i * z *)

Theorem gq_self_neg_zero : forall z : GQ, GQeq z (gneg z) -> GQeq z gzero.
Proof.
  intros z [Hr Hi]. split; simpl.
  - apply self_neg_zero. exact Hr.
  - apply self_neg_zero. exact Hi.
Qed.

(* ================= Obligation (2): the matrix step ================= *)

Definition CMat := nat -> nat -> GQ.
Definition dagger (A : CMat) : CMat := fun i j => gcj (A j i).
Definition smulI  (A : CMat) : CMat := fun i j => gImul (A i j).

Definition IsHerm (n : nat) (A : CMat) : Prop :=
  forall i j, (i < n)%nat -> (j < n)%nat -> GQeq (dagger A i j) (A i j).
Definition IsSkew (n : nat) (A : CMat) : Prop :=
  forall i j, (i < n)%nat -> (j < n)%nat -> GQeq (dagger A i j) (gneg (A i j)).

(* Multiplying a skew-Hermitian matrix by i yields a Hermitian matrix. *)
Theorem smulI_skew_isHerm : forall n Y, IsSkew n Y -> IsHerm n (smulI Y).
Proof.
  intros n Y hY i j hi hj.
  destruct (hY j i hj hi) as [Hr Hi]. simpl in Hr, Hi.
  split; simpl.
  - rewrite <- Hi. ring.
  - rewrite Hr. ring.
Qed.

(* A matrix both Hermitian and skew-Hermitian vanishes. *)
Theorem herm_skew_zero : forall n A,
  IsHerm n A -> IsSkew n A ->
  forall i j, (i < n)%nat -> (j < n)%nat -> GQeq (A i j) gzero.
Proof.
  intros n A hH hS i j hi hj.
  apply gq_self_neg_zero.
  destruct (hH i j hi hj) as [Hr1 Hi1].
  destruct (hS i j hi hj) as [Hr2 Hi2].
  split.
  - rewrite <- Hr1. exact Hr2.
  - rewrite <- Hi1. exact Hi2.
Qed.

(* Obligation (2), the boxed result:  g /\ i*g = {0}. *)
Theorem real_form_inter_trivial : forall n (X Y : CMat),
  IsSkew n X -> IsSkew n Y ->
  (forall i j, GQeq (X i j) (smulI Y i j)) ->
  forall i j, (i < n)%nat -> (j < n)%nat -> GQeq (X i j) gzero.
Proof.
  intros n X Y hX hY hXY i j hi hj.
  assert (hXH : IsHerm n X).
  { intros p q hp hq.
    destruct (smulI_skew_isHerm n Y hY p q hp hq) as [Hr Hi].
    destruct (hXY q p) as [Er Ei].
    destruct (hXY p q) as [Fr Fi].
    unfold dagger, gcj in *. simpl in *.
    split; simpl.
    - rewrite Er. rewrite Hr. symmetry. exact Fr.
    - rewrite Ei. rewrite Hi. symmetry. exact Fi. }
  apply (herm_skew_zero n X hXH hX i j hi hj).
Qed.

(* ===================== Remaining obligations =====================

   NOT PROVED HERE.  Stated so the gap is exact rather than vague.

   (3) Complexification.  Phi : g (x)_R C -> g + i*g,
       Phi(X (x) (a + i b)) = a X + i b X, is C-linear and surjective by
       construction, injective by real_form_inter_trivial above.
       Formalizing it needs a tensor product over R.

   (4) Dimension.  dim_R g = dim_C (g (x)_R C) = n^2; with g <= u(n) and
       dim_R u(n) = n^2, equality follows.  Formalizing it needs finrank
       over a field, i.e. a library beyond the standard one.

   Only (4) is irreducibly dimension-theoretic.
*)

End E47RealForm.
