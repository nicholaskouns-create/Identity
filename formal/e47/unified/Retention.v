(* E47-RET-003: corrected polynomial degree and integer brackets. *)
From Coq Require Import ZArith Lia.
Open Scope Z_scope.
Module E47Retention.
Definition p (x : Z) := x^10-x-1.
Theorem at_one : p 1 = -1. Proof. reflexivity. Qed.
Theorem at_two : p 2 = 1021. Proof. reflexivity. Qed.
Theorem degree_ten_sample : 2^10=1024. Proof. reflexivity. Qed.
End E47Retention.
