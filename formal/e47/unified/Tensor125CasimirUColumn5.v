(* Concrete 125-dimensional spin-2 triple tensor [C,U], column 5.
   Imports unchanged integer generators and actual 125-term matrix products.
   Does not assume the centrality claim, spectrum, or kernel dimension. *)
From Coq Require Import ZArith Arith Bool List.
From E47Tensor Require Import Tensor125.
Import ListNotations.
Open Scope Z_scope.

Definition concreteCasimirUColumnFiveOK (i : nat) : bool :=
  Z.eqb
    (mulEntry concreteCasimirEntry totalUp i 5%nat -
     mulEntry totalUp concreteCasimirEntry i 5%nat) 0.

Theorem concreteCasimirU_column_five :
  List.forallb concreteCasimirUColumnFiveOK (List.seq 0 125) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions concreteCasimirU_column_five.
