From Coq Require Import ZArith Lia.
Open Scope Z_scope.

Fixpoint fib (n : nat) : Z :=
  match n with
  | O => 0
  | S O => 1
  | S (S k as m) => fib m + fib k
  end.

Fixpoint luc (n : nat) : Z :=
  match n with
  | O => 2
  | S O => 1
  | S (S k as m) => luc m + luc k
  end.

Lemma invariants : forall n : nat,
  (if Nat.even n then
     luc n * luc n - 5 * fib n * fib n = 4 /\
     luc (S n) * luc (S n) - 5 * fib (S n) * fib (S n) = -4 /\
     luc n * luc (S n) - 5 * fib n * fib (S n) = 2
   else
     luc n * luc n - 5 * fib n * fib n = -4 /\
     luc (S n) * luc (S n) - 5 * fib (S n) * fib (S n) = 4 /\
     luc n * luc (S n) - 5 * fib n * fib (S n) = -2).
Proof.
  induction n as [|n IH].
  - simpl. lia.
  - rewrite Nat.even_succ. unfold Nat.odd.
    assert (Ef : fib (S (S n)) = fib (S n) + fib n) by reflexivity.
    assert (El : luc (S (S n)) = luc (S n) + luc n) by reflexivity.
    destruct (Nat.even n) eqn:E; simpl negb; cbv iota in IH;
      destruct IH as [H0 [H1 H2]];
      rewrite Ef, El; repeat split; nia.
Qed.

Theorem lucas_fibonacci_odd : forall n : nat,
  Nat.even n = false ->
  luc n * luc n - 5 * fib n * fib n = -4.
Proof.
  intros n Hodd.
  pose proof (invariants n) as H.
  rewrite Hodd in H.
  tauto.
Qed.

Theorem tower_spin_identity : forall (n : nat) (j J : Z),
  Nat.even n = false ->
  2 * j + 1 = fib n ->
  2 * J + 1 = luc n ->
  J * (J + 1) = 5 * j * (j + 1).
Proof.
  intros n j J Hodd Hj HJ.
  pose proof (lucas_fibonacci_odd n Hodd) as H.
  nia.
Qed.
