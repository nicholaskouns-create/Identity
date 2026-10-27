From Coq Require Import Arith Lia.

Module KKPEntropy.

Theorem ratio_exact : 47 * 1000 = 376 * 125.
Proof. lia. Qed.

Theorem gl_case_a : 752 * 376 = 2 * 376 * 376.
Proof. lia. Qed.

Theorem gl_case_b : 400 * 200 = 2 * 200 * 200.
Proof. lia. Qed.

Theorem distinct_minima : 376 <> 200.
Proof. lia. Qed.

End KKPEntropy.
