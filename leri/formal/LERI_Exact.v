(* LERI exact finite-sector certificate, Coq 8.18 stdlib only.
   Arithmetic consequences of the joint SU(2)/S3 sector ledger,
   not a machine proof of construction of the 125x125 operator. *)
From Coq Require Import Arith Lia ZArith.
Module LERI.
Definition carrierDim : nat := 125.
Definition e47Dim : nat := 47.
Definition canonicalDim : nat := 5.
Definition symmetricDim : nat := 35.
(* Large spectral eigenvalues use Z, avoiding unary-nat evaluation. *)
Definition gap : Z := 11664%Z.
Definition maxEigen : Z := 186624%Z.
Definition stepDenominator : Z := 99144%Z.

Theorem dimension_split : e47Dim + 78 = carrierDim.
Proof. reflexivity. Qed.
Theorem canonical_inside_e47 : canonicalDim < e47Dim.
Proof. simpl. lia. Qed.
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
Theorem spectral_midpoint : (gap + maxEigen = 2 * stepDenominator)%Z.
Proof. unfold gap, maxEigen, stepDenominator. lia. Qed.
Theorem low_endpoint_factor :
  (17 * (stepDenominator - gap) = 15 * stepDenominator)%Z.
Proof. unfold gap, stepDenominator. lia. Qed.
Theorem high_endpoint_factor :
  (17 * (maxEigen - stepDenominator) = 15 * stepDenominator)%Z.
Proof. unfold maxEigen, stepDenominator. lia. Qed.
Theorem gap_strict : (0 < gap)%Z.
Proof. unfold gap. lia. Qed.
Theorem max_exceeds_gap : (gap < maxEigen)%Z.
Proof. unfold gap, maxEigen. lia. Qed.
Theorem exact_omega : (47 * 1000 = 376 * 125)%Z.
Proof. lia. Qed.
End LERI.
