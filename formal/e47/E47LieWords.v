(* Free bracket words, similarity transport, and spanning from an explicit
   inverse.  Coq standard library only; no axioms or Admitted.

   ITEM 1  Word / eval : the free bracket word on two generators, evaluated
           into n x n rational matrices.
   ITEM 2  conj_eval : diagonal similarity transports EVERY iterated
           commutator, by structural induction on the word.  Its base case is
           conj_commutator.  Coq has no axiom-free functional extensionality,
           so matrix equality here is the pointwise relation MEq and the
           induction goes through matmul_congr / commutator_congr.
   ITEM 3  spanning_from_inverse : if the coordinate matrix of a family of
           words admits an explicit right inverse N, every matrix X is the
           rational combination of the words with coefficients N . X.  No
           determinant theory and no dimension theory is used.

   Not proved here: Lie_R{-iD,-iB} = u(n), which needs complexification and
   finrank.  See E47RealForm.v for the two obligations of that argument that
   ARE closed.
*)
From Coq Require Import QArith Qring Arith Lia.
Open Scope Q_scope.
Module E47LieWords.
Fixpoint qsum (n : nat) (f : nat -> Q) : Q :=
  match n with O => 0 | S m => qsum m f + f m end.

Lemma qsum_congr : forall n f g,
  (forall i, (i < n)%nat -> f i == g i) -> qsum n f == qsum n g.
Proof.
  induction n as [|m IH]; intros f g H; simpl.
  - reflexivity.
  - rewrite (IH f g) by (intros i Hi; apply H; lia).
    rewrite (H m) by lia. reflexivity.
Qed.

Lemma qsum_zero : forall n, qsum n (fun _ => 0) == 0.
Proof. induction n as [|m IH]; simpl. reflexivity. rewrite IH. ring. Qed.

Lemma qsum_add : forall n f g,
  qsum n (fun i => f i + g i) == qsum n f + qsum n g.
Proof.
  induction n as [|m IH]; intros f g; simpl.
  - ring.
  - rewrite (IH f g). ring.
Qed.

Lemma qsum_mul_left : forall c n f, c * qsum n f == qsum n (fun i => c * f i).
Proof. intros c n; induction n as [|m IH]; intro f; simpl. ring. rewrite <- (IH f). ring. Qed.

Lemma qsum_mul_right : forall c n f, qsum n f * c == qsum n (fun i => f i * c).
Proof. intros c n; induction n as [|m IH]; intro f; simpl. ring. rewrite <- (IH f). ring. Qed.

Lemma qsum_swap : forall a b f,
  qsum a (fun i => qsum b (fun j => f i j)) == qsum b (fun j => qsum a (fun i => f i j)).
Proof.
  induction a as [|m IH]; intros b f; simpl.
  - symmetry.
    transitivity (qsum b (fun _ : nat => 0)).
    + apply qsum_congr. intros. reflexivity.
    + apply qsum_zero.
  - rewrite (IH b f).
    rewrite <- (qsum_add b (fun j => qsum m (fun i => f i j)) (fun j => f m j)).
    reflexivity.
Qed.

Lemma qsum_skip : forall n i g, (n <= i)%nat ->
  qsum n (fun p => if Nat.eq_dec i p then g p else 0) == 0.
Proof.
  induction n as [|m IH]; intros i g H; simpl.
  - reflexivity.
  - rewrite (IH i g) by lia.
    destruct (Nat.eq_dec i m) as [E|E]. lia. ring.
Qed.

Lemma qsum_delta : forall n i g, (i < n)%nat ->
  qsum n (fun p => if Nat.eq_dec i p then g p else 0) == g i.
Proof.
  induction n as [|m IH]; intros i g H; simpl. lia.
  destruct (Nat.eq_dec i m) as [E|E].
  - subst i. rewrite (qsum_skip m m g) by lia. ring.
  - rewrite (IH i g) by lia. ring.
Qed.

Definition Mat := nat -> nat -> Q.
Definition matmul (n : nat) (A B : Mat) : Mat := fun i j => qsum n (fun k => A i k * B k j).
Definition conj (s t : nat -> Q) (A : Mat) : Mat := fun i j => t i * A i j * s j.
Definition matsub (A B : Mat) : Mat := fun i j => A i j - B i j.
Definition commutator (n : nat) (A B : Mat) : Mat := matsub (matmul n A B) (matmul n B A).
Definition MEq (A B : Mat) := forall i j, A i j == B i j.

Theorem conj_mul : forall (n : nat) (s t : nat -> Q),
  (forall k, (k < n)%nat -> s k * t k == 1) ->
  forall (A B : Mat) (i j : nat),
    conj s t (matmul n A B) i j == matmul n (conj s t A) (conj s t B) i j.
Proof.
  intros n s t hst A B i j. unfold conj, matmul.
  rewrite qsum_mul_left, qsum_mul_right.
  apply qsum_congr. intros k hk. specialize (hst k hk).
  setoid_replace (t i * A i k * s k * (t k * B k j * s j))
    with ((s k * t k) * (t i * (A i k * B k j) * s j)) by ring.
  rewrite hst. ring.
Qed.

Theorem conj_sub : forall (s t : nat -> Q) (A B : Mat) (i j : nat),
  conj s t (matsub A B) i j == matsub (conj s t A) (conj s t B) i j.
Proof. intros. unfold conj, matsub. ring. Qed.

Theorem conj_commutator : forall (n : nat) (s t : nat -> Q),
  (forall k, (k < n)%nat -> s k * t k == 1) ->
  forall (A B : Mat) (i j : nat),
    conj s t (commutator n A B) i j == commutator n (conj s t A) (conj s t B) i j.
Proof.
  intros n s t hst A B i j. unfold commutator.
  rewrite (conj_sub s t (matmul n A B) (matmul n B A) i j).
  unfold matsub.
  rewrite (conj_mul n s t hst A B i j).
  rewrite (conj_mul n s t hst B A i j). reflexivity.
Qed.

Lemma matmul_congr : forall n A A' B B', MEq A A' -> MEq B B' ->
  forall i j, matmul n A B i j == matmul n A' B' i j.
Proof.
  intros n A A' B B' HA HB i j. unfold matmul.
  apply qsum_congr. intros k _. rewrite (HA i k), (HB k j). reflexivity.
Qed.

Lemma commutator_congr : forall n A A' B B', MEq A A' -> MEq B B' ->
  forall i j, commutator n A B i j == commutator n A' B' i j.
Proof.
  intros n A A' B B' HA HB i j. unfold commutator, matsub.
  rewrite (matmul_congr n A A' B B' HA HB i j).
  rewrite (matmul_congr n B B' A A' HB HA i j). reflexivity.
Qed.

(* ITEM 1 *)
Inductive Word : Type := gA : Word | gB : Word | br : Word -> Word -> Word.

Fixpoint eval (n : nat) (A B : Mat) (w : Word) : Mat :=
  match w with
  | gA => A
  | gB => B
  | br u v => commutator n (eval n A B u) (eval n A B v)
  end.

(* ITEM 2 *)
Theorem conj_eval : forall (n : nat) (s t : nat -> Q),
  (forall k, (k < n)%nat -> s k * t k == 1) ->
  forall (A B : Mat) (w : Word) (i j : nat),
    conj s t (eval n A B w) i j == eval n (conj s t A) (conj s t B) w i j.
Proof.
  intros n s t hst A B w.
  induction w as [| | u IHu v IHv]; intros i j.
  - reflexivity.
  - reflexivity.
  - transitivity (commutator n (conj s t (eval n A B u)) (conj s t (eval n A B v)) i j).
    + apply (conj_commutator n s t hst).
    + apply commutator_congr; intros p q; [apply IHu | apply IHv].
Qed.

Definition qsum2 (a b : nat) (f : nat -> nat -> Q) : Q :=
  qsum a (fun p => qsum b (fun q => f p q)).

Lemma delta_row : forall n i j p (X : Mat), (j < n)%nat ->
  qsum n (fun q => (if Nat.eq_dec i p then (if Nat.eq_dec j q then 1 else 0) else 0) * X p q)
    == (if Nat.eq_dec i p then X p j else 0).
Proof.
  intros n i j p X hj.
  destruct (Nat.eq_dec i p) as [E|E].
  - transitivity (qsum n (fun q => if Nat.eq_dec j q then X p q else 0)).
    + apply qsum_congr. intros q _. destruct (Nat.eq_dec j q); ring.
    + apply (qsum_delta n j (fun q => X p q) hj).
  - transitivity (qsum n (fun _ : nat => 0)).
    + apply qsum_congr. intros q _. ring.
    + apply qsum_zero.
Qed.

(* ITEM 3 *)
Theorem spanning_from_inverse :
  forall (n m : nat) (W : nat -> Mat) (N : nat -> nat -> nat -> Q),
  (forall i j p q, qsum m (fun k => N k p q * W k i j)
     == (if Nat.eq_dec i p then (if Nat.eq_dec j q then 1 else 0) else 0)) ->
  forall (X : Mat) i j, (i < n)%nat -> (j < n)%nat ->
    qsum m (fun k => qsum2 n n (fun p q => N k p q * X p q) * W k i j) == X i j.
Proof.
  intros n m W N hMN X i j hi hj.
  transitivity (qsum m (fun k => qsum n (fun p => qsum n (fun q => N k p q * X p q * W k i j)))).
  { apply qsum_congr. intros k _. unfold qsum2.
    rewrite (qsum_mul_right (W k i j) n (fun p => qsum n (fun q => N k p q * X p q))).
    apply qsum_congr. intros p _.
    apply (qsum_mul_right (W k i j) n (fun q => N k p q * X p q)). }
  transitivity (qsum n (fun p => qsum m (fun k => qsum n (fun q => N k p q * X p q * W k i j)))).
  { apply (qsum_swap m n (fun k p => qsum n (fun q => N k p q * X p q * W k i j))). }
  transitivity (qsum n (fun p => qsum n (fun q => qsum m (fun k => N k p q * X p q * W k i j)))).
  { apply qsum_congr. intros p _.
    apply (qsum_swap m n (fun k q => N k p q * X p q * W k i j)). }
  transitivity (qsum n (fun p => qsum n (fun q =>
      (if Nat.eq_dec i p then (if Nat.eq_dec j q then 1 else 0) else 0) * X p q))).
  { apply qsum_congr. intros p _. apply qsum_congr. intros q _.
    transitivity (qsum m (fun k => N k p q * W k i j * X p q)).
    - apply qsum_congr. intros k _. ring.
    - rewrite <- (qsum_mul_right (X p q) m (fun k => N k p q * W k i j)).
      rewrite (hMN i j p q). reflexivity. }
  transitivity (qsum n (fun p => if Nat.eq_dec i p then X p j else 0)).
  { apply qsum_congr. intros p _. apply (delta_row n i j p X hj). }
  apply (qsum_delta n i (fun p => X p j) hi).
Qed.
End E47LieWords.
