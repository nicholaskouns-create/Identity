(* LERI exact finite-sector certificate, Coq stdlib only.
   Finite arithmetic consequences of the joint SU(2)/S3 sector ledger.
   The 125x125 operator construction is tested separately in Python. *)
From Coq Require Import Arith Lia.
Module LERI.
Definition carrierDim : nat := 125.
Definition e47Dim : nat := 47.
Definition canonicalDim : nat := 5.
Definition symmetricDim : nat := 35.
Definition gap : nat := 11664.
Definition maxEigen : nat := 186624.
Definition stepDenominator : nat := 99144.
Theorem dimension_split : e47Dim + 78 = carrierDim.
Proof. reflexivity. Qed.
Theorem canonical_inside_e47 : canonicalDim < e47Dim.
Proof. compute; lia. Qed.
Theorem symmetric_sector_dimension : 1 + 5 + 7 + 9 + 13 = symmetricDim.
Proof. reflexivity. Qed.
Theorem total_joint_sector_dimension :
  1 + 9 + 5 + 20 + 7 + 21 + 9 + 18 + 22 + 13 = carrierDim.
Proof. reflexivity. Qed.
Theorem canonical_zero_multiplicity :
  5 + 49 + 9 + 21 + 9 + 18 + 1 + 13 = carrierDim.
Proof. reflexivity. Qed.
Theorem adjoint_multipoles : 1 + 3 + 5 + 7 + 9 = 25.
Proof. reflexivity. Qed.
Theorem density_affine_dimension : 5 * 5 - 1 = 24.
Proof. reflexivity. Qed.
Theorem spectral_midpoint : gap + maxEigen = 2 * stepDenominator.
Proof. reflexivity. Qed.
Theorem low_endpoint_factor :
  17 * (stepDenominator - gap) = 15 * stepDenominator.
Proof. unfold stepDenominator, gap. lia. Qed.
Theorem high_endpoint_factor :
  17 * (maxEigen - stepDenominator) = 15 * stepDenominator.
Proof. unfold stepDenominator, maxEigen. lia. Qed.
Theorem gap_strict : 0 < gap.
Proof. unfold gap. lia. Qed.
Theorem max_exceeds_gap : gap < maxEigen.
Proof. unfold gap, maxEigen. lia. Qed.
Theorem exact_omega : 47 * 1000 = 376 * 125.
Proof. reflexivity. Qed.
End LERI.
