(* E47-CORE-001: finite arithmetic, not a matrix certificate. *)
From Coq Require Import Lia.
Module E47Core.
Definition carrier : nat := 125.
Definition kernel : nat := 47.
Theorem dimension_identity : kernel + 78 = carrier. Proof. reflexivity. Qed.
Theorem kernel_below_carrier : kernel < carrier. Proof. unfold kernel, carrier. simpl. lia. Qed.
End E47Core.
