(* Concrete 125-state triple tensor generator entries, weight basis. *)
From Coq Require Import ZArith Arith Bool List.
Import ListNotations.
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

(* Finite certificates over the entire concrete 125-state diagonal.
   These establish weight counts and combinatorial block dimensions.
   They do not prove the full Casimir eigenspace decomposition. *)

Definition weightCount (m : Z) : nat :=
  List.length (List.filter (fun i => Z.eqb (totalZ i i) m) (List.seq 0 125)).

Definition multiplicity (j : nat) : nat :=
  Nat.sub (weightCount (Z.of_nat j)) (weightCount (Z.of_nat (S j))).

Theorem diagonal_weight_counts :
  List.map (fun n => weightCount (Z.of_nat n - 6)) (List.seq 0 13) =
  [1%nat; 3%nat; 6%nat; 10%nat; 15%nat; 18%nat; 19%nat;
   18%nat; 15%nat; 10%nat; 6%nat; 3%nat; 1%nat].
Proof. vm_compute. reflexivity. Qed.

Theorem spin_multiplicities_from_diagonal :
  List.map multiplicity (List.seq 0 7) =
  [1%nat; 3%nat; 5%nat; 4%nat; 3%nat; 2%nat; 1%nat].
Proof. vm_compute. reflexivity. Qed.

Theorem dimension_from_diagonal :
  List.fold_right Nat.add 0%nat
    (List.map (fun j => (multiplicity j * (2 * j + 1))%nat)
      (List.seq 0 7)) = 125%nat.
Proof. vm_compute. reflexivity. Qed.

Theorem selected_block_dimension_from_diagonal :
  (multiplicity 2%nat * 5 + multiplicity 5%nat * 11)%nat = 47%nat.
Proof. vm_compute. reflexivity. Qed.

Theorem totalZ_trace :
  List.fold_right Z.add 0
    (List.map (fun n => totalZ n n) (List.seq 0 125)) = 0.
Proof. vm_compute. reflexivity. Qed.

Theorem totalZ_diagonal_square_trace :
  List.fold_right Z.add 0
    (List.map (fun n => totalZ n n * totalZ n n) (List.seq 0 125)) = 750.
Proof. vm_compute. reflexivity. Qed.

(* Bounded all-index versions of the raising/lowering boundary checks. *)
Theorem highest_raising_zero_all :
  List.forallb (fun i => Z.eqb (totalUp i 0%nat) 0) (List.seq 0 125) = true.
Proof. vm_compute. reflexivity. Qed.

Theorem lowest_lowering_zero_all :
  List.forallb (fun i => Z.eqb (totalDown i 124%nat) 0) (List.seq 0 125) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions diagonal_weight_counts.
Print Assumptions spin_multiplicities_from_diagonal.
Print Assumptions dimension_from_diagonal.
Print Assumptions selected_block_dimension_from_diagonal.
Print Assumptions totalZ_trace.
Print Assumptions totalZ_diagonal_square_trace.
Print Assumptions highest_raising_zero_all.
Print Assumptions lowest_lowering_zero_all.


(* Exact finite entry certificates for [Z,Up]=Up and [Z,Down]=-Down.
   Z is diagonal, so [Z,A]_{ij} = (Z_ii - Z_jj) A_ij.
   This checks all 125*125 index pairs for each identity. *)
Definition z_up_entry_ok (i j : nat) : bool :=
  Z.eqb ((totalZ i i - totalZ j j) * totalUp i j) (totalUp i j).
Definition z_down_entry_ok (i j : nat) : bool :=
  Z.eqb ((totalZ i i - totalZ j j) * totalDown i j) (- totalDown i j).
Definition all_pairs_ok (f : nat -> nat -> bool) : bool :=
  List.forallb
    (fun i => List.forallb (fun j => f i j) (List.seq 0 125))
    (List.seq 0 125).

Theorem totalZ_up_bracket_entries : all_pairs_ok z_up_entry_ok = true.
Proof. vm_compute. reflexivity. Qed.
Theorem totalZ_down_bracket_entries : all_pairs_ok z_down_entry_ok = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalZ_up_bracket_entries.
Print Assumptions totalZ_down_bracket_entries.

(* Genuine 125-term integer matrix products. These certificates cover
   the diagonal of the third Lie bracket, not its off-diagonal entries. *)
Definition mulEntry (A B : nat -> nat -> Z) (i j : nat) : Z :=
  List.fold_right Z.add 0
    (List.map (fun k => A i k * B k j) (List.seq 0 125)).

Definition ud_diagonal_ok (i : nat) : bool :=
  Z.eqb (mulEntry totalUp totalDown i i -
         mulEntry totalDown totalUp i i) (2 * totalZ i i).

Theorem totalUp_down_bracket_diagonal :
  List.forallb ud_diagonal_ok (List.seq 0 125) = true.
Proof. vm_compute. reflexivity. Qed.

Definition casimirDiag (i : nat) : Z :=
  mulEntry totalDown totalUp i i +
  totalZ i i * (totalZ i i + 1).

Theorem concrete_casimir_trace :
  List.fold_right Z.add 0
    (List.map casimirDiag (List.seq 0 125)) = 2250.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_diagonal.
Print Assumptions concrete_casimir_trace.
