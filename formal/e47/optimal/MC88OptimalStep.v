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


(* Exact uniqueness of the rational minimax Richardson step.
   The hypotheses are signed endpoint bounds after multiplying by
   17*q. No concrete Casimir eigenspace is assumed or proved here. *)
Theorem rational_sharp_step_unique :
  forall p q : Z,
    17 * (q - gamma * p) <= 15 * q ->
    17 * (lambdaMax * p - q) <= 15 * q ->
    q = qStar * p.
Proof.
  intros p q hleft hright.
  unfold gamma, lambdaMax, qStar in *.
  lia.
Qed.

Theorem rational_no_strict_endpoint_improvement :
  forall p q : Z,
    ~ (17 * (q - gamma * p) < 15 * q /\
       17 * (lambdaMax * p - q) < 15 * q).
Proof.
  intros p q [hleft hright].
  unfold gamma, lambdaMax in *.
  lia.
Qed.

(* Both endpoint absolute residuals are within the optimal bound
   exactly when p/q = 1/99144, for q > 0. *)
Theorem rational_sharp_endpoints_iff :
  forall p q : Z, 0 < q ->
    ((-15 * q <= 17 * (q - gamma * p) /\
       17 * (q - gamma * p) <= 15 * q) /\
     (-15 * q <= 17 * (q - lambdaMax * p) /\
       17 * (q - lambdaMax * p) <= 15 * q))
    <-> q = qStar * p.
Proof.
  intros p q hq.
  unfold gamma, lambdaMax, qStar.
  split; intro h; lia.
Qed.

End MC88OptimalStep.

Print Assumptions MC88OptimalStep.denominator_identity.
Print Assumptions MC88OptimalStep.admissible_step.
Print Assumptions MC88OptimalStep.endpoint_equioscillation.
Print Assumptions MC88OptimalStep.five_modes_within_sharp_bound.
Print Assumptions MC88OptimalStep.rational_minimax_lower_bound.
Print Assumptions MC88OptimalStep.rational_sharp_step_unique.
Print Assumptions MC88OptimalStep.rational_no_strict_endpoint_improvement.
Print Assumptions MC88OptimalStep.rational_sharp_endpoints_iff.
