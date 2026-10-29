(* E47 canonicalization and sector arithmetic; Coq 8.18 stdlib. *)
From Coq Require Import ZArith Lia.
Section Canonicalization.
Variables X I : Type.
Variable e : I -> X.
Variable p : X -> I.
Variable T : X -> X.
Hypothesis lawful : forall i : I, p (T (e i)) = i.
Definition S (x : X) : X := e (p (T x)).
Theorem S_idempotent : forall x, S (S x) = S x.
Proof.
 intro x. unfold S. rewrite lawful. reflexivity.
Qed.
End Canonicalization.
Definition Pc (v : Z * Z) : Z * Z := (fst v, 0%Z).
Definition Tc (v : Z * Z) : Z * Z := (snd v, fst v).
Definition Sc (v : Z * Z) : Z * Z := Pc (Tc v).
Lemma Pc_idempotent : forall v, Pc (Pc v) = Pc v.
Proof. intros [x y]; reflexivity. Qed.
Lemma Sc_not_idempotent : Sc (Sc (0%Z,1%Z)) <> Sc (0%Z,1%Z).
Proof. discriminate. Qed.
Lemma sector_dims_sum : (1+9+25+28+27+22+13=125)%nat.
Proof. lia. Qed.
Lemma kernel_dim : (25+22=47)%nat.
Proof. lia. Qed.
Lemma complement_dim : (1+9+28+27+13=78)%nat.
Proof. lia. Qed.
Lemma carrier_split : (47+78=125)%nat.
Proof. lia. Qed.
Lemma omega_cross : (47*1000=376*125)%nat.
Proof. lia. Qed.
