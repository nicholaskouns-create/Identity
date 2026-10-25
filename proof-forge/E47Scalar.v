(* E47 Proof Forge: scalar rank and dimension arithmetic only. *)
Require Import Coq.Arith.Arith.
Definition carrier_dimension : nat := 1 + 9 + 25 + 28 + 27 + 22 + 13.
Definition selected_dimension : nat := 25 + 22.
Theorem carrier_dimension_125 : carrier_dimension = 125.
Proof. reflexivity. Qed.
Theorem selected_dimension_47 : selected_dimension = 47.
Proof. reflexivity. Qed.
Theorem selected_bounded : selected_dimension <= carrier_dimension.
Proof. compute. auto with arith. Qed.
