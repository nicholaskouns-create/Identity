(* E47-CORE-002: rank and kernel as OUTPUTS.
   Rocq/Coq mirror of formal/e47/unified/RankNullity47.lean.

   E47-CORE-001 (Core47.v) defines carrier := 125 and kernel := 47 and then
   checks 47 + 78 = 125. The numerals are its input. This module removes that.

   Inputs: (1) the coupling 2 (x) 2 (x) 2, (2) the polynomial p(x)=(x-6)(x-30).
   125, 47 and 78 are computed. The identity is proved for EVERY spin content
   by induction, with no numeral in its statement, then specialised.

   Self-contained: stdlib only. *)

From Coq Require Import List PeanoNat ZArith Lia.
Import ListNotations.

Module E47RankNullity.

(* ---- Input 1: the coupling 2 (x) 2 (x) 2 ------------------------------- *)
(* Same construction as formal/e47/E47Spectral.v, repeated so this file
   compiles standalone under scripts/site_validate.py. *)

Fixpoint seq_from (lo len : nat) : list nat :=
  match len with
  | 0   => []
  | S n => lo :: seq_from (S lo) n
  end.

Definition couple (j1 j2 : nat) : list nat :=
  let lo := Nat.max (j1 - j2) (j2 - j1) in
  seq_from lo (j1 + j2 - lo + 1).

Definition threeSpin2 : list nat :=
  flat_map (fun j => couple j 2) (couple 2 2).

(* The carrier as blocks: one entry (j, 2j+1) per copy of spin j.
   Nothing written by hand; this is exactly the coupling output. *)
Definition blocks : list (nat * nat) :=
  map (fun j => (j, 2 * j + 1)) threeSpin2.

(* ---- Input 2: the annihilating polynomial ------------------------------ *)

Definition casimir (j : nat) : Z := Z.of_nat j * (Z.of_nat j + 1).
Definition p (x : Z) : Z := (x - 6) * (x - 30).
Definition annihilated (j : nat) : bool := Z.eqb (p (casimir j)) 0.

(* ---- Dimension bookkeeping --------------------------------------------- *)

Definition keep (b : bool) (m : nat) : nat := if b then m else 0.
Definition drop (b : bool) (m : nat) : nat := if b then 0 else m.

(* A block is counted on exactly one side. Both cases are definitional. *)
Lemma drop_add_keep : forall b m, drop b m + keep b m = m.
Proof. intros b m; destruct b; simpl; lia. Qed.

Fixpoint dim (l : list (nat * nat)) : nat :=
  match l with
  | []          => 0
  | (_, m) :: t => m + dim t
  end.

Fixpoint kerDim (l : list (nat * nat)) : nat :=
  match l with
  | []          => 0
  | (j, m) :: t => keep (annihilated j) m + kerDim t
  end.

Fixpoint rankDim (l : list (nat * nat)) : nat :=
  match l with
  | []          => 0
  | (j, m) :: t => drop (annihilated j) m + rankDim t
  end.

(* ---- The general theorem ------------------------------------------------ *)
(* Rank-nullity for a graded carrier. True of ANY list of blocks.
   No numeral appears in the statement or the proof. *)

Theorem rank_nullity : forall l, rankDim l + kerDim l = dim l.
Proof.
  induction l as [| [j m] t IH]; simpl.
  - reflexivity.
  - pose proof (drop_add_keep (annihilated j) m) as Hb. lia.
Qed.

(* ---- Read-outs ---------------------------------------------------------- *)
(* Each numeral below is the RESULT of evaluating the definitions on the
   coupling output. None is used as an input anywhere. *)

Lemma block_count : length blocks = 19.
Proof. vm_compute. reflexivity. Qed.

Lemma annihilated_spins : filter annihilated (seq 0 7) = [2; 5].
Proof. vm_compute. reflexivity. Qed.

Lemma carrier_eq : dim blocks = 125.
Proof. vm_compute. reflexivity. Qed.

Lemma kernel_eq : kerDim blocks = 47.
Proof. vm_compute. reflexivity. Qed.

Lemma rank_eq : rankDim blocks = 78.
Proof. vm_compute. reflexivity. Qed.

(* The dimension identity, obtained from the general theorem. *)
Theorem dimension_identity : rankDim blocks + kerDim blocks = dim blocks.
Proof. apply rank_nullity. Qed.

(* The same identity in numerals. Each side still carries its derivation:
   this is rank_nullity rewritten through the three read-outs, not a
   computation on literals. *)
(* Note: reverse-rewriting the numerals does not work here -- in Coq's unary
   nat, the term 47 is a subterm of 78 and of 125, so `rewrite <-` matches
   inside them. Going left to right through the read-outs avoids that. *)
Theorem dimension_identity_numeric : 78 + 47 = 125.
Proof.
  transitivity (rankDim blocks + kerDim blocks).
  - rewrite rank_eq, kernel_eq. reflexivity.
  - rewrite rank_nullity. apply carrier_eq.
Qed.

(* Agreement with E47-CORE-001's hand-written constants, stated as a check
   on them rather than an assumption. *)
Theorem agrees_with_core001 :
  kerDim blocks = 47 /\ dim blocks = 125 /\ rankDim blocks = 78.
Proof. repeat split; vm_compute; reflexivity. Qed.

End E47RankNullity.
