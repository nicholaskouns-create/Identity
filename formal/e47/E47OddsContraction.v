(* Odds contraction for the E47 filter Gamma = I - K^2/99144.
   Self-contained: Coq standard library only, no axioms, no Admitted.
   Companion to E47OddsContraction.lean (same statements).

   WHAT IS FORMALIZED HERE
   Model: the diagonal (Hermitian) eigenbasis picture. The Casimir levels are
   c in {0,2,6,12,20,30,42}; the kernel levels of K = (C-6)(C-30) are {6,30};
   Gamma acts on the level-c eigenspace as the scalar g(c) = 1 - K(c)^2/99144,
   K(c) = (c-6)(c-30). Write D = 99144 and num(c) = D - K(c)^2, so g = num/D.
   A "state" is a function giving, per level c, the squared-norm mass m_c >= 0.
   One Gamma step multiplies the mass at level c by g(c)^2 = num(c)^2 / D^2.
   To stay in integers the step is stored UNSCALED: [step m c = num(c)^2 * m c],
   and the true mass after k steps is [iter k step m c] / D^(2k) (one common
   denominator for every level, so ratios of masses are unaffected).
   Define in := m_6 + m_30 and out := m_0 + m_2 + m_12 + m_20 + m_42.
   Proved, in exact integer arithmetic:
   (1) g(6) = g(30) = 1: num(6) = num(30) = D (Gamma is the identity on E47).
   (2) For each off-kernel level c: 289 * num(c)^2 <= 225 * D^2, i.e.
       g(c)^2 <= 225/289 = (15/17)^2. Equality exactly at c = 12 and c = 42
       (17*num(12) = 15*D, 17*num(42) = -15*D, so |g| = 15/17), strict at
       c = 0, 2, 20. Note 289/225 = (17/15)^2.
   (3) One step: in' = in (scaled by D^2) and 289 * out' <= 225 * D^2 * out;
       hence the cross-multiplied odds bound 289 * out' * in <= 225 * out * in'.
       k steps: 289^k * out_k * in_0 <= 225^k * out_0 * in_k, where in_k is
       D^(2k) * in_0 and out_k, in_k are both scaled by the same D^(2k).
       Odds form (odds_identity): for R = out/(in+out) with in > 0 and out >= 0
       (rationals, Q), R/(1-R) == out/in. So the odds after k steps are
       out_k/in_k, and odds_k <= odds_0 * (225/289)^k is exactly the
       cross-multiplied integer statement odds_k_steps (stated and proved in
       that integer form; the division form is not restated).
       Equality case: mass only at c = 12 (or only at c = 42) plus kernel mass
       gives 289 * out' = 225 * D^2 * out.
   (4) Concrete counterexample to the NAIVE bound R_1 <= R_0 * (225/289):
       kernel mass 1 at c = 6, off-kernel mass 100 at c = 12. Then
       289 * out' * (in + out) > 225 * out * (in' + out') in integers, i.e. the
       naive bound on R fails at k = 1, while the odds bound (3) holds.

   WHAT IS NOT FORMALIZED
   - This is a theorem about the diagonal eigenbasis model (Hermitian form,
     Gamma diagonal with the eigenvalues above, masses as squared norms of the
     components in each Casimir eigenspace). The link from the 125x125 integer
     matrix model to that Hermitian form (diagonal rescaling making the model
     orthogonal, spectral decomposition, the identification of squared norms
     with level masses) is NOT formalized here.
   - Masses are nonnegative integers (or rationals after a common scaling).
     States are arbitrary nonnegative level masses; no particular vector in the
     125-dimensional space is constructed. *)

From Coq Require Import List ZArith Lia QArith Qfield.
Import ListNotations.
Open Scope Z_scope.

Module OddsContraction.

Definition K (c : Z) : Z := (c - 6) * (c - 30).
Definition D : Z := 99144.
(* Gamma eigenvalue at Casimir level c is [num c / D]. *)
Definition num (c : Z) : Z := D - K c * K c.

Definition off_levels : list Z := [0; 2; 12; 20; 42].

(* 289/225 = (17/15)^2 *)
Lemma ratio_squares : 289 = 17 * 17 /\ 225 = 15 * 15.
Proof. split; reflexivity. Qed.

(* ---- (1) identity on E47 ---- *)
Lemma num_kernel : num 6 = D /\ num 30 = D.
Proof. split; vm_compute; reflexivity. Qed.

(* Gamma numerators at every level (g(c) = num(c)/D). *)
Lemma num_values :
  num 0 = 66744 /\ num 2 = 86600 /\ num 12 = 87480 /\ num 20 = 79544 /\ num 42 = -87480.
Proof. vm_compute. repeat split; reflexivity. Qed.

(* ---- (2) contraction off the kernel ---- *)
Lemma off_contraction :
  forall c, In c off_levels -> 289 * (num c * num c) <= 225 * (D * D).
Proof.
  intros c H. simpl in H.
  destruct H as [<- | [<- | [<- | [<- | [<- | []]]]]]; vm_compute; discriminate.
Qed.

Lemma off_equality_iff :
  forall c, In c off_levels ->
    (289 * (num c * num c) = 225 * (D * D) <-> c = 12 \/ c = 42).
Proof.
  intros c H. simpl in H.
  destruct H as [<- | [<- | [<- | [<- | [<- | []]]]]]; split; intro H;
    first [ reflexivity | (exfalso; revert H; vm_compute; discriminate)
          | (left; reflexivity) | (right; reflexivity) | (vm_compute in H; discriminate)
          | (destruct H as [H | H]; discriminate H) ].
Qed.

Lemma off_strict :
  forall c, In c off_levels -> c <> 12 -> c <> 42 ->
    289 * (num c * num c) < 225 * (D * D).
Proof.
  intros c H h12 h42. simpl in H.
  destruct H as [<- | [<- | [<- | [<- | [<- | []]]]]];
    first [ (exfalso; contradiction) | (vm_compute; reflexivity) ].
Qed.

Lemma abs_ratio_fifteen_seventeenths :
  17 * num 12 = 15 * D /\ 17 * num 42 = - (15 * D).
Proof. split; vm_compute; reflexivity. Qed.

(* ---- (3) vector level: diagonal eigenbasis model ---- *)
Definition mass := Z -> Z.
Definition Nonneg (m : mass) : Prop := forall c, 0 <= m c.

(* Unscaled Gamma step on squared-norm masses: true mass = this / D^2. *)
Definition step (m : mass) : mass := fun c => num c * num c * m c.

Definition inm (m : mass) : Z := m 6 + m 30.
Definition outm (m : mass) : Z := m 0 + m 2 + m 12 + m 20 + m 42.

Lemma step_nonneg : forall m, Nonneg m -> Nonneg (step m).
Proof.
  intros m H c. unfold step. specialize (H c).
  apply Z.mul_nonneg_nonneg; [ apply Z.square_nonneg | exact H ].
Qed.

Lemma step_in : forall m, inm (step m) = D * D * inm m.
Proof.
  intro m. unfold inm, step.
  destruct num_kernel as [h6 h30]. rewrite h6, h30. ring.
Qed.

Lemma step_out :
  forall m, Nonneg m -> 289 * outm (step m) <= 225 * (D * D) * outm m.
Proof.
  intros m H. unfold outm, step.
  destruct num_values as (n0 & n2 & n12 & n20 & n42).
  rewrite n0, n2, n12, n20, n42.
  pose proof (H 0) as H0. pose proof (H 2) as H2. pose proof (H 12) as H12.
  pose proof (H 20) as H20. pose proof (H 42) as H42.
  unfold D. lia.
Qed.

(* One step, cross-multiplied odds bound: 289 * out' * in <= 225 * out * in'. *)
Theorem odds_one_step :
  forall m, Nonneg m ->
    289 * outm (step m) * inm m <= 225 * outm m * inm (step m).
Proof.
  intros m H.
  pose proof (step_out m H) as h1. rewrite (step_in m).
  assert (Hin : 0 <= inm m) by (unfold inm; pose proof (H 6); pose proof (H 30); lia).
  pose proof (Zmult_le_compat_r _ _ _ h1 Hin) as h2.
  nia.
Qed.

Fixpoint iter (k : nat) (m : mass) : mass :=
  match k with O => m | S k' => step (iter k' m) end.

Lemma iter_nonneg : forall k m, Nonneg m -> Nonneg (iter k m).
Proof. induction k as [|k IH]; intros m H; simpl; [exact H | apply step_nonneg, IH, H]. Qed.

Lemma iter_in : forall k m, inm (iter k m) = (D * D) ^ Z.of_nat k * inm m.
Proof.
  induction k as [|k IH]; intro m.
  - change (iter 0 m) with m. change (Z.of_nat 0) with 0. rewrite Z.pow_0_r. ring.
  - change (iter (S k) m) with (step (iter k m)). rewrite step_in, IH. rewrite Nat2Z.inj_succ, Z.pow_succ_r by lia. ring.
Qed.

(* k steps, unscaled out_k: 289^k * out_k <= 225^k * D^(2k) * out_0. *)
Lemma iter_out :
  forall k m, Nonneg m ->
    289 ^ Z.of_nat k * outm (iter k m) <= 225 ^ Z.of_nat k * (D * D) ^ Z.of_nat k * outm m.
Proof.
  induction k as [|k IH]; intros m H.
  - change (iter 0 m) with m. change (Z.of_nat 0) with 0. rewrite !Z.pow_0_r. lia.
  - change (iter (S k) m) with (step (iter k m)). rewrite Nat2Z.inj_succ, !Z.pow_succ_r by lia.
    pose proof (step_out (iter k m) (iter_nonneg k m H)) as hs.
    pose proof (IH m H) as ih.
    assert (p289 : 0 <= 289 ^ Z.of_nat k) by (apply Z.pow_nonneg; lia).
    assert (p225 : 0 <= 225 * (D * D)) by (unfold D; lia).
    pose proof (Zmult_le_compat_l _ _ _ hs p289) as h1.
    pose proof (Zmult_le_compat_l _ _ _ ih p225) as h2.
    nia.
Qed.

(* k steps, cross-multiplied odds bound:
   289^k * out_k * in_0 <= 225^k * out_0 * in_k,
   with in_k = D^(2k) * in_0 (kernel mass is unchanged up to the common scale). *)
Theorem odds_k_steps :
  forall k m, Nonneg m ->
    289 ^ Z.of_nat k * outm (iter k m) * inm m <= 225 ^ Z.of_nat k * outm m * inm (iter k m).
Proof.
  intros k m H. rewrite iter_in.
  assert (Hin : 0 <= inm m) by (unfold inm; pose proof (H 6); pose proof (H 30); lia).
  pose proof (Zmult_le_compat_r _ _ _ (iter_out k m H) Hin) as h.
  nia.
Qed.

(* R = out/(in+out); the odds R/(1-R) equal out/in (in > 0). *)
Definition Rfrac (o i : Z) : Q := inject_Z o / inject_Z (i + o).

Lemma odds_identity :
  forall o i : Z, 0 < i -> 0 <= o ->
    Qeq (Rfrac o i / (1 - Rfrac o i)) (inject_Z o / inject_Z i).
Proof.
  intros o i Hi Ho. unfold Rfrac.
  rewrite inject_Z_plus.
  assert (Hi' : ~ Qeq (inject_Z i) 0).
  { intro H. apply Zlt_not_le with (n := 0) (m := i); [exact Hi|].
    unfold Qeq in H. simpl in H. lia. }
  assert (Ho' : 0 <= Qnum (inject_Z o)) by (simpl; lia).
  assert (Hs : ~ Qeq (inject_Z i + inject_Z o) 0).
  { intro H. unfold Qeq, Qplus in H. simpl in H. lia. }
  assert (e : Qeq (1 - inject_Z o / (inject_Z i + inject_Z o))
                  (inject_Z i / (inject_Z i + inject_Z o))) by (field; exact Hs).
  rewrite e. field. split; assumption.
Qed.

(* Equality case: mass only at c = 12 (or only at c = 42) plus kernel mass. *)
Theorem equality_case_12 :
  forall m, Nonneg m -> m 0 = 0 -> m 2 = 0 -> m 20 = 0 -> m 42 = 0 ->
    289 * outm (step m) = 225 * (D * D) * outm m.
Proof.
  intros m H h0 h2 h20 h42. unfold outm, step. rewrite h0, h2, h20, h42.
  destruct num_values as (n0 & n2 & n12 & n20 & n42). rewrite n12. unfold D. lia.
Qed.

Theorem equality_case_42 :
  forall m, Nonneg m -> m 0 = 0 -> m 2 = 0 -> m 12 = 0 -> m 20 = 0 ->
    289 * outm (step m) = 225 * (D * D) * outm m.
Proof.
  intros m H h0 h2 h12 h20. unfold outm, step. rewrite h0, h2, h12, h20.
  destruct num_values as (n0 & n2 & n12 & n20 & n42). rewrite n42. unfold D. lia.
Qed.

(* ---- (4) the naive bound on R fails ---- *)
(* kernel mass 1 at c = 6, off-kernel mass 100 at c = 12 *)
Definition m_ex : mass := fun c => if Z.eqb c 6 then 1 else if Z.eqb c 12 then 100 else 0.

Lemma m_ex_nonneg : Nonneg m_ex.
Proof. intro c. unfold m_ex. destruct (Z.eqb c 6); [lia|]. destruct (Z.eqb c 12); lia. Qed.

(* R_1 > R_0 * (225/289), cross-multiplied with positive denominators:
   R_1 = out'/(in'+out'), R_0 = out/(in+out); the claim is
   289 * out' * (in+out) > 225 * out * (in'+out'). *)
Theorem naive_bound_fails :
  inm m_ex = 1 /\ outm m_ex = 100 /\
  225 * outm m_ex * (inm (step m_ex) + outm (step m_ex))
    < 289 * outm (step m_ex) * (inm m_ex + outm m_ex).
Proof. repeat split; vm_compute; reflexivity. Qed.

(* ... while the odds bound holds on the same state. *)
Theorem odds_bound_on_example :
  289 * outm (step m_ex) * inm m_ex <= 225 * outm m_ex * inm (step m_ex).
Proof. apply odds_one_step, m_ex_nonneg. Qed.

End OddsContraction.

Print Assumptions OddsContraction.num_kernel.
Print Assumptions OddsContraction.off_contraction.
Print Assumptions OddsContraction.off_equality_iff.
Print Assumptions OddsContraction.off_strict.
Print Assumptions OddsContraction.abs_ratio_fifteen_seventeenths.
Print Assumptions OddsContraction.odds_one_step.
Print Assumptions OddsContraction.odds_k_steps.
Print Assumptions OddsContraction.odds_identity.
Print Assumptions OddsContraction.equality_case_12.
Print Assumptions OddsContraction.equality_case_42.
Print Assumptions OddsContraction.naive_bound_fails.
Print Assumptions OddsContraction.odds_bound_on_example.
