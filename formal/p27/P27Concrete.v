From Coq Require Import ZArith Lia.
Open Scope Z_scope.
Definition p (i:Z) : Z := if Z.ltb i 26 then 1 else 0.
Definition e (i:Z) : Z := if Z.eqb i 26 then 1 else 0.
Definition p27 (i:Z) : Z := p i + e i.
Definition q27 (i:Z) : Z := 1 - p27 i.
Lemma p27_boolean : forall i, 0 <= i < 64 -> p27 i = 0 \/ p27 i = 1.
Proof.
 intros i hi. unfold p27,p,e.
 destruct (Z.ltb i 26) eqn:hp; destruct (Z.eqb i 26) eqn:he;
 apply Z.ltb_lt in hp || apply Z.ltb_ge in hp;
 try (apply Z.eqb_eq in he); try (apply Z.eqb_neq in he); lia.
Qed.
Lemma p27_idempotent : forall i, 0 <= i < 64 -> p27 i * p27 i = p27 i.
Proof. intros i hi; destruct (p27_boolean i hi) as [h|h]; rewrite h; lia. Qed.
Lemma q27_idempotent : forall i, 0 <= i < 64 -> q27 i * q27 i = q27 i.
Proof. intros i hi; destruct (p27_boolean i hi) as [h|h]; unfold q27; rewrite h; lia. Qed.
Lemma p27_orthogonal : forall i, 0 <= i < 64 -> p27 i * q27 i = 0.
Proof. intros i hi; destruct (p27_boolean i hi) as [h|h]; unfold q27; rewrite h; lia. Qed.
Theorem halmos_involution : forall i x y, 0 <= i < 64 ->
 p27 i * (p27 i * x + q27 i * y) + q27 i * (q27 i * x - p27 i * y) = x /\
 q27 i * (p27 i * x + q27 i * y) - p27 i * (q27 i * x - p27 i * y) = y.
Proof.
 intros i x y hi.
 destruct (p27_boolean i hi) as [h|h]; unfold q27; rewrite h; simpl; lia.
Qed.
Theorem contraction_denominator : 2^40 = 1099511627776.
Proof. reflexivity. Qed.
