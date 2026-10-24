(* E47-TIME-004: discrete surrogate positivity only, not exp or proper time. *)
From Coq Require Import Lia.
Module E47Clock.
Definition surrogate_rate (n : nat) : nat := 1 + n*n.
Theorem surrogate_positive (n : nat) : 0 < surrogate_rate n.
Proof. unfold surrogate_rate. lia. Qed.
Theorem sample_rate : surrogate_rate 3 = 10. Proof. reflexivity. Qed.
End E47Clock.
