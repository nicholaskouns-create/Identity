From Coq Require Import QArith QArith_base.
Open Scope Q_scope.
Module E47Richardson.
Definition eps : Q := 1#99144.
Definition multiplier (k2 : Q) : Q := 1 - eps * k2.
Lemma step_minimax : eps == 2 / (11664 + 186624).
Proof. unfold eps; vm_compute; reflexivity. Qed.
Lemma stability_lower : 0 < eps.
Proof. unfold eps; vm_compute; reflexivity. Qed.
Lemma stability_upper : eps < 2 / 186624.
Proof. unfold eps; vm_compute; reflexivity. Qed.
Lemma slow_sector : multiplier 11664 == 15#17.
Proof. unfold multiplier, eps; vm_compute; reflexivity. Qed.
Lemma fast_sector : multiplier 186624 == -(15#17).
Proof. unfold multiplier, eps; vm_compute; reflexivity. Qed.
Lemma retained_sector : multiplier 0 == 1.
Proof. unfold multiplier, eps; vm_compute; reflexivity. Qed.
Lemma normalized_identity (k : Q) :
  1 - eps * (k*k) == 1 - (32#17) * ((k/432)*(k/432)).
Proof. unfold eps; field; discriminate. Qed.
End E47Richardson.
