From Coq Require Import Arith Lia.

(* E47 29-unit arithmetic certificate.
   These results check dimensions only, not the representation-theoretic
   SU(2) commutant isomorphism. *)

Module E47Kernel29.

Definition carrier_dim : nat := 5 * 5 * 5.
Definition selected_dim : nat := 5 * 5 + 2 * 11.
Definition intertwiner_dim : nat := 5 * 5 + 2 * 2.
Definition logical_dim : nat := 2.
Definition logical_operator_dim : nat :=
  logical_dim * logical_dim.

Theorem carrier_eq : carrier_dim = 125.
Proof. unfold carrier_dim; lia. Qed.

Theorem selected_eq : selected_dim = 47.
Proof. unfold selected_dim; lia. Qed.

Theorem intertwiner_eq : intertwiner_dim = 29.
Proof. unfold intertwiner_dim; lia. Qed.

Theorem qubit_algebra_eq : logical_operator_dim = 4.
Proof.
  unfold logical_operator_dim, logical_dim.
  lia.
Qed.

End E47Kernel29.
