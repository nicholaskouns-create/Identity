(*
   E47 spectral certificate — corrected arithmetic core.
   Coq / Rocq.  ZArith only.  No QArith, no MathComp, no admits.

   TWO CORRECTIONS to the prior version:

   (1) The contraction constants were stated over Q and closed with
       `reflexivity` on `Qeq`.  Replaced by integer cross-multiplication,
       which is what a rational identity means and which needs no QArith.

   (2) The file opened `nat_scope`.  Coq's nat is UNARY, so `reflexivity`
       on 2 974 320 = 2 974 320 would attempt to normalise a Peano numeral
       of that size and will not return.  Everything below is in Z_scope,
       whose literals are binary and reduce in microseconds.

   NOT COMPILED BY THE AUTHOR OF THIS FILE: no Coq toolchain was reachable
   in the environment where it was written.  Run `coqc E47Certificate.v`.
*)

Require Import ZArith.
Open Scope Z_scope.

(* ---- L1, L2, L4 : dimension residues ---- *)
Theorem carrier_dim    : 5 ^ 3 = 125.
Proof. reflexivity. Qed.

Theorem isotypic_sum   : 1*1 + 3*3 + 5*5 + 4*7 + 3*9 + 2*11 + 1*13 = 125.
Proof. reflexivity. Qed.

Theorem kernel_dim     : 5*5 + 2*11 = 47.
Proof. reflexivity. Qed.

Theorem rank_nullity   : 47 + 78 = 125.
Proof. reflexivity. Qed.

(* ---- L5 : commutant of the collective action on the kernel ---- *)
Theorem commutant_dim  : 5*5 + 2*2 = 29.
Proof. reflexivity. Qed.

(* The permutation group does not exhaust it: |S_3| = 6 < 29. *)
Theorem s3_too_small   : 6 < 29.
Proof. reflexivity. Qed.

(* ---- L3 : optimal contraction.  lam_min = 11664, lam_max = 186624. ---- *)
Theorem kappa_sixteen  : 186624 = 16 * 11664.
Proof. reflexivity. Qed.

(* eps* = 2/(lam_min + lam_max) = 1/99144, as a cross-multiplication. *)
Theorem contraction_star : 2 * 99144 = 1 * (11664 + 186624).
Proof. reflexivity. Qed.

(* rho* = (lam_max - lam_min)/(lam_max + lam_min) = 15/17. *)
Theorem contraction_rho  : (186624 - 11664) * 17 = 15 * (186624 + 11664).
Proof. reflexivity. Qed.

(* rho* = (kappa - 1)/(kappa + 1) with kappa = 16. *)
Theorem rho_from_kappa   : (16 - 1) * 17 = 15 * (16 + 1).
Proof. reflexivity. Qed.

(* ---- R6 : the four-fold carrier.  m_2 = 16, m_5 = 10. ---- *)
Theorem four_fold_dim    : 5 ^ 4 = 625.
Proof. reflexivity. Qed.

Theorem four_fold_kernel : 16*5 + 10*11 = 190.
Proof. reflexivity. Qed.

Theorem not_one_eight_seven : 190 <> 187.
Proof. discriminate. Qed.

Print Assumptions carrier_dim.
Print Assumptions contraction_star.
Print Assumptions contraction_rho.
Print Assumptions four_fold_kernel.
