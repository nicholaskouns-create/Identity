(* Concrete 125-dimensional spin-2 triple tensor [C,D], column one.
   Uses existing Tensor125.v definitions and 125-term matrix products.
   No full centrality, spectrum or rank hypothesis is imported. *)
From Coq Require Import ZArith Arith Bool List.
From E47Tensor Require Import Tensor125.
Import ListNotations.
Open Scope Z_scope.

Definition concreteCasimirDColumnOneOK (i : nat) : bool :=
  Z.eqb
    (mulEntry concreteCasimirEntry totalDown i 1%nat -
     mulEntry totalDown concreteCasimirEntry i 1%nat) 0.

Theorem concreteCasimirD_column_one :
  List.forallb concreteCasimirDColumnOneOK (List.seq 0 125) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions concreteCasimirD_column_one.
