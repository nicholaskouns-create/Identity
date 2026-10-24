(* Concrete 125-state triple tensor generator entries, weight basis. *)
From Coq Require Import ZArith Arith Bool.
Open Scope Z_scope.
Definition a (n : nat) := (n / 25)%nat.
Definition b (n : nat) := ((n / 5) mod 5)%nat.
Definition c (n : nat) := (n mod 5)%nat.
Definition totalZ (i j : nat) : Z :=
  if Nat.eqb i j then 6 - Z.of_nat (a i) - Z.of_nat (b i) - Z.of_nat (c i) else 0.
Definition totalUp (i j : nat) : Z :=
  (if (Nat.eqb (S (a i)) (a j) && Nat.eqb (b i) (b j) && Nat.eqb (c i) (c j))%bool
    then Z.of_nat (a j) * (5 - Z.of_nat (a j)) else 0) +
  (if (Nat.eqb (a i) (a j) && Nat.eqb (S (b i)) (b j) && Nat.eqb (c i) (c j))%bool
    then Z.of_nat (b j) * (5 - Z.of_nat (b j)) else 0) +
  (if (Nat.eqb (a i) (a j) && Nat.eqb (b i) (b j) && Nat.eqb (S (c i)) (c j))%bool
    then Z.of_nat (c j) * (5 - Z.of_nat (c j)) else 0).
Definition totalDown (i j : nat) : Z :=
  (if (Nat.eqb (a i) (S (a j)) && Nat.eqb (b i) (b j) && Nat.eqb (c i) (c j))%bool then 1 else 0) +
  (if (Nat.eqb (a i) (a j) && Nat.eqb (b i) (S (b j)) && Nat.eqb (c i) (c j))%bool then 1 else 0) +
  (if (Nat.eqb (a i) (a j) && Nat.eqb (b i) (b j) && Nat.eqb (c i) (S (c j)))%bool then 1 else 0).
Theorem highest_weight : totalZ 0%nat 0%nat = 6.
Proof. vm_compute. reflexivity. Qed.
Theorem lowest_weight : totalZ 124%nat 124%nat = -6.
Proof. vm_compute. reflexivity. Qed.
Theorem highest_raising_zero : totalUp 0%nat 0%nat = 0.
Proof. vm_compute. reflexivity. Qed.
Theorem lowest_lowering_zero : totalDown 124%nat 124%nat = 0.
Proof. vm_compute. reflexivity. Qed.
