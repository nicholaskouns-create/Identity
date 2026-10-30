(* Modern cubic comparison; not an historical transcription. *)
From Coq Require Import Reals Lra Psatz.
Open Scope R_scope.
Definition cubic (a c x : R) : R := x^3 - a*x^2 + c.
Definition step (a c w x : R) : R := x + w * cubic a c x.
Theorem critical_value : forall a c : R,
  cubic a c (2*a/3) = c - 4*a^3/27.
Proof. intros; unfold cubic; field; lra. Qed.
Theorem critical_factor : forall a c x : R,
  cubic a c x - cubic a c (2*a/3) = (x-2*a/3)^2*(x+a/3).
Proof. intros; unfold cubic; field; lra. Qed.
Theorem fixed_root : forall a c w r : R,
  cubic a c r = 0 -> step a c w r = r.
Proof. intros a c w r H; unfold step; rewrite H; ring. Qed.
Theorem error_identity : forall a c w r e : R,
  cubic a c r = 0 -> step a c w (r+e) - r =
  (1-w*r*(2*a-3*r))*e + w*(3*r-a)*e^2 + w*e^3.
Proof.
  intros a c w r e H.
  unfold step, cubic in *.
  assert (Hc : c = a*r^2-r^3) by nra.
  rewrite Hc; ring.
Qed.
