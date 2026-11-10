From Coq Require Import ZArith Lia.
Open Scope Z_scope.

(* Exact formal-series coefficient recurrence and uniqueness.
   Does not formalize Clebsch-Gordan->recurrence or analytic transfer. *)
Module E47ThirdTurnGF.

Definition GFRec (a0 a1 d : nat -> Z) : Prop :=
  d 0%nat = - a0 0%nat /\
  d 1%nat + 2 * d 0%nat =
     - a0 1%nat + 4 * a0 0%nat + 2 * a1 0%nat /\
  forall n : nat,
      d (n+2)%nat + 2*d (n+1)%nat + d n =
      - a0 (n+2)%nat + 4*a0 (n+1)%nat + 5*a0 n +
       2*a1 (n+1)%nat - 10*a1 n.

Theorem generating_function_coefficients_unique
    (a0 a1 d e : nat -> Z) :
    GFRec a0 a1 d -> GFRec a0 a1 e ->
    forall n : nat, d n = e n.
Proof.
  intros [Hd0 [Hd1 Hd]] [He0 [He1 He]].
  assert (H0 : d 0%nat = e 0%nat) by lia.
  assert (H1 : d 1%nat = e 1%nat) by lia.
  assert (Hpair : forall n : nat,
           d n = e n /\ d (n+1)%nat = e (n+1)%nat).
  { intro n.
    induction n as [|n IH].
    - exact (conj H0 H1).
    - destruct IH as [Hn Hn1].
      split.
      + replace (S n) with (n+1)%nat by lia. exact Hn1.
      + specialize (Hd n).
        specialize (He n).
        replace (S n + 1)%nat with (n+2)%nat by lia.
        lia.
  }
  intro n.
  exact (proj1 (Hpair n)).
Qed.

Definition chi (J : nat) : Z :=
  match (J mod 3)%nat with
  | O => 1
  | S O => 0
  | _ => -1
  end.

Theorem chi_period_three (J : nat) : chi (J+3)%nat = chi J.
Proof.
  unfold chi.
  replace ((J+3) mod 3)%nat with (J mod 3)%nat by lia.
  reflexivity.
Qed.

Print Assumptions generating_function_coefficients_unique.
Print Assumptions chi_period_three.
End E47ThirdTurnGF.
