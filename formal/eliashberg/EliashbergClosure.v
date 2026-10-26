From Coq Require Import Reals Psatz Field.
Open Scope R_scope.
Section Closure.
Variables lambda omega : R.
Hypothesis lambda_nonzero : lambda <> 0.
Hypothesis omega_nonzero : omega <> 0.
Definition weight := lambda * omega / 2.
Theorem coupling_closure : 2 * weight / omega = lambda.
Proof. unfold weight; field; split; assumption. Qed.
Theorem second_moment : (2 / lambda) * weight * omega = omega ^ 2.
Proof. unfold weight; field; assumption. Qed.
End Closure.
Print Assumptions coupling_closure.
Print Assumptions second_moment.
