(* E47-CORE-003: the carrier bridge.
   Rocq/Coq mirror of formal/e47/unified/E47Bridge.lean.

   Proves that the spin content used to derive 47 and 78 is exactly the spin
   content read off the DIAGONAL OF THE CONCRETE totalZ on all 125 basis
   states, rather than assumed from the coupling 2 (x) 2 (x) 2.

   Does NOT prove dim ker (C-6I)(C-30I) = 47 for the full 125x125 Casimir.
   That needs Casimir centrality and the identification of eigenspaces with
   weight blocks (Proof Forge lanes #17, #19), which remain open.

   Self-contained: stdlib only. *)

From Coq Require Import List Arith ZArith Lia.
Import ListNotations.
Open Scope Z_scope.

Module E47Bridge.

(* ---- the concrete carrier, from Tensor125 ------------------------------- *)

Definition aa (n : nat) : nat := Nat.div n 25.
Definition bb (n : nat) : nat := Nat.modulo (Nat.div n 5) 5.
Definition cc (n : nat) : nat := Nat.modulo n 5.

(* The actual diagonal entry of the total weight operator at basis state n. *)
Definition totalZdiag (n : nat) : Z :=
  6 - Z.of_nat (aa n) - Z.of_nat (bb n) - Z.of_nat (cc n).

Definition states : list nat := seq 0 125.

(* How many of the 125 states carry weight m. Counts actual entries. *)
Definition weightCount (m : Z) : nat :=
  length (filter (fun n => Z.eqb (totalZdiag n) m) states).

Definition multiplicity (j : nat) : nat :=
  Nat.sub (weightCount (Z.of_nat j)) (weightCount (Z.of_nat (S j))).

(* ---- the assumed coupling, from E47Spectral ----------------------------- *)

Fixpoint seq_from (lo len : nat) : list nat :=
  match len with O => [] | S n => lo :: seq_from (S lo) n end.

Definition couple (j1 j2 : nat) : list nat :=
  let lo := Nat.max (j1 - j2) (j2 - j1) in
  seq_from lo (j1 + j2 - lo + 1).

Definition threeSpin2 : list nat :=
  flat_map (fun j => couple j 2) (couple 2 2).

Definition count (j : nat) (xs : list nat) : nat :=
  length (filter (fun x => Nat.eqb x j) xs).

(* ---- THE BRIDGE --------------------------------------------------------- *)

Theorem concrete_weights_match_coupling :
  map multiplicity (seq 0 7) = map (fun j => count j threeSpin2) (seq 0 7).
Proof. vm_compute. reflexivity. Qed.

Theorem multiplicities_are :
  map multiplicity (seq 0 7) = [1;3;5;4;3;2;1]%nat.
Proof. vm_compute. reflexivity. Qed.

(* ---- blocks from the CONCRETE operator ---------------------------------- *)

Definition blocksFromMatrix : list (nat * nat) :=
  flat_map (fun j => repeat (j, 2 * j + 1)%nat (multiplicity j)) (seq 0 7).

Definition casimir (j : nat) : Z := Z.of_nat j * (Z.of_nat j + 1).
Definition p (x : Z) : Z := (x - 6) * (x - 30).
Definition annihilated (j : nat) : bool := Z.eqb (p (casimir j)) 0.

Definition keep (b : bool) (m : nat) : nat := if b then m else O.
Definition drop (b : bool) (m : nat) : nat := if b then O else m.

Lemma drop_add_keep : forall b m, (drop b m + keep b m = m)%nat.
Proof. intros b m; destruct b; simpl; lia. Qed.

Fixpoint dim (l : list (nat * nat)) : nat :=
  match l with nil => O | (_, m) :: t => (m + dim t)%nat end.

Fixpoint kerDim (l : list (nat * nat)) : nat :=
  match l with nil => O | (j, m) :: t => (keep (annihilated j) m + kerDim t)%nat end.

Fixpoint rankDim (l : list (nat * nat)) : nat :=
  match l with nil => O | (j, m) :: t => (drop (annihilated j) m + rankDim t)%nat end.

Theorem rank_nullity : forall l, (rankDim l + kerDim l = dim l)%nat.
Proof.
  induction l as [| [j m] t IH]; simpl.
  - reflexivity.
  - pose proof (drop_add_keep (annihilated j) m) as Hb. lia.
Qed.

(* ---- read-outs grounded in the concrete operator ------------------------ *)

Theorem block_count_from_matrix : length blocksFromMatrix = 19%nat.
Proof. vm_compute. reflexivity. Qed.

Theorem carrier_from_matrix : dim blocksFromMatrix = 125%nat.
Proof. vm_compute. reflexivity. Qed.

Theorem kernel_from_matrix : kerDim blocksFromMatrix = 47%nat.
Proof. vm_compute. reflexivity. Qed.

Theorem rank_from_matrix : rankDim blocksFromMatrix = 78%nat.
Proof. vm_compute. reflexivity. Qed.

Theorem dimension_identity_from_matrix :
  (rankDim blocksFromMatrix + kerDim blocksFromMatrix = dim blocksFromMatrix)%nat.
Proof. apply rank_nullity. Qed.

(* ---- independent cross-checks against real matrix invariants ------------ *)
(* Each predicts a trace from the block decomposition; each is a number
   Tensor125 separately proves about the actual 125x125 matrices. *)

Definition blockWeightSum (j : nat) : Z :=
  fold_left (fun acc k => acc + (Z.of_nat k - Z.of_nat j)) (seq 0 (2 * j + 1)) 0.

Definition blockWeightSqSum (j : nat) : Z :=
  fold_left (fun acc k =>
    acc + (Z.of_nat k - Z.of_nat j) * (Z.of_nat k - Z.of_nat j))
    (seq 0 (2 * j + 1)) 0.

(* Tensor125.totalZ_trace = 0 *)
Theorem trace_Z_from_blocks :
  fold_left Z.add
    (map (fun j => Z.of_nat (multiplicity j) * blockWeightSum j) (seq 0 7)) 0 = 0.
Proof. vm_compute. reflexivity. Qed.

(* Tensor125.totalZ_diagonal_square_trace = 750 *)
Theorem trace_Z_squared_from_blocks :
  fold_left Z.add
    (map (fun j => Z.of_nat (multiplicity j) * blockWeightSqSum j) (seq 0 7)) 0 = 750.
Proof. vm_compute. reflexivity. Qed.

(* Tensor125.concrete_casimir_trace = 2250 *)
Theorem trace_casimir_from_blocks :
  fold_left Z.add
    (map (fun j => Z.of_nat (multiplicity j) * (2 * Z.of_nat j + 1) * casimir j)
         (seq 0 7)) 0 = 2250.
Proof. vm_compute. reflexivity. Qed.

Definition blocksFromCoupling : list (nat * nat) :=
  flat_map (fun j => repeat (j, 2 * j + 1)%nat (count j threeSpin2)) (seq 0 7).

Theorem blocks_agree : blocksFromMatrix = blocksFromCoupling.
Proof. vm_compute. reflexivity. Qed.

End E47Bridge.
