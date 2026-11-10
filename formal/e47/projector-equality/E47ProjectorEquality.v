From Coq Require Import ZArith Lia Bool Arith.
Open Scope Z_scope.

Module E47ProjectorEquality.

Definition casimir (j : Z) : Z := j * (j + 1).
Definition numerator (x : Z) : Z :=
  x * (x - 2) * (x - 12) * (x - 20) * (x - 31) * (x - 42).
Definition selected (j : Z) : bool :=
  orb (Z.eqb j 2) (Z.eqb j 5).

Theorem seven_sectors :
  forall j : Z, 0 <= j <= 6 ->
    numerator (casimir j) =
      if selected j then 1814400 else 0.
Proof.
  intros j Hj.
  assert (H : j = 0 \/ j = 1 \/ j = 2 \/ j = 3 \/
              j = 4 \/ j = 5 \/ j = 6) by lia.
  destruct H as [->|[->|[->|[->|[->|[->|->]]]]]];
    vm_compute; reflexivity.
Qed.

Definition spin (i : nat) : Z :=
  if Nat.ltb i 1 then 0
  else if Nat.ltb i 10 then 1
  else if Nat.ltb i 35 then 2
  else if Nat.ltb i 63 then 3
  else if Nat.ltb i 90 then 4
  else if Nat.ltb i 112 then 5
  else 6.

Lemma spin_bound : forall i : nat, 0 <= spin i <= 6.
Proof.
  intro i.
  unfold spin.
  repeat (destruct (Nat.ltb _ _) eqn:?); simpl; lia.
Qed.

Theorem all_125 :
  forall i : nat, (i < 125)%nat ->
    numerator (casimir (spin i)) =
      if selected (spin i) then 1814400 else 0.
Proof.
  intros i Hi.
  apply seven_sectors.
  apply spin_bound.
Qed.

Definition casimirNumerator (v : nat -> Z) (i : nat) : Z :=
  numerator (casimir (spin i)) * v i.
Definition characterNumerator (v : nat -> Z) (i : nat) : Z :=
  if selected (spin i) then 1814400 * v i else 0.

Theorem full_projector_equality :
  forall (v : nat -> Z) (i : nat), (i < 125)%nat ->
    casimirNumerator v i = characterNumerator v i.
Proof.
  intros v i Hi.
  unfold casimirNumerator, characterNumerator.
  rewrite (all_125 i Hi).
  destruct (selected (spin i)); lia.
Qed.

Print Assumptions seven_sectors.
Print Assumptions all_125.
Print Assumptions full_projector_equality.
End E47ProjectorEquality.
