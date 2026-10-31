(* MC-88 Discrete Filter Optimal-Step Theorem.
   Rational minimax via exact integer cross-multiplication.
   Source: canonical Notion citizen MC-88 and City Proof 88.
   The five K^2 eigenvalues are supplied spectral input; the concrete
   125x125 Casimir eigenspace correspondence remains a separate task. *)
From Coq Require Import ZArith Lia List.
Import ListNotations.
Open Scope Z_scope.

Module MC88OptimalStep.

Definition gamma : Z := 11664.
Definition lambdaMax : Z := 186624.
Definition qStar : Z := 99144.
Definition positiveSpectrum : list Z := [11664; 12544; 19600; 32400; 186624].

Theorem denominator_identity : gamma + lambdaMax = 2 * qStar.
Proof. reflexivity. Qed.

Theorem admissible_step : 0 < qStar /\ lambdaMax < 2 * qStar.
Proof. unfold qStar, lambdaMax. lia. Qed.

Theorem endpoint_equioscillation :
  17 * (qStar - gamma) = 15 * qStar /\
  17 * (lambdaMax - qStar) = 15 * qStar.
Proof. unfold qStar, gamma, lambdaMax. lia. Qed.

Theorem five_modes_within_sharp_bound :
  Forall (fun lam =>
    -15 * qStar <= 17 * (qStar - lam) /\
    17 * (qStar - lam) <= 15 * qStar) positiveSpectrum.
Proof.
  unfold positiveSpectrum, qStar.
  repeat constructor; lia.
Qed.

(* For any positive rational denominator q, at least one endpoint
   residual is >= 15*q/17. Together with the exact endpoint equality
   and five-mode bound this certifies the sharp rational minimax step. *)
Theorem rational_minimax_lower_bound :
  forall p q : Z, 0 < q ->
    15 * q <= 17 * (q - gamma * p) \/
    15 * q <= 17 * (lambdaMax * p - q).
Proof.
  intros p q hq.
  unfold gamma, lambdaMax.
  lia.
Qed.

End MC88OptimalStep.

Print Assumptions MC88OptimalStep.denominator_identity.
Print Assumptions MC88OptimalStep.admissible_step.
Print Assumptions MC88OptimalStep.endpoint_equioscillation.
Print Assumptions MC88OptimalStep.five_modes_within_sharp_bound.
Print Assumptions MC88OptimalStep.rational_minimax_lower_bound.
