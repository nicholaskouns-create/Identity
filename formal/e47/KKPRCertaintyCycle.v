(* KKP-R E47 certainty gate and reset; Coq standard libraries.
   P(q y)=q y is a hypothesis, not a constructed 125x125 Casimir matrix. *)
Require Import Coq.Arith.Arith.
Require Import Coq.ZArith.ZArith.
Require Import Coq.Vectors.Fin.
Definition Carrier := Fin.t 125 -> Z.
Definition Protected := Fin.t 47 -> Z.
Definition omega (score : Protected -> nat) (threshold : nat)
                 (y : Protected) : bool :=
  if le_dec (score y) threshold then true else false.
Definition selected (score : Protected -> nat) (threshold : nat)
                    (baseline y : Protected) : Protected :=
  if omega score threshold y then y else baseline.
Definition alpha (q : Protected -> Carrier)
                 (score : Protected -> nat) (threshold : nat)
                 (baseline y : Protected) : Carrier :=
  q (selected score threshold baseline y).
Definition cycle (sigma gamma : Carrier -> Carrier)
                 (lambda : Carrier -> Protected)
                 (psi : Protected -> Protected)
                 (q : Protected -> Carrier)
                 (score : Protected -> nat) (threshold : nat)
                 (baseline : Protected) (x : Carrier) : Carrier :=
  alpha q score threshold baseline (psi (lambda (gamma (sigma x)))).
Theorem omega_sound : forall score threshold y,
  omega score threshold y = true -> score y <= threshold.
Proof.
  intros score threshold y H.
  unfold omega in H.
  destruct (le_dec (score y) threshold) as [Hok|Hbad];
    [exact Hok|discriminate].
Qed.
Theorem selected_certified : forall score threshold baseline y,
  score baseline <= threshold ->
  score (selected score threshold baseline y) <= threshold.
Proof.
  intros score threshold baseline y Hbase.
  unfold selected, omega.
  destruct (le_dec (score y) threshold) as [Hok|Hbad];
    [exact Hok|exact Hbase].
Qed.
Theorem cycle_invariant : forall
  (P : Carrier -> Carrier) (q : Protected -> Carrier),
  (forall y, P (q y) = q y) ->
  forall (sigma gamma : Carrier -> Carrier)
         (lambda : Carrier -> Protected) (psi : Protected -> Protected)
         (score : Protected -> nat) (threshold : nat)
         (baseline : Protected) (x : Carrier),
  P (cycle sigma gamma lambda psi q score threshold baseline x) =
    cycle sigma gamma lambda psi q score threshold baseline x.
Proof.
  intros P q Hq sigma gamma lambda psi score threshold baseline x.
  unfold cycle, alpha.
  apply Hq.
Qed.
Theorem cycle_certified : forall (sigma gamma : Carrier -> Carrier)
  (lambda : Carrier -> Protected) (psi : Protected -> Protected)
  (score : Protected -> nat) (threshold : nat)
  (baseline : Protected) (x : Carrier),
  score baseline <= threshold ->
  score (selected score threshold baseline
    (psi (lambda (gamma (sigma x))))) <= threshold.
Proof.
  intros sigma gamma lambda psi score threshold baseline x Hbase.
  apply selected_certified; exact Hbase.
Qed.
Fixpoint iterate (f : Carrier -> Carrier) (n : nat) (x : Carrier) : Carrier :=
  match n with O => x | S k => f (iterate f k x) end.
Theorem repeated_invariant : forall (P : Carrier -> Carrier)
  (f : Carrier -> Carrier),
  (forall x, P (f x) = f x) -> forall n x,
  P (iterate f (S n) x) = iterate f (S n) x.
Proof.
  intros P f Hf n x.
  simpl; apply Hf.
Qed.
Theorem full_cycle_repeated_invariant : forall
  (P : Carrier -> Carrier) (q : Protected -> Carrier),
  (forall y, P (q y) = q y) ->
  forall (sigma gamma : Carrier -> Carrier)
         (lambda : Carrier -> Protected) (psi : Protected -> Protected)
         (score : Protected -> nat) (threshold : nat)
         (baseline : Protected) (n : nat) (x : Carrier),
  P (iterate (cycle sigma gamma lambda psi q score threshold baseline) (S n) x) =
    iterate (cycle sigma gamma lambda psi q score threshold baseline) (S n) x.
Proof.
  intros P q Hq sigma gamma lambda psi score threshold baseline n x.
  apply repeated_invariant.
  intro v; apply cycle_invariant; exact Hq.
Qed.
Print Assumptions cycle_invariant.
Print Assumptions cycle_certified.
Print Assumptions full_cycle_repeated_invariant.
