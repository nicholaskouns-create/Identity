(* Exact Jacobi rationalization, arbitrary dimension.
   Coq standard library only; no axioms or Admitted.
   r_i*r_i=c_i represents a square-root coupling.
   The four entry classes establish the rational similarity;
   they are then assembled into a single all-entries theorem,
   and diagonal conjugation is shown to preserve products,
   differences and commutators -- the transport step carrying
   a rational commutator certificate back to the original pair.
*)
From Coq Require Import QArith Qring Arith Lia.
Open Scope Q_scope.
Module E47Jacobi.

(* ================= Part 1. The four entry classes. ================= *)

Theorem upper_entry : forall s t r c : Q,
  t*s == 1 -> r*r == c -> t*r*(s*r) == c.
Proof.
  intros s t r c ht hr.
  setoid_replace (t*r*(s*r)) with ((t*s)*(r*r)) by ring.
  rewrite ht, hr. ring.
Qed.
Theorem lower_entry : forall sNext tNext s r : Q,
  sNext == s*r -> tNext*sNext == 1 -> tNext*r*s == 1.
Proof.
  intros sNext tNext s r hs ht.
  setoid_replace (tNext*r*s) with (tNext*(s*r)) by ring.
  rewrite <- hs. exact ht.
Qed.
Theorem diagonal_entry : forall s t a : Q,
  t*s == 1 -> t*a*s == a.
Proof.
  intros s t a ht.
  setoid_replace (t*a*s) with ((t*s)*a) by ring.
  rewrite ht. ring.
Qed.
Theorem zero_entry : forall s t : Q, t*0*s == 0.
Proof. intros; ring. Qed.

Theorem jacobi_upper_all :
  forall (n : nat) (s t r c : nat -> Q),
    (forall i, (i < n)%nat -> t i * s i == 1) ->
    (forall i, (S i < n)%nat -> r i * r i == c i) ->
    forall i, (S i < n)%nat ->
      t i * r i * (s i * r i) == c i.
Proof.
  intros n s t r c hinv hroot i hi.
  apply upper_entry.
  - apply hinv. lia.
  - apply hroot. exact hi.
Qed.
Theorem jacobi_lower_all :
  forall (n : nat) (s t r : nat -> Q),
    (forall i, (S i < n)%nat -> s (S i) == s i * r i) ->
    (forall i, (i < n)%nat -> t i * s i == 1) ->
    forall i, (S i < n)%nat ->
      t (S i) * r i * s i == 1.
Proof.
  intros n s t r hrec hinv i hi.
  eapply lower_entry.
  - apply hrec. exact hi.
  - apply hinv. exact hi.
Qed.

(* ========== Part 2. Matrices as index functions, finite sums. ========== *)

Definition Mat := nat -> nat -> Q.

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

Lemma qsum_mul_left : forall c n f, c * qsum n f == qsum n (fun i => c * f i).
Proof.
  intros c n; induction n as [|m IH]; intro f; simpl.
  - ring.
  - rewrite <- (IH f). ring.
Qed.

Lemma qsum_mul_right : forall c n f, qsum n f * c == qsum n (fun i => f i * c).
Proof.
  intros c n; induction n as [|m IH]; intro f; simpl.
  - ring.
  - rewrite <- (IH f). ring.
Qed.

Definition matmul (n : nat) (A B : Mat) : Mat :=
  fun i j => qsum n (fun k => A i k * B k j).
Definition conj (s t : nat -> Q) (A : Mat) : Mat :=
  fun i j => t i * A i j * s j.
Definition matsub (A B : Mat) : Mat := fun i j => A i j - B i j.
Definition commutator (n : nat) (A B : Mat) : Mat :=
  matsub (matmul n A B) (matmul n B A).

(* ===== Part 3. Diagonal conjugation is an algebra homomorphism. ===== *)

Theorem conj_mul : forall (n : nat) (s t : nat -> Q),
  (forall k, (k < n)%nat -> s k * t k == 1) ->
  forall (A B : Mat) (i j : nat),
    conj s t (matmul n A B) i j == matmul n (conj s t A) (conj s t B) i j.
Proof.
  intros n s t hst A B i j. unfold conj, matmul.
  rewrite qsum_mul_left, qsum_mul_right.
  apply qsum_congr. intros k hk.
  specialize (hst k hk).
  setoid_replace (t i * A i k * s k * (t k * B k j * s j))
    with ((s k * t k) * (t i * (A i k * B k j) * s j)) by ring.
  rewrite hst. ring.
Qed.

Theorem conj_sub : forall (s t : nat -> Q) (A B : Mat) (i j : nat),
  conj s t (matsub A B) i j == matsub (conj s t A) (conj s t B) i j.
Proof. intros. unfold conj, matsub. ring. Qed.

(* Similarity preserves commutators: the transport step. *)
Theorem conj_commutator : forall (n : nat) (s t : nat -> Q),
  (forall k, (k < n)%nat -> s k * t k == 1) ->
  forall (A B : Mat) (i j : nat),
    conj s t (commutator n A B) i j
      == commutator n (conj s t A) (conj s t B) i j.
Proof.
  intros n s t hst A B i j. unfold commutator.
  rewrite (conj_sub s t (matmul n A B) (matmul n B A) i j).
  unfold matsub.
  rewrite (conj_mul n s t hst A B i j).
  rewrite (conj_mul n s t hst B A i j).
  reflexivity.
Qed.

(* ==== Part 4. Jacobi matrices and the all-entries similarity. ==== *)

(* Symmetric tridiagonal B: diagonal a_i, both off-diagonals r_i. *)
Definition jacobiB (a r : nat -> Q) : Mat := fun i j =>
  if Nat.eq_dec i j then a i
  else if Nat.eq_dec j (S i) then r i
  else if Nat.eq_dec i (S j) then r j
  else 0.

(* Rationalised B~: diagonal a_i, upper c_i, lower 1. *)
Definition jacobiRat (a c : nat -> Q) : Mat := fun i j =>
  if Nat.eq_dec i j then a i
  else if Nat.eq_dec j (S i) then c i
  else if Nat.eq_dec i (S j) then 1
  else 0.

(* Every entry at once: S^-1 B S = B~ on the index range, where
   S = diag(s), S^-1 = diag(t), s_0 = 1, s_{i+1} = s_i r_i, r_i^2 = c_i. *)
Theorem conj_jacobi_entry :
  forall (n : nat) (a r c s t : nat -> Q),
    (forall i, (i < n)%nat -> t i * s i == 1) ->
    (forall i, (S i < n)%nat -> s (S i) == s i * r i) ->
    (forall i, (S i < n)%nat -> r i * r i == c i) ->
    forall i j, (i < n)%nat -> (j < n)%nat ->
      conj s t (jacobiB a r) i j == jacobiRat a c i j.
Proof.
  intros n a r c s t hinv hrec hroot i j hi hj.
  unfold conj, jacobiB, jacobiRat.
  destruct (Nat.eq_dec i j) as [E|E].
  - subst j. apply diagonal_entry. apply hinv. exact hi.
  - destruct (Nat.eq_dec j (S i)) as [E2|E2].
    + subst j. rewrite (hrec i hj).
      apply upper_entry.
      * apply hinv. lia.
      * apply hroot. lia.
    + destruct (Nat.eq_dec i (S j)) as [E3|E3].
      * subst i. eapply lower_entry.
        -- apply hrec. lia.
        -- apply hinv. lia.
      * apply zero_entry.
Qed.

End E47Jacobi.
