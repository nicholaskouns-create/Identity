(* KKP-R six-glyph arithmetic and typed compositional certificate.
   The stage functions are PARAMETERS, not derived operator specifications. *)
Require Import Coq.Arith.Arith.
Require Import Coq.Vectors.Fin.

Definition sigmaNumeral : nat := 200.
Definition gammaNumeral : nat := 3.
Definition lambdaNumeral : nat := 30.
Definition psiNumeral : nat := 700.
Definition omegaNumeral : nat := 800.
Definition alphaNumeral : nat := 1.

Theorem numeral_total :
  sigmaNumeral + gammaNumeral + lambdaNumeral +
  psiNumeral + omegaNumeral + alphaNumeral = 1734.
Proof. reflexivity. Qed.

Theorem carrier_dimension : 5 * 5 * 5 = 125.
Proof. reflexivity. Qed.

Theorem kernel_dimension : 5 * 5 + 2 * 11 = 47.
Proof. reflexivity. Qed.

Theorem complement_dimension : 125 - 47 = 78.
Proof. reflexivity. Qed.

Inductive decision : Type := accept | reject.

Definition partial_pipeline
  (sigma : Fin.t 125 -> Fin.t 125)
  (gamma : Fin.t 125 -> Fin.t 125)
  (lambda : Fin.t 125 -> Fin.t 47)
  (psi : Fin.t 47 -> Fin.t 47) : Fin.t 125 -> Fin.t 47 :=
  fun x => psi (lambda (gamma (sigma x))).

Definition full_pipeline
  (sigma : Fin.t 125 -> Fin.t 125)
  (gamma : Fin.t 125 -> Fin.t 125)
  (lambda : Fin.t 125 -> Fin.t 47)
  (psi : Fin.t 47 -> Fin.t 47)
  (omega : Fin.t 47 -> decision)
  (alpha : decision -> Fin.t 125) : Fin.t 125 -> Fin.t 125 :=
  fun x => alpha (omega (partial_pipeline sigma gamma lambda psi x)).

Theorem full_pipeline_expands : forall
  (sigma : Fin.t 125 -> Fin.t 125)
  (gamma : Fin.t 125 -> Fin.t 125)
  (lambda : Fin.t 125 -> Fin.t 47)
  (psi : Fin.t 47 -> Fin.t 47)
  (omega : Fin.t 47 -> decision)
  (alpha : decision -> Fin.t 125)
  (x : Fin.t 125),
  full_pipeline sigma gamma lambda psi omega alpha x =
  alpha (omega (psi (lambda (gamma (sigma x))))).
Proof. reflexivity. Qed.

Print Assumptions numeral_total.
Print Assumptions full_pipeline_expands.
