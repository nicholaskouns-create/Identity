(* Concrete 125-dimensional spin-2 triple tensor [C,U], column 6.
   Imports unchanged integer generators and actual 125-term matrix products.
   Does not assume the centrality claim, spectrum, or kernel dimension. *)
From Coq Require Import ZArith Arith Bool List.
From E47Tensor Require Import Tensor125.
Import ListNotations.
Open Scope Z_scope.

(* Tensor125.v exports mulEntry and the generators but not this full
   off-diagonal Casimir definition. Construct it explicitly here rather
   than assuming a symbol from a different, unmerged proof branch. *)
Definition concreteCasimirEntry (i j : nat) : Z :=
  mulEntry totalDown totalUp i j +
  (if Nat.eqb i j then totalZ i i * (totalZ i i + 1) else 0).

Definition concreteCasimirUColumnSixOK (i : nat) : bool :=
  Z.eqb
    (mulEntry concreteCasimirEntry totalUp i 6%nat -
     mulEntry totalUp concreteCasimirEntry i 6%nat) 0.

Theorem concreteCasimirU_column_six :
  List.forallb concreteCasimirUColumnSixOK (List.seq 0 125) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions concreteCasimirU_column_six.
