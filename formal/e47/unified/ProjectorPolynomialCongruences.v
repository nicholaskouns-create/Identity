(* Paired exact coefficient identities for the E47 projector.
   This does not assume the concrete 125x125 Casimir annihilator M(C)=0.
   A separate formal polynomial-evaluation bridge is still required. *)
From Coq Require Import ZArith List.
Import ListNotations.
Open Scope Z_scope.

Module E47ProjectorCongruences.
Definition coeff (p : list Z) (i : nat) : Z := nth i p 0.
Definition polyMul (p q : list Z) : list Z :=
  map (fun k =>
    fold_left Z.add
      (map (fun i => coeff p i * coeff q (k - i)%nat) (seq 0 (S k))) 0)
    (seq 0 (length p + length q - 1)%nat).
Definition polySub (p q : list Z) : list Z :=
  map (fun k => coeff p k - coeff q k)
    (seq 0 (Nat.max (length p) (length q))).
Definition polyScale (s : Z) (p : list Z) : list Z := map (Z.mul s) p.
Definition product (factors : list (list Z)) : list Z :=
  fold_left polyMul factors [1].

Definition numerator : list Z :=
  product [[0;1];[-2;1];[-12;1];[-20;1];[-31;1];[-42;1]].
Definition annihilator : list Z :=
  product [[0;1];[-2;1];[-6;1];[-12;1];[-20;1];[-30;1];[-42;1]].
Definition kernelFilter : list Z := product [[-6;1];[-30;1]].
Definition qIdempotence : list Z := [312480;160048;-47400;3553;-102;1].
Definition qKernel : list Z := [-31;1].
Definition denominator : Z := 1814400.

Theorem numerator_coefficients :
  numerator = [0;-624960;430848;-66940;4088;-107;1].
Proof. vm_compute. reflexivity. Qed.

Theorem annihilator_coefficients :
  annihilator = [0;3628800;-3110400;808848;-89280;4648;-112;1].
Proof. vm_compute. reflexivity. Qed.

Theorem idempotence_polynomial_divisibility :
  polySub (polyMul numerator numerator) (polyScale denominator numerator) =
    polyMul annihilator qIdempotence.
Proof. vm_compute. reflexivity. Qed.

Theorem kernel_polynomial_divisibility :
  polyMul kernelFilter numerator = polyMul annihilator qKernel.
Proof. vm_compute. reflexivity. Qed.

Definition mutantNumerator : list Z :=
  product [[0;1];[-2;1];[-12;1];[-20;1];[-30;1];[-42;1]].

Theorem negative_control_rejected :
  polySub (polyMul mutantNumerator mutantNumerator)
    (polyScale denominator mutantNumerator) <>
    polyMul annihilator qIdempotence.
Proof. vm_compute. discriminate. Qed.

End E47ProjectorCongruences.

Print Assumptions E47ProjectorCongruences.numerator_coefficients.
Print Assumptions E47ProjectorCongruences.annihilator_coefficients.
Print Assumptions E47ProjectorCongruences.idempotence_polynomial_divisibility.
Print Assumptions E47ProjectorCongruences.kernel_polynomial_divisibility.
Print Assumptions E47ProjectorCongruences.negative_control_rejected.
