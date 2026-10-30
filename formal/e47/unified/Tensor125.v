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


(* Candidate Casimir spectral moments computed from actual diagonal Z weights.
   These are necessary consistency checks, not an eigenspace or kernel proof.
   No concrete characteristic polynomial or rank is assumed. *)
Definition candidateCasimirSpectrum : list (nat * nat) :=
  List.map (fun j => ((j * (j + 1))%nat,
    (multiplicity j * (2 * j + 1))%nat)) (List.seq 0 7).

Theorem candidateCasimirSpectrum_exact :
  candidateCasimirSpectrum =
    [(0%nat, 1%nat); (2%nat, 9%nat); (6%nat, 25%nat);
     (12%nat, 28%nat); (20%nat, 27%nat); (30%nat, 22%nat);
     (42%nat, 13%nat)].
Proof. vm_compute. reflexivity. Qed.

(* Use binary Z for moments: a 58500%nat numeral overflows the Coq 8.18
   evaluator stack before the proof. Preserve the failed CI as evidence. *)
Definition candidateCasimirMoment (p : nat) : Z :=
  List.fold_right Z.add 0
    (List.map (fun j =>
      Z.of_nat (multiplicity j * (2 * j + 1)) *
      Z.pow (Z.of_nat (j * (j + 1))) (Z.of_nat p)) (List.seq 0 7)).

Theorem candidateCasimirMoments :
  candidateCasimirMoment 0%nat = 125 /\
  candidateCasimirMoment 1%nat = 2250 /\
  candidateCasimirMoment 2%nat = 58500.
Proof. vm_compute. repeat split; reflexivity. Qed.

Theorem candidateCasimirFirstMomentMatchesConcreteTrace :
  candidateCasimirMoment 1%nat =
    List.fold_right Z.add 0 (List.map casimirDiag (List.seq 0 125)).
Proof. rewrite concrete_casimir_trace. vm_compute. reflexivity. Qed.

Print Assumptions candidateCasimirSpectrum_exact.
Print Assumptions candidateCasimirMoments.
Print Assumptions candidateCasimirFirstMomentMatchesConcreteTrace.

(* First five complete columns of [Up,Down]=2Z on the genuine
   125-term matrix products. This includes every off-diagonal row
   in columns 0..4. The remaining columns are not claimed. *)
Definition ud_entry_ok (i j : nat) : bool :=
  Z.eqb (mulEntry totalUp totalDown i j -
         mulEntry totalDown totalUp i j) (2 * totalZ i j).

Theorem totalUp_down_bracket_first_five_columns :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 0 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_first_five_columns.

(* Next five complete columns, 5..9, of the genuine 125-term
   [Up,Down]=2Z matrix products. This does not import the target
   identity as an assumption and does not certify columns 10..124. *)
Theorem totalUp_down_bracket_next_five_columns :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 5 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_next_five_columns.

(* Five additional concrete columns, 10..14, of [Up,Down]=2Z.
   Each entry uses the original 125-term integer matrix products.
   The remaining 110 columns are not claimed. *)
Theorem totalUp_down_bracket_columns_ten_through_fourteen :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 10 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_ten_through_fourteen.

(* Genuine 125-term integer matrix products for every row of columns 15..19.
   The preceding 0..14 column proofs are retained; 20..124 remain open. *)
Theorem totalUp_down_bracket_columns_fifteen_through_nineteen :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 15 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_fifteen_through_nineteen.

(* Five additional concrete columns 20..24 of [Up,Down]=2Z.
   All 625 entries use the genuine 125-term integer matrix products.
   Columns 25..124 remain a separate formal obligation. *)
Theorem totalUp_down_bracket_columns_twenty_through_twentyfour :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 20 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_twenty_through_twentyfour.

(* Concrete third-bracket columns 25..29, each of 125 rows using the
   original 125-term integer matrix products. This theorem is checked
   by computation; no full-bracket identity is imported as an axiom.
   Columns 30..124 remain unproved in the formal certificate. *)
Theorem totalUp_down_bracket_columns_twentyfive_through_twentynine :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 25 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_twentyfive_through_twentynine.


(* Concrete third-bracket columns 30..34, all 625 entries computed from
   the genuine 125-term integer matrix products, not a diagonal surrogate.
   This does not assert the remaining columns 35..124. *)
Theorem totalUp_down_bracket_columns_thirty_through_thirtyfour :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 30 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_thirty_through_thirtyfour.


(* Concrete third-bracket columns 35..39, all 625 entries from the
   original 125-term integer matrix products; no imported bracket axiom.
   Columns 40..124 remain unproved in this formal certificate. *)
Theorem totalUp_down_bracket_columns_thirtyfive_through_thirtynine :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 35 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_thirtyfive_through_thirtynine.

(* Concrete third-bracket columns 40..44: all 625 entries from
   original 125-term integer matrix products, not a diagonal surrogate.
   Columns 45..124 remain independent formal obligations. *)
Theorem totalUp_down_bracket_columns_forty_through_fortyfour :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 40 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_forty_through_fortyfour.

(* Concrete third-bracket columns 45..49, all 625 entries from the
   genuine 125-term integer matrix products, without an imported
   commutator theorem. Columns 50..124 remain separate obligations. *)
Theorem totalUp_down_bracket_columns_fortyfive_through_fortynine :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 45 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_fortyfive_through_fortynine.

(* Concrete third-bracket columns 50..54: all 625 entries of
   [totalUp,totalDown] = 2 totalZ use the explicit spin-2 triple tensor
   generators and full 125-term integer matrix products. No imported
   commutator axiom. Columns 55..124 remain open. *)
Theorem totalUp_down_bracket_columns_fifty_through_fiftyfour :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 50 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_fifty_through_fiftyfour.

(* Concrete third-bracket columns 55..59: all 625 entries computed
   using the original 125-term integer matrix products of explicit
   spin-2 triple tensor generators. No imported commutator theorem.
   Columns 60..124 remain separate proof obligations. *)
Theorem totalUp_down_bracket_columns_fiftyfive_through_fiftynine :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 55 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_fiftyfive_through_fiftynine.

(* Concrete third-bracket columns 60..64: all 625 entries computed
   from the explicit integer spin-2 triple tensor generators and genuine
   125-term matrix products. No imported bracket theorem or axiom.
   Columns 65..124 remain independent proof obligations. *)
Theorem totalUp_down_bracket_columns_sixty_through_sixtyfour :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 60 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_sixty_through_sixtyfour.

(* Concrete third-bracket columns 65..69: 625 entries from the explicit
   spin-2 triple tensor generators and full 125-term matrix products.
   No imported commutator conclusion. Columns 70..124 remain open. *)
Theorem totalUp_down_bracket_columns_sixtyfive_through_sixtynine :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 65 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_sixtyfive_through_sixtynine.

(* Concrete third-bracket columns 70..74: 625 entries from the explicit
   spin-2 triple tensor generators and full 125-term matrix products.
   No imported commutator conclusion. Columns 75..124 remain open. *)
Theorem totalUp_down_bracket_columns_seventy_through_seventyfour :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 70 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_seventy_through_seventyfour.

(* Concrete third-bracket columns 75..79: 625 entries from the explicit
   spin-2 triple tensor generators and full 125-term matrix products.
   No imported commutator conclusion. Columns 80..124 remain open. *)
Theorem totalUp_down_bracket_columns_seventyfive_through_seventynine :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 75 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_seventyfive_through_seventynine.

(* Concrete third-bracket columns 80..84: all 625 entries of
   [totalUp,totalDown] = 2 totalZ use the explicit integer spin-2
   triple-tensor generators and genuine 125-term matrix products.
   No imported commutator conclusion. Columns 85..124 remain open. *)
Theorem totalUp_down_bracket_columns_eighty_through_eightyfour :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 80 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_eighty_through_eightyfour.

(* Concrete third-bracket columns 85..89: all 625 entries of
   [totalUp,totalDown] = 2 totalZ use explicit spin-2 triple-tensor
   generators and genuine 125-term integer matrix products.
   No imported commutator conclusion. Columns 90..124 remain open. *)
Theorem totalUp_down_bracket_columns_eightyfive_through_eightynine :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 85 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_eightyfive_through_eightynine.

(* Concrete third-bracket columns 90..94: 625 entries of
   [totalUp,totalDown] = 2 totalZ from explicit 125-state generators.
   No imported commutator conclusion. Columns 95..124 remain open. *)
Theorem totalUp_down_bracket_columns_ninety_through_ninetyfour :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 90 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_ninety_through_ninetyfour.

(* Concrete third-bracket columns 95..99: all 625 entries of
   [totalUp,totalDown] = 2 totalZ from explicit 125-state generators.
   No imported commutator conclusion. Columns 100..124 remain open. *)
Theorem totalUp_down_bracket_columns_ninetyfive_through_ninetynine :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 95 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_ninetyfive_through_ninetynine.

(* Concrete third-bracket columns 100..104: all 625 entries of
   [totalUp,totalDown] = 2 totalZ from the explicit 125-state generators.
   No imported commutator conclusion. Columns 105..124 remain open. *)
Theorem totalUp_down_bracket_columns_onehundred_through_onehundredfour :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 100 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_onehundred_through_onehundredfour.

(* Concrete third-bracket columns 105..109: all 625 entries of
   [totalUp,totalDown] = 2 totalZ from explicit 125-state generators.
   No imported commutator conclusion. Columns 110..124 remain open. *)
Theorem totalUp_down_bracket_columns_onehundredfive_through_onehundrednine :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 105 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_onehundredfive_through_onehundrednine.


(* Concrete third-bracket columns 110..114: all 625 entries of
   [totalUp,totalDown] = 2 totalZ from explicit 125-state generators.
   No imported commutator conclusion. Columns 115..124 remain open. *)
Theorem totalUp_down_bracket_columns_onehundredten_through_onehundredfourteen :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 110 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_onehundredten_through_onehundredfourteen.


(* Concrete third-bracket columns 115..119: all 625 entries of
   [totalUp,totalDown] = 2 totalZ from explicit 125-state generators.
   No imported commutator conclusion. Columns 120..124 remain open. *)
Theorem totalUp_down_bracket_columns_onehundredfifteen_through_onehundrednineteen :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 115 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_onehundredfifteen_through_onehundrednineteen.

(* Concrete third-bracket columns 120..124: final 625 entries of
   [totalUp,totalDown] = 2 totalZ from explicit 125-state generators.
   No imported commutator conclusion. This completes the 25 five-column
   certificates; their integration is a separate proof obligation. *)
Theorem totalUp_down_bracket_columns_onehundredtwenty_through_onehundredtwentyfour :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 120 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions totalUp_down_bracket_columns_onehundredtwenty_through_onehundredtwentyfour.

(* Exact partition and integration of the 25 separately proved five-column
   concrete [Up,Down]=2Z certificates. No 15,625-entry recomputation,
   imported commutator axiom, or assumption about the spectrum. *)
Definition thirdBracketColumnPartition : list nat :=
  List.flat_map (fun block =>
    List.map (fun offset => (5 * block + offset)%nat) (List.seq 0 5))
    (List.seq 0 25).

Theorem thirdBracketColumnPartition_exact :
  thirdBracketColumnPartition = List.seq 0 125.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions thirdBracketColumnPartition_exact.

Theorem totalUp_down_bracket_full_columns :
  List.forallb
    (fun j => List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125))
    (List.seq 0 125) = true.
Proof.
  set (column_ok := fun j : nat =>
    List.forallb (fun i => ud_entry_ok i j) (List.seq 0 125)).
  replace (List.seq 0 125) with
    (List.seq 0 5 ++
     List.seq 5 5 ++
     List.seq 10 5 ++
     List.seq 15 5 ++
     List.seq 20 5 ++
     List.seq 25 5 ++
     List.seq 30 5 ++
     List.seq 35 5 ++
     List.seq 40 5 ++
     List.seq 45 5 ++
     List.seq 50 5 ++
     List.seq 55 5 ++
     List.seq 60 5 ++
     List.seq 65 5 ++
     List.seq 70 5 ++
     List.seq 75 5 ++
     List.seq 80 5 ++
     List.seq 85 5 ++
     List.seq 90 5 ++
     List.seq 95 5 ++
     List.seq 100 5 ++
     List.seq 105 5 ++
     List.seq 110 5 ++
     List.seq 115 5 ++
     List.seq 120 5)
    by (vm_compute; reflexivity).
  repeat rewrite List.forallb_app.
  unfold column_ok.
  rewrite totalUp_down_bracket_first_five_columns.
  rewrite totalUp_down_bracket_next_five_columns.
  rewrite totalUp_down_bracket_columns_ten_through_fourteen.
  rewrite totalUp_down_bracket_columns_fifteen_through_nineteen.
  rewrite totalUp_down_bracket_columns_twenty_through_twentyfour.
  rewrite totalUp_down_bracket_columns_twentyfive_through_twentynine.
  rewrite totalUp_down_bracket_columns_thirty_through_thirtyfour.
  rewrite totalUp_down_bracket_columns_thirtyfive_through_thirtynine.
  rewrite totalUp_down_bracket_columns_forty_through_fortyfour.
  rewrite totalUp_down_bracket_columns_fortyfive_through_fortynine.
  rewrite totalUp_down_bracket_columns_fifty_through_fiftyfour.
  rewrite totalUp_down_bracket_columns_fiftyfive_through_fiftynine.
  rewrite totalUp_down_bracket_columns_sixty_through_sixtyfour.
  rewrite totalUp_down_bracket_columns_sixtyfive_through_sixtynine.
  rewrite totalUp_down_bracket_columns_seventy_through_seventyfour.
  rewrite totalUp_down_bracket_columns_seventyfive_through_seventynine.
  rewrite totalUp_down_bracket_columns_eighty_through_eightyfour.
  rewrite totalUp_down_bracket_columns_eightyfive_through_eightynine.
  rewrite totalUp_down_bracket_columns_ninety_through_ninetyfour.
  rewrite totalUp_down_bracket_columns_ninetyfive_through_ninetynine.
  rewrite totalUp_down_bracket_columns_onehundred_through_onehundredfour.
  rewrite totalUp_down_bracket_columns_onehundredfive_through_onehundrednine.
  rewrite totalUp_down_bracket_columns_onehundredten_through_onehundredfourteen.
  rewrite totalUp_down_bracket_columns_onehundredfifteen_through_onehundrednineteen.
  rewrite totalUp_down_bracket_columns_onehundredtwenty_through_onehundredtwentyfour.
  reflexivity.
Qed.

Print Assumptions totalUp_down_bracket_full_columns.


(* Concrete C = D*U + Z*(Z+I), using the genuine 125-term product.
   Z is diagonal, so [C,Z]_{ij} = (Z_jj-Z_ii)*C_ij.
   This checks every row and columns 0..4, not the full matrix.
   No imported Casimir centrality axiom or spectral conclusion. *)
Definition concreteCasimirEntry (i j : nat) : Z :=
  mulEntry totalDown totalUp i j +
    (if Nat.eqb i j then totalZ i i * (totalZ i i + 1) else 0).

Definition concreteCasimirZEntryOK (i j : nat) : bool :=
  Z.eqb ((totalZ i i - totalZ j j) * concreteCasimirEntry i j) 0.

Theorem concreteCasimirZ_first_five_columns :
  List.forallb
    (fun j => List.forallb
      (fun i => concreteCasimirZEntryOK i j) (List.seq 0 125))
    (List.seq 0 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions concreteCasimirZ_first_five_columns.

(* Concrete Casimir centrality [C,Z] for all rows, columns 5..9.
   Reuses the actual 125-term D*U matrix product, not spectral data. *)
Theorem concreteCasimirZ_next_five_columns :
  List.forallb
    (fun j => List.forallb
      (fun i => concreteCasimirZEntryOK i j) (List.seq 0 125))
    (List.seq 5 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions concreteCasimirZ_next_five_columns.

(* Exact [C,Z] columns 10..14: 625 concrete entries from the genuine
   125-term D*U product and diagonal Z correction. No assumed spectrum,
   imported Casimir centrality theorem, or admitted lemma. *)
Theorem concreteCasimirZ_columns_ten_through_fourteen :
  List.forallb
    (fun j => List.forallb
      (fun i => concreteCasimirZEntryOK i j) (List.seq 0 125))
    (List.seq 10 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions concreteCasimirZ_columns_ten_through_fourteen.

(* Concrete [C,Z] columns 15..19: 625 entries computed from the genuine
   125-term D*U product and diagonal Z correction. No assumed Casimir
   spectrum or imported centrality theorem. Columns 20..124 remain open. *)
Theorem concreteCasimirZ_columns_fifteen_through_nineteen :
  List.forallb
    (fun j => List.forallb
      (fun i => concreteCasimirZEntryOK i j) (List.seq 0 125))
    (List.seq 15 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions concreteCasimirZ_columns_fifteen_through_nineteen.

(* Concrete Casimir centrality [C,Z], all 125 rows and columns 20..24.
   Uses the genuine 125-term D*U matrix product and diagonal Z correction.
   No imported spectral multiplicity or commutator assumption. *)
Theorem concreteCasimirZ_columns_twenty_through_twentyfour :
  List.forallb
    (fun j => List.forallb
      (fun i => concreteCasimirZEntryOK i j) (List.seq 0 125))
    (List.seq 20 5) = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions concreteCasimirZ_columns_twenty_through_twentyfour.
