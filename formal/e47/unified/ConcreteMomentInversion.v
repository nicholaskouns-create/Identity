(* Exact seven-root moment inversion. Roots are candidate values, not
   postulated concrete 125-state Casimir eigenvalues. The Python companion
   independently constructs C and its first seven integer power traces. *)
From Coq Require Import List Arith ZArith Bool.
Import ListNotations.
Open Scope Z_scope.

Module E47ConcreteMomentInversion.
Definition roots : list Z := [0; 2; 6; 12; 20; 30; 42].
Definition candidateMult : list Z := [1; 9; 25; 28; 27; 22; 13].
Definition observedMoments : list Z :=
  [125; 2250; 58500; 1827000; 63205200; 2327148000; 89208187200].
Definition lagrange : list (list Z) :=
  [[3628800; -3110400; 808848; -89280; 4648; -112; 1];
   [0; -1814400; 648000; -80424; 4428; -110; 1];
   [0; -604800; 417600; -65208; 4012; -106; 1];
   [0; -302400; 234000; -47904; 3448; -100; 1];
   [0; -181440; 146448; -33120; 2808; -92; 1];
   [0; -120960; 99648; -23640; 2188; -82; 1];
   [0; -86400; 72000; -17544; 1708; -70; 1]].
Definition denominators : list Z :=
  [3628800; -1612800; 1741824; -3110400; 8870400; -43545600; 479001600].

Definition evalRow (i j : nat) : Z :=
  fold_right Z.add 0 (map (fun k =>
    nth k (nth i lagrange []) 0 * Z.pow (nth j roots 0) (Z.of_nat k))
    (seq 0 7)).
Definition leftInverseOK : bool :=
  forallb (fun i => forallb (fun j =>
    Z.eqb (evalRow i j)
      (if Nat.eqb i j then nth i denominators 0 else 0))
    (seq 0 7)) (seq 0 7).
Definition candidateMoment (k : nat) : Z :=
  fold_right Z.add 0 (map (fun i =>
    nth i candidateMult 0 * Z.pow (nth i roots 0) (Z.of_nat k))
    (seq 0 7)).
Definition candidateMomentsOK : bool :=
  forallb (fun k => Z.eqb (candidateMoment k) (nth k observedMoments 0))
    (seq 0 7).
Definition recoveryOK (moments : list Z) : bool :=
  forallb (fun i =>
    Z.eqb
      (fold_right Z.add 0 (map (fun k =>
        nth k (nth i lagrange []) 0 * nth k moments 0) (seq 0 7)))
      (nth i denominators 0 * nth i candidateMult 0))
    (seq 0 7).
Definition mutantMoments : list Z :=
  [126; 2250; 58500; 1827000; 63205200; 2327148000; 89208187200].

Theorem lagrange_left_inverse : leftInverseOK = true.
Proof. vm_compute. reflexivity. Qed.
Theorem candidate_moment_vector : candidateMomentsOK = true.
Proof. vm_compute. reflexivity. Qed.
Theorem exact_multiplicity_recovery : recoveryOK observedMoments = true.
Proof. vm_compute. reflexivity. Qed.
Theorem mutant_moment_rejected : recoveryOK mutantMoments = false.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions lagrange_left_inverse.
Print Assumptions candidate_moment_vector.
Print Assumptions exact_multiplicity_recovery.
Print Assumptions mutant_moment_rejected.
End E47ConcreteMomentInversion.
