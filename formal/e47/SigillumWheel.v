(*
   THE TEN-REGISTER THEOREM
   for the Sigillum Dei Aemeth wheel.   Coq / Rocq mirror.

   Plain stdlib (List, Arith, Bool).  No axioms.  Every proof closes by
   `vm_compute; reflexivity`, which is kernel-checked conversion -- NOT a
   trusted oracle, so the trust story matches the Lean file exactly.

   `nat` is unary here, but every intermediate is <= 3*39+39 = 156, so the
   whole development evaluates instantly.
*)

Require Import List Arith Bool.
Import ListNotations.

Module Sigillum.

(* Stations on the rim. *)
Definition NN : nat := 40.

(* One click of the wheel at offset s. *)
Definition F (s j : nat) : nat := Nat.modulo (3 * j + s) NN.

Definition orbit (s j : nat) : list nat :=
  [j; F s j; F s (F s j); F s (F s (F s j))].

(* Canonical name of a register: its least station. *)
Definition rep (s j : nat) : nat := fold_right Nat.min j (orbit s j).

(* One station per register. *)
Definition reps (s : nat) : list nat :=
  filter (fun j => Nat.eqb (rep s j) j) (seq 0 NN).

Definition odds : list nat :=
  filter (fun s => Nat.eqb (Nat.modulo s 2) 1) (seq 0 NN).

(* ---------- PART I.  Reversible, period four, every offset. ---------- *)

Definition chk_injective : bool :=
  forallb (fun s => forallb (fun i => forallb (fun j =>
    implb (Nat.eqb (F s i) (F s j)) (Nat.eqb i j)) (seq 0 NN)) (seq 0 NN)) (seq 0 NN).

Theorem step_injective : chk_injective = true.
Proof. vm_compute. reflexivity. Qed.

Definition chk_period : bool :=
  forallb (fun s => forallb (fun j =>
    Nat.eqb (F s (F s (F s (F s j)))) j) (seq 0 NN)) (seq 0 NN).

Theorem period_four : chk_period = true.
Proof. vm_compute. reflexivity. Qed.

(* ---------- PART II.  Primitive at every ODD offset. ---------- *)

Definition chk_no_fixed : bool :=
  forallb (fun s => forallb (fun j => negb (Nat.eqb (F s j) j)) (seq 0 NN)) odds.

Theorem no_fixed_station : chk_no_fixed = true.
Proof. vm_compute. reflexivity. Qed.

Definition chk_no_swap : bool :=
  forallb (fun s => forallb (fun j => negb (Nat.eqb (F s (F s j)) j)) (seq 0 NN)) odds.

Theorem no_two_cycle : chk_no_swap = true.
Proof. vm_compute. reflexivity. Qed.

(* ---------- PART III.  THE TEN-REGISTER THEOREM. ---------- *)

Definition chk_ten : bool := forallb (fun s => Nat.eqb (length (reps s)) 10) odds.

Theorem ten_registers : chk_ten = true.
Proof. vm_compute. reflexivity. Qed.

Theorem omega_wheel : 10 * 4 = NN.
Proof. vm_compute. reflexivity. Qed.

Theorem even_offset_degenerates : length (reps 0) = 13.
Proof. vm_compute. reflexivity. Qed.

(* ---------- PART IV.  Constructive witness at s = 1. ---------- *)

Definition registers : list (list nat) :=
  [[0;1;4;13]; [2;7;22;27]; [3;10;31;14]; [5;16;9;28];  [6;19;18;15];
   [8;25;36;29]; [11;34;23;30]; [12;37;32;17]; [20;21;24;33]; [26;39;38;35]].

Theorem witness_count : length registers = 10.
Proof. vm_compute. reflexivity. Qed.

Definition chk_widths : bool := forallb (fun r => Nat.eqb (length r) 4) registers.
Theorem witness_widths : chk_widths = true.
Proof. vm_compute. reflexivity. Qed.

Theorem witness_total : length (concat registers) = NN.
Proof. vm_compute. reflexivity. Qed.

Definition chk_cover : bool :=
  forallb (fun j => existsb (fun r => existsb (Nat.eqb j) r) registers) (seq 0 NN).
Theorem witness_covers : chk_cover = true.
Proof. vm_compute. reflexivity. Qed.

Definition chk_closed : bool :=
  forallb (fun r => forallb (fun j => existsb (Nat.eqb (F 1 j)) r) r) registers.
Theorem witness_closed : chk_closed = true.
Proof. vm_compute. reflexivity. Qed.

(* ---------- PART V.  The CRT refinement:  10 = 2 + 8. ---------- *)

Theorem mod5_fixed_point : Nat.modulo (3 * 2 + 1) 5 = 2.
Proof. vm_compute. reflexivity. Qed.

Theorem crt_two :
  length (filter (fun j => Nat.eqb (Nat.modulo j 5) 2) (reps 1)) = 2.
Proof. vm_compute. reflexivity. Qed.

Theorem crt_eight :
  length (filter (fun j => negb (Nat.eqb (Nat.modulo j 5) 2)) (reps 1)) = 8.
Proof. vm_compute. reflexivity. Qed.

Theorem crt_sums : 2 + 8 = 10.
Proof. vm_compute. reflexivity. Qed.

End Sigillum.

(* Assumption ledger — the Coq counterpart of the Lean #print axioms block. *)
Print Assumptions Sigillum.step_injective.
Print Assumptions Sigillum.period_four.
Print Assumptions Sigillum.no_fixed_station.
Print Assumptions Sigillum.no_two_cycle.
Print Assumptions Sigillum.ten_registers.
Print Assumptions Sigillum.witness_covers.
Print Assumptions Sigillum.witness_closed.
Print Assumptions Sigillum.crt_two.
Print Assumptions Sigillum.crt_eight.
