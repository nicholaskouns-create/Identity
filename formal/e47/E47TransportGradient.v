(*
E47 transport-gradient: exact 2-mode algebraic reduction.
This proves polynomial identities for a skew transport with a diagonal
positive gradient, not the full concrete 47x47 Casimir construction.
Uses only Coq standard library tactics and no axioms admitted here.
*)
Require Import Reals.
Require Import Psatz.
Require Import Ring.
Open Scope R_scope.

Theorem e47_dimension_census : (1 + 9 + 25 + 28 + 27 + 22 + 13 = 125)%nat.
Proof. reflexivity. Qed.

Theorem e47_protected_dimension : (25 + 22 = 47)%nat.
Proof. reflexivity. Qed.

Theorem skew_dot_zero : forall x y a : R,
  x * (- a * y) + y * (a * x) = 0.
Proof. intros; ring. Qed.

Theorem two_mode_gradient_nonnegative : forall x y b1 b2 : R,
  0 <= b1 -> 0 <= b2 ->
  0 <= b1 * x * x + b2 * y * y.
Proof.
  intros x y b1 b2 Hb1 Hb2.
  assert (Hx : 0 <= x * x) by nra.
  assert (Hy : 0 <= y * y) by nra.
  nra.
Qed.

Theorem two_mode_norm_identity : forall x y a b1 b2 gamma : R,
  2*x*(-a*y - gamma*b1*x) + 2*y*(a*x-gamma*b2*y)
  = -2*gamma*(b1*x*x+b2*y*y).
Proof. intros; ring. Qed.

Theorem two_mode_gradient_identity : forall x y a b1 b2 gamma : R,
  2*b1*x*(-a*y-gamma*b1*x) + 2*b2*y*(a*x-gamma*b2*y)
  = 2*a*(b2-b1)*x*y - 2*gamma*(b1*b1*x*x+b2*b2*y*y).
Proof. intros; ring. Qed.

Print Assumptions skew_dot_zero.
Print Assumptions two_mode_gradient_nonnegative.
Print Assumptions two_mode_norm_identity.
Print Assumptions two_mode_gradient_identity.
