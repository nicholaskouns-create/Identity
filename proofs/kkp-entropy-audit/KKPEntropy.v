From Coq Require Import QArith Qring.
Open Scope Q_scope.

Module KKPEntropy.

Theorem ratio_exact : 47 / 125 == 376 / 1000.
Proof. unfold Qeq; simpl; reflexivity. Qed.

Definition gl (alpha beta x : Q) : Q := alpha*x + beta*x*x.

Theorem gl_example_a :
  gl (-752/1000) 1 (376/1000) == -(376/1000)*(376/1000).
Proof. unfold gl. ring. Qed.

Theorem gl_example_b :
  gl (-4/10) 1 (2/10) == -(2/10)*(2/10).
Proof. unfold gl. ring. Qed.

Theorem distinct_values : ~ (376/1000 == 2/10).
Proof. unfold Qeq; simpl; discriminate. Qed.

End KKPEntropy.
