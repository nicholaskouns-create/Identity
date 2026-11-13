(* E47 QGNN exchange arithmetic certificates.
   Coq standard library only; no axioms or Admitted.
   Full Lie closure u(5) is NOT asserted in this module. *)
From Coq Require Import List ZArith Lia.
Import ListNotations.
Open Scope Z_scope.
Module E47QGNN.
Definition exchangeD : list Z := [-6;-5;-3;0;4].
Definition adjacentGaps : list Z := [1;2;3;4].
Definition gapSquares : list Z := map (fun x => x*x) adjacentGaps.
Definition couplingNumerators : list Z := [12;147;144;9].
Definition couplingDenominators : list Z := [1;20;35;7].
Theorem diagonal_exact : exchangeD = [-6;-5;-3;0;4].
Proof. reflexivity. Qed.
Theorem gaps_exact : gapSquares = [1;4;9;16].
Proof. reflexivity. Qed.
Theorem gaps_distinct : NoDup gapSquares.
Proof. repeat constructor; simpl; lia. Qed.
Theorem couplings_nonzero : Forall (fun x => 0 < x) couplingNumerators.
Proof. repeat constructor; lia. Qed.
Theorem denominators_nonzero : Forall (fun x => 0 < x) couplingDenominators.
Proof. repeat constructor; lia. Qed.
Theorem u5_real_dimension : 5*5 = 25.
Proof. reflexivity. Qed.
Theorem pu5_real_dimension : 5*5-1 = 24.
Proof. reflexivity. Qed.
Theorem e47_retained_dimension : 5*5+2*11 = 47.
Proof. reflexivity. Qed.
Theorem exchange_sum_spin2 : 2*(2+1)-18 = -12.
Proof. reflexivity. Qed.
End E47QGNN.
