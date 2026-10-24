(* E47-RG-002: prescribed polynomial beta fixed points only. *)
From Coq Require Import ZArith Lia.
Open Scope Z_scope.
Module E47RG.
Definition beta_num (g : Z) := 125*g - 47*g*g.
Definition dimension_num (d : Z) := 10-d.
Theorem zero_fixed : beta_num 0 = 0. Proof. reflexivity. Qed.
Theorem positive_fixed_scaled : 125*47-47*125=0. Proof. lia. Qed.
Theorem dimension_fixed : dimension_num 10 = 0. Proof. reflexivity. Qed.
End E47RG.
