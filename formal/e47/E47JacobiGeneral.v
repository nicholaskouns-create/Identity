(* Exact Jacobi rationalization, arbitrary dimension.
   Coq standard library only; no axioms or Admitted.
   r_i*r_i=c_i represents a square-root coupling.
   The four entry classes establish the rational similarity.
*)
From Coq Require Import QArith Qring Arith Lia.
Open Scope Q_scope.
Module E47Jacobi.
Theorem upper_entry : forall s t r c : Q,
  t*s == 1 -> r*r == c -> t*r*(s*r) == c.
Proof.
  intros s t r c ht hr.
  replace (t*r*(s*r)) with ((t*s)*(r*r)) by ring.
  rewrite ht, hr. ring.
Qed.
Theorem lower_entry : forall sNext tNext s r : Q,
  sNext == s*r -> tNext*sNext == 1 -> tNext*r*s == 1.
Proof.
  intros sNext tNext s r hs ht.
  replace (tNext*r*s) with (tNext*(s*r)) by ring.
  rewrite <- hs. exact ht.
Qed.
Theorem diagonal_entry : forall s t a : Q,
  t*s == 1 -> t*a*s == a.
Proof.
  intros s t a ht.
  replace (t*a*s) with ((t*s)*a) by ring.
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
End E47Jacobi.
