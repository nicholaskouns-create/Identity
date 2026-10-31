(* Exact integration of all 25 independently compiled concrete Casimir-Z
   five-column theorems. Imports the existing generator/theorem module,
   without altering it or triggering its 25 isolated CI workflows. *)
From Coq Require Import ZArith Arith Bool List.
From E47Tensor Require Import Tensor125.
Import ListNotations.
Open Scope Z_scope.

Theorem concreteCasimirZ_full_columns :
  List.forallb
    (fun j => List.forallb (fun i => concreteCasimirZEntryOK i j) (List.seq 0 125))
    (List.seq 0 125) = true.
Proof.
  set (column_ok := fun j : nat =>
    List.forallb (fun i => concreteCasimirZEntryOK i j) (List.seq 0 125)).
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
  rewrite concreteCasimirZ_first_five_columns.
  rewrite concreteCasimirZ_next_five_columns.
  rewrite concreteCasimirZ_columns_ten_through_fourteen.
  rewrite concreteCasimirZ_columns_fifteen_through_nineteen.
  rewrite concreteCasimirZ_columns_twenty_through_twentyfour.
  rewrite concreteCasimirZ_columns_twentyfive_through_twentynine.
  rewrite concreteCasimirZ_columns_thirty_through_thirtyfour.
  rewrite concreteCasimirZ_columns_thirtyfive_through_thirtynine.
  rewrite concreteCasimirZ_columns_forty_through_fortyfour.
  rewrite concreteCasimirZ_columns_fortyfive_through_fortynine.
  rewrite concreteCasimirZ_columns_fifty_through_fiftyfour.
  rewrite concreteCasimirZ_columns_fiftyfive_through_fiftynine.
  rewrite concreteCasimirZ_columns_sixty_through_sixtyfour.
  rewrite concreteCasimirZ_columns_sixtyfive_through_sixtynine.
  rewrite concreteCasimirZ_columns_seventy_through_seventyfour.
  rewrite concreteCasimirZ_columns_seventyfive_through_seventynine.
  rewrite concreteCasimirZ_columns_eighty_through_eightyfour.
  rewrite concreteCasimirZ_columns_eightyfive_through_eightynine.
  rewrite concreteCasimirZ_columns_ninety_through_ninetyfour.
  rewrite concreteCasimirZ_columns_ninetyfive_through_ninetynine.
  rewrite concreteCasimirZ_columns_onehundred_through_onehundredfour.
  rewrite concreteCasimirZ_columns_onehundredfive_through_onehundrednine.
  rewrite concreteCasimirZ_columns_onehundredten_through_onehundredfourteen.
  rewrite concreteCasimirZ_columns_onehundredfifteen_through_onehundrednineteen.
  rewrite concreteCasimirZ_columns_onehundredtwenty_through_onehundredtwentyfour.
  reflexivity.
Qed.

Print Assumptions concreteCasimirZ_full_columns.
