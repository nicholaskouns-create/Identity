(* NativeResidualCertificate.v

   GENERAL THEOREM (exact half of the native-basis residual construction).

   For ANY square integer matrices K, R, P (size n), integers d, beta <> 0, an integer
   matrix B (n x r) and a pivot list piv (length r) satisfying the four identities
       (Bezout)    R*K + P = d*I
       (basis)     K*B = 0
       (reduced)   B[piv,:] = beta*I_r
       (spanning)  beta*P = B*P[piv,:]
   the kernel of K is exactly the image of the injective map y |-> B y from Q^r:
   dim ker K = r.  No eigenvalues, no rank-trace argument, no floating point.

   The identities arise from any operator A in a native (integer) basis and any
   factorisation M = m1*m2 of an annihilating polynomial into coprime integer
   factors: K = m1(A), and u*m1 + v*m2 = d (Bezout in Q[z], cleared) gives
   R = u(A), P = v(A)*m2(A). So every finite-dimensional operator whose spectrum
   splits into two Galois-closed parts -- rational or not -- has such a certificate.

   Instances checked below by vm_compute:
     E47       the integer sl2 Casimir on V2^(x)3, m1 = (z-6)(z-30):  dim ker = 47
               (an independent second derivation: Bezout, not Lagrange idempotents)
     Cube      the 5x5x5 torus Laplacian (the Professor's Cube carrier),
               m1 = z^2 - 5z + 5, roots (5 -+ sqrt5)/2:                 dim ker = 12
               -- an irrational (golden-ratio) spectral cluster, certified over Z.

   Self-contained: Coq standard library only. No Axiom, no Admitted. *)

From Coq Require Import List ZArith Lia Bool.
Import ListNotations.
Open Scope Z_scope.

Module NativeResidual.

(* ================= matrices with unconditional associativity ================= *)
Definition Mat := list (list Z).

Fixpoint dot (u v : list Z) : Z :=
  match u, v with a :: u', b :: v' => a * b + dot u' v' | _, _ => 0 end.
Definition mv (A : Mat) (x : list Z) : list Z := map (fun r => dot r x) A.
Fixpoint vadd (u v : list Z) : list Z :=
  match u, v with
  | a :: u', b :: v' => (a + b) :: vadd u' v'
  | [], _ => v
  | _, [] => u
  end.
Definition vscale (k : Z) (v : list Z) : list Z := map (Z.mul k) v.
Fixpoint vcomb (r : list Z) (B : Mat) : list Z :=
  match r, B with a :: r', b :: B' => vadd (vscale a b) (vcomb r' B') | _, _ => [] end.
Definition mmul (A B : Mat) : Mat := map (fun r => vcomb r B) A.
Fixpoint madd (A B : Mat) : Mat :=
  match A, B with
  | r :: A', s :: B' => vadd r s :: madd A' B'
  | [], _ => B
  | _, [] => A
  end.
Definition mscale (k : Z) (A : Mat) : Mat := map (vscale k) A.
Definition ident (n : nat) : Mat :=
  map (fun i => map (fun j => if Nat.eqb i j then 1 else 0) (seq 0 n)) (seq 0 n).
Definition zmat (m k : nat) : Mat := repeat (repeat 0 k) m.
Definition rowsel (piv : list nat) (M : Mat) : Mat := map (fun p => nth p M []) piv.

Lemma dot_vadd_l : forall u v x, dot (vadd u v) x = dot u x + dot v x.
Proof.
  induction u as [|a u IH]; intros v x; [reflexivity|].
  destruct v as [|b v]; [simpl; destruct x; simpl; ring|].
  destruct x as [|c x]; [reflexivity|]. simpl. rewrite IH. ring.
Qed.

Lemma dot_vscale_l : forall k u x, dot (vscale k u) x = k * dot u x.
Proof. intros k. induction u as [|a u IH]; intros [|b x]; simpl; try ring. rewrite IH. ring. Qed.

Lemma dot_vcomb : forall r B x, dot (vcomb r B) x = dot r (mv B x).
Proof.
  induction r as [|a r IH]; intros B x; [reflexivity|].
  destruct B as [|b B]; [destruct r; reflexivity|].
  simpl vcomb. rewrite dot_vadd_l, dot_vscale_l, IH. reflexivity.
Qed.

Theorem mv_mmul : forall A B x, mv (mmul A B) x = mv A (mv B x).
Proof.
  intros A B x. unfold mv, mmul. rewrite map_map. apply map_ext. intro r. apply dot_vcomb.
Qed.

Lemma mv_madd : forall A B x, mv (madd A B) x = vadd (mv A x) (mv B x).
Proof.
  induction A as [|r A IH]; intros B x; [reflexivity|].
  destruct B as [|s B]; [reflexivity|].
  simpl. f_equal; [apply dot_vadd_l | apply IH].
Qed.

Lemma dot_vscale_r : forall k r x, dot r (vscale k x) = k * dot r x.
Proof. intros k. induction r as [|a r IH]; intros [|b x]; simpl; try ring. rewrite IH. ring. Qed.

Lemma mv_mscale : forall k A x, mv (mscale k A) x = vscale k (mv A x).
Proof.
  intros. unfold mv, mscale, vscale. rewrite !map_map. apply map_ext. intro r. apply dot_vscale_l.
Qed.

Lemma dot_unit : forall x s i,
  dot (map (fun j => if Nat.eqb i j then 1 else 0) (seq s (length x))) x =
  if andb (Nat.leb s i) (Nat.ltb i (s + length x)) then nth (i - s) x 0 else 0.
Proof.
  induction x as [|b x IH]; intros s i.
  - simpl. destruct (Nat.leb s i) eqn:E1, (Nat.ltb i (s + 0)) eqn:E2; simpl; try reflexivity.
    apply Nat.leb_le in E1. apply Nat.ltb_lt in E2. lia.
  - change (seq s (length (b :: x))) with (s :: seq (S s) (length x)).
    change (dot (map (fun j => if Nat.eqb i j then 1 else 0) (s :: seq (S s) (length x))) (b :: x))
      with ((if Nat.eqb i s then 1 else 0) * b + dot (map (fun j => if Nat.eqb i j then 1 else 0) (seq (S s) (length x))) x).
    rewrite IH. change (length (b :: x)) with (S (length x)).
    destruct (Nat.eqb_spec i s) as [->|Hne].
    + replace (Nat.leb (S s) s) with false by (symmetry; apply Nat.leb_gt; lia).
      replace (Nat.leb s s) with true by (symmetry; apply Nat.leb_le; lia).
      replace (Nat.ltb s (s + S (length x))) with true by (symmetry; apply Nat.ltb_lt; lia).
      rewrite Nat.sub_diag. cbv [andb nth]. ring.
    + destruct (Nat.leb_spec (S s) i) as [H1|H1].
      * replace (Nat.leb s i) with true by (symmetry; apply Nat.leb_le; lia).
        replace (Nat.ltb i (S s + length x)) with (Nat.ltb i (s + S (length x))) by (f_equal; lia).
        cbv [andb]. destruct (Nat.ltb i (s + S (length x))); [|ring].
        replace (i - s)%nat with (S (i - S s)) by lia. cbv [nth]. ring.
      * replace (Nat.leb s i) with false by (symmetry; apply Nat.leb_gt; lia).
        replace (Nat.leb (S s) i) with false by (symmetry; apply Nat.leb_gt; lia).
        cbv [andb]. ring.
Qed.

Lemma map_nth_seq_self : forall (x : list Z), map (fun i => nth i x 0) (seq 0 (length x)) = x.
Proof. induction x as [|b x IH]; [reflexivity|]. simpl. f_equal. rewrite <- seq_shift, map_map. exact IH. Qed.

Lemma mv_ident : forall n x, length x = n -> mv (ident n) x = x.
Proof.
  intros n x Hx. subst n. unfold ident, mv. rewrite map_map.
  transitivity (map (fun i => nth i x 0) (seq 0 (length x))); [|apply map_nth_seq_self].
  apply map_ext_in. intros i Hi. apply in_seq in Hi. rewrite dot_unit.
  replace (andb (Nat.leb 0 i) (Nat.ltb i (0 + length x))) with true
    by (symmetry; apply andb_true_iff; split; [apply Nat.leb_le | apply Nat.ltb_lt]; lia).
  rewrite Nat.sub_0_r. reflexivity.
Qed.

Lemma map_const : forall {X Y : Type} (a : Y) (l : list X), map (fun _ => a) l = repeat a (length l).
Proof. intros. induction l as [|b l IH]; [reflexivity|]. simpl. rewrite IH. reflexivity. Qed.

Lemma dot_repeat0_r : forall r n, dot r (repeat 0 n) = 0.
Proof. induction r as [|a r IH]; intros [|n]; simpl; try reflexivity. rewrite IH. ring. Qed.

Lemma dot_repeat0_l : forall n y, dot (repeat 0 n) y = 0.
Proof. induction n as [|n IH]; intros [|b y]; simpl; try reflexivity. rewrite IH. ring. Qed.

Lemma mv_repeat0 : forall A n, mv A (repeat 0 n) = repeat 0 (length A).
Proof. intros. unfold mv. rewrite <- (map_const 0 A). apply map_ext. intro. apply dot_repeat0_r. Qed.

Lemma mv_zmat : forall m k y, mv (zmat m k) y = repeat 0 m.
Proof. intros. unfold mv, zmat. rewrite map_repeat, dot_repeat0_l. reflexivity. Qed.

Lemma vadd_repeat0_l : forall v, vadd (repeat 0 (length v)) v = v.
Proof. induction v as [|a v IH]; [reflexivity|]. simpl. rewrite IH. reflexivity. Qed.

Lemma nth_mv : forall B y p, nth p (mv B y) 0 = dot (nth p B []) y.
Proof. intros B y p. unfold mv. exact (map_nth (fun r => dot r y) B [] p). Qed.

Lemma mv_rowsel : forall piv B y, mv (rowsel piv B) y = map (fun p => nth p (mv B y) 0) piv.
Proof. intros. unfold rowsel, mv at 1. rewrite map_map. apply map_ext. intro p. symmetry. apply nth_mv. Qed.

Lemma vscale_zero_inv : forall k v, k <> 0 -> vscale k v = repeat 0 (length v) -> v = repeat 0 (length v).
Proof.
  intros k v Hk. induction v as [|a v IH]; intro H; [reflexivity|].
  simpl in H. injection H as H1 H2. simpl. f_equal.
  - apply Z.mul_eq_0 in H1. destruct H1; [contradiction | assumption].
  - apply IH. exact H2.
Qed.

Lemma vscale_vscale : forall a b v, vscale a (vscale b v) = vscale (a * b) v.
Proof. intros. unfold vscale. rewrite map_map. apply map_ext. intro. ring. Qed.

(* ================= the checker and the general theorem ================= *)
Fixpoint leqb {X : Type} (f : X -> X -> bool) (u v : list X) : bool :=
  match u, v with [], [] => true | a :: u', b :: v' => f a b && leqb f u' v' | _, _ => false end.
Lemma leqb_eq : forall {X : Type} (f : X -> X -> bool) u v,
  (forall a b, f a b = true -> a = b) -> leqb f u v = true -> u = v.
Proof.
  intros X f. induction u as [|a u IH]; intros [|b v] Hf H; simpl in H; try discriminate; try reflexivity.
  apply andb_true_iff in H as [H1 H2]. rewrite (Hf _ _ H1), (IH v Hf H2). reflexivity.
Qed.
Definition meqb (A B : Mat) : bool := leqb (leqb Z.eqb) A B.
Lemma meqb_eq : forall A B, meqb A B = true -> A = B.
Proof.
  intros A B H. apply (leqb_eq (leqb Z.eqb) A B); [|exact H].
  intros a b Hab. apply (leqb_eq Z.eqb); [|exact Hab]. intros. apply Z.eqb_eq. assumption.
Qed.

Definition shape (m k : nat) (M : Mat) : bool :=
  Nat.eqb (length M) m && forallb (fun r => Nat.eqb (length r) k) M.

Definition check (n : nat) (K R P B : Mat) (piv : list nat) (d beta : Z) : bool :=
  shape n n K && shape n n R && shape n n P && shape n (length piv) B &&
  negb (Z.eqb d 0) && negb (Z.eqb beta 0) &&
  meqb (madd (mmul R K) P) (mscale d (ident n)) &&
  meqb (mmul K B) (zmat n (length piv)) &&
  meqb (rowsel piv B) (mscale beta (ident (length piv))) &&
  meqb (mscale beta P) (mmul B (rowsel piv P)).

Theorem native_certificate : forall n K R P B piv d beta,
  check n K R P B piv d beta = true ->
  (forall y, length y = length piv -> mv K (mv B y) = repeat 0 n) /\
  (forall y, length y = length piv -> mv B y = repeat 0 n -> y = repeat 0 (length piv)) /\
  (forall x, length x = n -> mv K x = repeat 0 n ->
     exists y, length y = length piv /\ vscale (beta * d) x = mv B y).
Proof.
  intros n K R P B piv d beta H. unfold check in H.
  repeat rewrite andb_true_iff in H.
  destruct H as [[[[[[[[[HK HR] HP] HB] Hd] Hbeta] H1] H3] H4] H5].
  apply negb_true_iff, Z.eqb_neq in Hd. apply negb_true_iff, Z.eqb_neq in Hbeta.
  apply meqb_eq in H1. apply meqb_eq in H3. apply meqb_eq in H4. apply meqb_eq in H5.
  apply andb_true_iff in HR as [HR _]. apply Nat.eqb_eq in HR.
  apply andb_true_iff in HP as [HP _]. apply Nat.eqb_eq in HP.
  split; [|split].
  - intros y Hy. rewrite <- mv_mmul, H3. apply mv_zmat.
  - intros y Hy H0.
    assert (E1 : mv (rowsel piv B) y = vscale beta y)
      by (rewrite H4, mv_mscale, (mv_ident _ y Hy); reflexivity).
    rewrite mv_rowsel, H0 in E1.
    assert (E2 : map (fun p => nth p (repeat 0 n) 0) piv = repeat 0 (length piv)).
    { rewrite <- map_const. apply map_ext. intro p.
      destruct (Nat.lt_ge_cases p n); [apply nth_repeat | apply nth_overflow; rewrite repeat_length; assumption]. }
    rewrite E2, <- Hy in E1. rewrite <- Hy.
    apply (vscale_zero_inv beta y Hbeta). symmetry. exact E1.
  - intros x Hx HKx.
    assert (HD : vscale d x = mv P x).
    { assert (Hm : mv (madd (mmul R K) P) x = mv (mscale d (ident n)) x) by (rewrite H1; reflexivity).
      rewrite mv_madd, mv_mmul, HKx, mv_repeat0, mv_mscale, (mv_ident n x Hx), HR in Hm.
      rewrite <- Hm, <- HP. replace (length P) with (length (mv P x)) by (unfold mv; apply map_length).
      apply vadd_repeat0_l. }
    exists (mv (rowsel piv P) x). split; [unfold mv, rowsel; rewrite !map_length; reflexivity|].
    rewrite <- mv_mmul, <- H5, mv_mscale, <- HD, vscale_vscale. reflexivity.
Qed.

(* ================= instances ================= *)
Definition kron (A B : Mat) : Mat :=
  flat_map (fun ra => map (fun rb => flat_map (fun a => map (fun b => a * b) rb) ra) B) A.
Definition ksum3 (a : Mat) : Mat :=
  let I5 := ident 5 in madd (madd (kron (kron a I5) I5) (kron (kron I5 a) I5)) (kron (kron I5 I5) a).

(* Horner: [c0;c1;...;ck] |-> c0 I + A (c1 I + A (...)) *)
Definition hpoly (n : nat) (A : Mat) (cs : list Z) : Mat :=
  fold_right (fun c M => madd (mscale c (ident n)) (mmul A M)) (zmat n n) cs.

(* ---------- Instance 1: E47 (integer sl2 model; generators exactly as E47MatrixProjector.v) ---------- *)
Definition Jz5 : Mat := [[2;0;0;0;0];[0;1;0;0;0];[0;0;0;0;0];[0;0;0;-1;0];[0;0;0;0;-2]].
Definition Jp5 : Mat := [[0;4;0;0;0];[0;0;6;0;0];[0;0;0;6;0];[0;0;0;0;4];[0;0;0;0;0]].
Definition Jm5 : Mat := [[0;0;0;0;0];[1;0;0;0;0];[0;1;0;0;0];[0;0;1;0;0];[0;0;0;1;0]].
Definition Jz : Mat := Eval vm_compute in ksum3 Jz5.
Definition Jp : Mat := Eval vm_compute in ksum3 Jp5.
Definition Jm : Mat := Eval vm_compute in ksum3 Jm5.
Definition Cas : Mat := Eval vm_compute in madd (madd (mmul Jz Jz) Jz) (mmul Jm Jp).
Lemma Cas_def : Cas = madd (madd (mmul (ksum3 Jz5) (ksum3 Jz5)) (ksum3 Jz5)) (mmul (ksum3 Jm5) (ksum3 Jp5)).
Proof. vm_compute. reflexivity. Qed.

Definition e47_m1 : list Z := [180;(-36);1].   (* (z-6)(z-30) *)
Definition e47_m2 : list Z := [0;20160;(-13248);1732;(-76);1].   (* z(z-2)(z-12)(z-20)(z-42) *)
Definition e47_u : list Z := [10080;5488;(-1352);71;(-1)].
Definition e47_v : list Z := [(-31);1].
Definition e47_d : Z := 1814400.
Definition e47_beta : Z := 630.
Definition e47_piv : list nat := [5;20;25;30;40;45;50;55;56;60;65;70;75;76;77;80;81;82;85;86;87;90;91;92;95;96;100;101;102;103;104;105;106;107;108;110;111;112;115;116;117;118;119;120;121;122;123]%nat.
Definition e47_B : Mat :=
  [[0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [(-630);0;(-630);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;(-630);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;(-630);0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;630;0;0;2520;0;0;0;(-3780);(-1890);0;0;0;3780;0;630;0;0;0;0;0;0;0;0;0;0;4410;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;(-630);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;(-630);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;(-630);0;0;(-1890);0;0;0;1890;945;0;0;0;(-2520);0;(-315);0;0;0;0;0;0;0;0;0;0;(-2520);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;630;0;0;0;1080;0;(-450);0;(-495);0;0;0;0;0;0;0;0;(-450);0;0;0;180;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;630;0;0;(-630);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;630;0;0;0;0;(-1890);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;630;0;0;1260;0;0;0;(-1050);(-945);0;0;0;1260;0;(-315);0;0;0;0;0;0;0;0;0;0;1260;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;(-630);0;0;0;(-630);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-210);0;(-315);0;0;0;0;0;0;0;0;0;0;(-210);0;0;420;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;630;0;0;0;0;(-1260);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;(-630);0;0;(-630);0;0;0;630;945;0;0;0;(-1260);0;(-315);0;0;0;0;0;0;0;0;0;0;(-1260);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;630;0;0;0;180;0;(-180);0;(-450);0;0;0;0;0;0;0;0;(-180);0;0;0;(-180);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-210);0;(-210);0;0;0;0;0;0;0;0;(-210);0;0;0;210;0;0;(-210);0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-504);0;(-378);0;126;0;0;0;0;0;0;0;0;(-84);0;0;294;0;252;0;0;0;0;0;0;0;0];
   [0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;(-630);0;0;0;(-675);0;(-270);0;900;0;0;0;0;0;0;0;0;360;0;0;0;(-270);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-315);0;(-105);0;315;0;0;0;0;0;0;315;0;0;0;(-105);0;0;(-105);0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-819);0;(-63);0;756;0;0;0;0;630;0;0;0;21;0;0;84;0;(-63);0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-5670);0;3780;0;0;0;0;630;0;0;0;2520;0;0;(-1890);0;630;0;0;0;4410;0;0;0];
   [0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;(-630);0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;(-1260);0;0;0;0;1890;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;(-630);0;0;0;1260;0;0;0;0;(-630);0;(-630);0;0;0;0;0;0;0;0;0;0;(-1260);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;630;0;0;0;0;1260;0;0;0;1755;0;(-180);0;(-1395);0;0;0;0;0;0;0;0;(-180);0;0;0;(-180);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;945;0;0;0;(-1890);(-945);0;0;0;1890;0;0;0;0;0;0;0;0;0;0;0;0;1890;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;(-630);0;0;0;0;(-945);0;0;0;(-810);0;180;0;135;0;0;0;0;0;0;0;0;180;0;0;0;(-450);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;315;0;(-315);0;0;0;0;0;0;0;0;315;0;0;0;(-315);0;0;(-315);0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;1260;0;0;0;0;(-1890);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;(-945);0;0;0;1260;945;0;0;0;(-1890);0;0;0;0;0;0;0;0;0;0;0;0;(-1890);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;630;0;0;0;0;630;0;0;0;990;0;(-360);0;(-585);0;0;0;0;0;0;0;0;(-360);0;0;0;(-360);0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;210;0;(-630);0;0;0;0;0;0;0;0;0;0;(-420);0;0;(-420);0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;441;0;(-63);0;(-504);0;0;0;0;0;0;0;0;(-189);0;0;(-546);0;(-63);0;0;0;0;0;0;0;0];
   [0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;(-630);0;0;0;0;(-315);0;0;0;(-1350);0;90;0;855;0;0;0;0;0;0;0;0;(-540);0;0;0;90;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-210);0;630;0;0;0;0;0;0;(-630);0;0;0;(-210);0;0;(-210);0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;378;0;126;0;(-252);0;0;0;0;(-630);0;0;0;(-252);0;0;(-378);0;(-504);0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;2835;0;(-2520);0;0;0;0;(-630);0;0;0;(-1890);0;0;945;0;(-315);0;0;0;(-2520);0;0;0];
   [0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-315);0;315;0;0;0;0;0;0;0;0;(-315);0;0;0;(-315);0;0;315;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;126;0;252;0;126;0;0;0;0;0;0;0;0;(-504);0;0;(-336);0;252;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;1890;0;(-630);0;0;0;0;0;0;0;0;(-630);0;0;0;0;(-630);0;0;0;(-1260);0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-945);0;0;0;630;0;0];
   [0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;(-630);0;0;0;0;1890;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;(-840);(-630);0;0;0;630;0;630;0;0;0;0;0;0;0;0;0;0;1260;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;(-630);0;0;0;(-180);0;180;0;(-180);0;0;0;0;0;0;0;0;180;0;0;0;180;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;315;0;(-105);0;(-630);0;0;0;0;0;0;315;0;0;0;(-105);0;0;(-105);0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;945;0;0;0;1440;0;(-180);0;(-1080);0;0;0;0;0;0;0;0;(-180);0;0;0;450;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;(-630);0;0;0;0;0;0;0;(-210);0;(-315);0;0;0;0;0;0;0;0;0;0;420;0;0;(-210);0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-126);0;(-252);0;(-126);0;0;0;0;0;0;0;0;504;0;0;(-294);0;(-252);0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;(-945);0;0;0;(-1350);0;90;0;1170;0;0;0;0;0;0;0;0;720;0;0;0;90;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;(-210);0;(-315);0;0;0;0;0;0;630;0;0;0;(-210);0;0;420;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-462);0;(-294);0;168;0;0;0;0;630;0;0;0;(-42);0;0;182;0;(-294);0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-1575);0;1260;0;0;0;0;630;0;0;0;1260;0;0;(-945);0;(-315);0;0;0;1260;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;(-630);0;0;0;0;0;(-630);0;0;0;945;0;0;0;0;0;0;(-630);0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-672);0;(-84);0;588;0;0;0;0;0;0;0;0;(-42);0;0;112;0;546;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-1890);0;1260;0;0;0;0;0;0;0;0;630;0;0;(-630);0;0;0;0;0;1260;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-630);0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-441);0;63;0;504;0;0;0;0;0;0;0;0;(-441);0;0;546;0;63;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-1260);0;630;0;0;0;0;0;0;0;0;0;0;0;(-630);0;630;0;0;0;1260;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-1260);0;0;0;1260;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-945);0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;210;0;210;0;(-630);0;0;0;0;0;0;210;0;0;0;(-210);0;0;210;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;315;0;(-315);0;0;0;0;0;0;0;0;0;0;(-105);0;0;210;0;(-315);0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;(-1260);0;0;0;0;(-630);0;0;0;420;0;0;(-210);0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;945;0;(-1260);0;0;0;0;(-630);0;0;0;(-630);0;0;945;0;(-315);0;0;0;(-1260);0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;1260;0;(-1260);0;0;0;0;0;0;0;0;(-630);0;0;630;0;0;0;0;0;(-1260);0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;(-1260);0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-420);0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-630);0;0;0;1260;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-630);0;0;0;420;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;(-630);0;0;0;(-630)];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;945;0;0;0;(-1260);0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;1260;0;0;0;(-1260);0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;945;0;0;0;(-630);0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630;0];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;630];
   [0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0]].
Definition e47_K : Mat := Eval vm_compute in hpoly 125 Cas e47_m1.
Definition e47_R : Mat := Eval vm_compute in hpoly 125 Cas e47_u.
Definition e47_P : Mat := Eval vm_compute in mmul (hpoly 125 Cas e47_v) (hpoly 125 Cas e47_m2).
Lemma e47_K_def : e47_K = hpoly 125 Cas e47_m1. Proof. vm_compute. reflexivity. Qed.
Lemma e47_minpoly : meqb (mmul e47_K (hpoly 125 Cas e47_m2)) (zmat 125 125) = true.
Proof. vm_compute. reflexivity. Qed.
Lemma e47_check : check 125 e47_K e47_R e47_P e47_B e47_piv e47_d e47_beta = true.
Proof. vm_compute. reflexivity. Qed.
Lemma e47_rank : length e47_piv = 47%nat. Proof. reflexivity. Qed.

Theorem e47_kernel_dimension :
  let K := hpoly 125 Cas e47_m1 in
  (forall y, length y = 47%nat -> mv K (mv e47_B y) = repeat 0 125) /\
  (forall y, length y = 47%nat -> mv e47_B y = repeat 0 125 -> y = repeat 0 47) /\
  (forall x, length x = 125%nat -> mv K x = repeat 0 125 ->
     exists y, length y = 47%nat /\ vscale (e47_beta * e47_d) x = mv e47_B y).
Proof.
  rewrite <- e47_K_def, <- e47_rank.
  exact (native_certificate 125 e47_K e47_R e47_P e47_B e47_piv e47_d e47_beta e47_check).
Qed.


(* ---------- Instance 2: the Professor's Cube -- Laplacian of the 5x5x5 torus C5 x C5 x C5 ----------
   Native basis = the 125 cube positions; L is an integer matrix (6 on the diagonal, -1 to each of
   the six neighbours). Its spectrum lies in Q(sqrt5). Selected cluster: the roots of z^2-5z+5,
   i.e. (5 - sqrt5)/2 = 1 + phi^-2 and (5 + sqrt5)/2 = 1 + phi^2.                              *)
Definition L5 : Mat := [[2;-1;0;0;-1];[-1;2;-1;0;0];[0;-1;2;-1;0];[0;0;-1;2;-1];[-1;0;0;-1;2]].
Definition Lcube : Mat := Eval vm_compute in ksum3 L5.
Lemma Lcube_def : Lcube = ksum3 L5. Proof. vm_compute. reflexivity. Qed.

Definition cube_m1 : list Z := [5;(-5);1].   (* z^2 - 5z + 5 *)
Definition cube_m2 : list Z := [0;(-247500);323250;(-174625);50725;(-8575);845;(-45);1].   (* z(z-5)(z^2-10z+20)(z^2-15z+45)(z^2-15z+55) *)
Definition cube_u : list Z := [2500;(-492500);500000;(-203300);42625;(-4880);290;(-7)].
Definition cube_v : list Z := [(-10);7].
Definition cube_d : Z := 12500.
Definition cube_beta : Z := 1.
Definition cube_piv : list nat := [49;74;99;104;109;114;119;120;121;122;123;124]%nat.
Definition cube_B : Mat :=
  [[(-1);(-1);(-1);0;(-1);(-1);(-1);0;(-1);(-1);(-1);5];
   [(-1);(-1);(-1);0;(-1);(-1);(-1);(-1);0;(-1);(-1);5];
   [(-1);(-1);(-1);0;(-1);(-1);(-1);(-1);(-1);0;(-1);5];
   [(-1);(-1);(-1);0;(-1);(-1);(-1);(-1);(-1);(-1);0;5];
   [(-1);(-1);(-1);0;(-1);(-1);(-1);(-1);(-1);(-1);(-1);6];
   [(-1);(-1);(-1);(-1);0;(-1);(-1);0;(-1);(-1);(-1);5];
   [(-1);(-1);(-1);(-1);0;(-1);(-1);(-1);0;(-1);(-1);5];
   [(-1);(-1);(-1);(-1);0;(-1);(-1);(-1);(-1);0;(-1);5];
   [(-1);(-1);(-1);(-1);0;(-1);(-1);(-1);(-1);(-1);0;5];
   [(-1);(-1);(-1);(-1);0;(-1);(-1);(-1);(-1);(-1);(-1);6];
   [(-1);(-1);(-1);(-1);(-1);0;(-1);0;(-1);(-1);(-1);5];
   [(-1);(-1);(-1);(-1);(-1);0;(-1);(-1);0;(-1);(-1);5];
   [(-1);(-1);(-1);(-1);(-1);0;(-1);(-1);(-1);0;(-1);5];
   [(-1);(-1);(-1);(-1);(-1);0;(-1);(-1);(-1);(-1);0;5];
   [(-1);(-1);(-1);(-1);(-1);0;(-1);(-1);(-1);(-1);(-1);6];
   [(-1);(-1);(-1);(-1);(-1);(-1);0;0;(-1);(-1);(-1);5];
   [(-1);(-1);(-1);(-1);(-1);(-1);0;(-1);0;(-1);(-1);5];
   [(-1);(-1);(-1);(-1);(-1);(-1);0;(-1);(-1);0;(-1);5];
   [(-1);(-1);(-1);(-1);(-1);(-1);0;(-1);(-1);(-1);0;5];
   [(-1);(-1);(-1);(-1);(-1);(-1);0;(-1);(-1);(-1);(-1);6];
   [(-1);(-1);(-1);(-1);(-1);(-1);(-1);0;(-1);(-1);(-1);6];
   [(-1);(-1);(-1);(-1);(-1);(-1);(-1);(-1);0;(-1);(-1);6];
   [(-1);(-1);(-1);(-1);(-1);(-1);(-1);(-1);(-1);0;(-1);6];
   [(-1);(-1);(-1);(-1);(-1);(-1);(-1);(-1);(-1);(-1);0;6];
   [(-1);(-1);(-1);(-1);(-1);(-1);(-1);(-1);(-1);(-1);(-1);7];
   [1;0;0;1;0;0;0;1;0;0;0;(-2)];
   [1;0;0;1;0;0;0;0;1;0;0;(-2)];
   [1;0;0;1;0;0;0;0;0;1;0;(-2)];
   [1;0;0;1;0;0;0;0;0;0;1;(-2)];
   [1;0;0;1;0;0;0;0;0;0;0;(-1)];
   [1;0;0;0;1;0;0;1;0;0;0;(-2)];
   [1;0;0;0;1;0;0;0;1;0;0;(-2)];
   [1;0;0;0;1;0;0;0;0;1;0;(-2)];
   [1;0;0;0;1;0;0;0;0;0;1;(-2)];
   [1;0;0;0;1;0;0;0;0;0;0;(-1)];
   [1;0;0;0;0;1;0;1;0;0;0;(-2)];
   [1;0;0;0;0;1;0;0;1;0;0;(-2)];
   [1;0;0;0;0;1;0;0;0;1;0;(-2)];
   [1;0;0;0;0;1;0;0;0;0;1;(-2)];
   [1;0;0;0;0;1;0;0;0;0;0;(-1)];
   [1;0;0;0;0;0;1;1;0;0;0;(-2)];
   [1;0;0;0;0;0;1;0;1;0;0;(-2)];
   [1;0;0;0;0;0;1;0;0;1;0;(-2)];
   [1;0;0;0;0;0;1;0;0;0;1;(-2)];
   [1;0;0;0;0;0;1;0;0;0;0;(-1)];
   [1;0;0;0;0;0;0;1;0;0;0;(-1)];
   [1;0;0;0;0;0;0;0;1;0;0;(-1)];
   [1;0;0;0;0;0;0;0;0;1;0;(-1)];
   [1;0;0;0;0;0;0;0;0;0;1;(-1)];
   [1;0;0;0;0;0;0;0;0;0;0;0];
   [0;1;0;1;0;0;0;1;0;0;0;(-2)];
   [0;1;0;1;0;0;0;0;1;0;0;(-2)];
   [0;1;0;1;0;0;0;0;0;1;0;(-2)];
   [0;1;0;1;0;0;0;0;0;0;1;(-2)];
   [0;1;0;1;0;0;0;0;0;0;0;(-1)];
   [0;1;0;0;1;0;0;1;0;0;0;(-2)];
   [0;1;0;0;1;0;0;0;1;0;0;(-2)];
   [0;1;0;0;1;0;0;0;0;1;0;(-2)];
   [0;1;0;0;1;0;0;0;0;0;1;(-2)];
   [0;1;0;0;1;0;0;0;0;0;0;(-1)];
   [0;1;0;0;0;1;0;1;0;0;0;(-2)];
   [0;1;0;0;0;1;0;0;1;0;0;(-2)];
   [0;1;0;0;0;1;0;0;0;1;0;(-2)];
   [0;1;0;0;0;1;0;0;0;0;1;(-2)];
   [0;1;0;0;0;1;0;0;0;0;0;(-1)];
   [0;1;0;0;0;0;1;1;0;0;0;(-2)];
   [0;1;0;0;0;0;1;0;1;0;0;(-2)];
   [0;1;0;0;0;0;1;0;0;1;0;(-2)];
   [0;1;0;0;0;0;1;0;0;0;1;(-2)];
   [0;1;0;0;0;0;1;0;0;0;0;(-1)];
   [0;1;0;0;0;0;0;1;0;0;0;(-1)];
   [0;1;0;0;0;0;0;0;1;0;0;(-1)];
   [0;1;0;0;0;0;0;0;0;1;0;(-1)];
   [0;1;0;0;0;0;0;0;0;0;1;(-1)];
   [0;1;0;0;0;0;0;0;0;0;0;0];
   [0;0;1;1;0;0;0;1;0;0;0;(-2)];
   [0;0;1;1;0;0;0;0;1;0;0;(-2)];
   [0;0;1;1;0;0;0;0;0;1;0;(-2)];
   [0;0;1;1;0;0;0;0;0;0;1;(-2)];
   [0;0;1;1;0;0;0;0;0;0;0;(-1)];
   [0;0;1;0;1;0;0;1;0;0;0;(-2)];
   [0;0;1;0;1;0;0;0;1;0;0;(-2)];
   [0;0;1;0;1;0;0;0;0;1;0;(-2)];
   [0;0;1;0;1;0;0;0;0;0;1;(-2)];
   [0;0;1;0;1;0;0;0;0;0;0;(-1)];
   [0;0;1;0;0;1;0;1;0;0;0;(-2)];
   [0;0;1;0;0;1;0;0;1;0;0;(-2)];
   [0;0;1;0;0;1;0;0;0;1;0;(-2)];
   [0;0;1;0;0;1;0;0;0;0;1;(-2)];
   [0;0;1;0;0;1;0;0;0;0;0;(-1)];
   [0;0;1;0;0;0;1;1;0;0;0;(-2)];
   [0;0;1;0;0;0;1;0;1;0;0;(-2)];
   [0;0;1;0;0;0;1;0;0;1;0;(-2)];
   [0;0;1;0;0;0;1;0;0;0;1;(-2)];
   [0;0;1;0;0;0;1;0;0;0;0;(-1)];
   [0;0;1;0;0;0;0;1;0;0;0;(-1)];
   [0;0;1;0;0;0;0;0;1;0;0;(-1)];
   [0;0;1;0;0;0;0;0;0;1;0;(-1)];
   [0;0;1;0;0;0;0;0;0;0;1;(-1)];
   [0;0;1;0;0;0;0;0;0;0;0;0];
   [0;0;0;1;0;0;0;1;0;0;0;(-1)];
   [0;0;0;1;0;0;0;0;1;0;0;(-1)];
   [0;0;0;1;0;0;0;0;0;1;0;(-1)];
   [0;0;0;1;0;0;0;0;0;0;1;(-1)];
   [0;0;0;1;0;0;0;0;0;0;0;0];
   [0;0;0;0;1;0;0;1;0;0;0;(-1)];
   [0;0;0;0;1;0;0;0;1;0;0;(-1)];
   [0;0;0;0;1;0;0;0;0;1;0;(-1)];
   [0;0;0;0;1;0;0;0;0;0;1;(-1)];
   [0;0;0;0;1;0;0;0;0;0;0;0];
   [0;0;0;0;0;1;0;1;0;0;0;(-1)];
   [0;0;0;0;0;1;0;0;1;0;0;(-1)];
   [0;0;0;0;0;1;0;0;0;1;0;(-1)];
   [0;0;0;0;0;1;0;0;0;0;1;(-1)];
   [0;0;0;0;0;1;0;0;0;0;0;0];
   [0;0;0;0;0;0;1;1;0;0;0;(-1)];
   [0;0;0;0;0;0;1;0;1;0;0;(-1)];
   [0;0;0;0;0;0;1;0;0;1;0;(-1)];
   [0;0;0;0;0;0;1;0;0;0;1;(-1)];
   [0;0;0;0;0;0;1;0;0;0;0;0];
   [0;0;0;0;0;0;0;1;0;0;0;0];
   [0;0;0;0;0;0;0;0;1;0;0;0];
   [0;0;0;0;0;0;0;0;0;1;0;0];
   [0;0;0;0;0;0;0;0;0;0;1;0];
   [0;0;0;0;0;0;0;0;0;0;0;1]].
Definition cube_K : Mat := Eval vm_compute in hpoly 125 Lcube cube_m1.
Definition cube_R : Mat := Eval vm_compute in hpoly 125 Lcube cube_u.
Definition cube_P : Mat := Eval vm_compute in mmul (hpoly 125 Lcube cube_v) (hpoly 125 Lcube cube_m2).
Lemma cube_K_def : cube_K = hpoly 125 Lcube cube_m1. Proof. vm_compute. reflexivity. Qed.
Lemma cube_minpoly : meqb (mmul cube_K (hpoly 125 Lcube cube_m2)) (zmat 125 125) = true.
Proof. vm_compute. reflexivity. Qed.
Lemma cube_check : check 125 cube_K cube_R cube_P cube_B cube_piv cube_d cube_beta = true.
Proof. vm_compute. reflexivity. Qed.
Lemma cube_rank : length cube_piv = 12%nat. Proof. reflexivity. Qed.

Theorem cube_golden_cluster_dimension :
  let K := hpoly 125 Lcube cube_m1 in
  (forall y, length y = 12%nat -> mv K (mv cube_B y) = repeat 0 125) /\
  (forall y, length y = 12%nat -> mv cube_B y = repeat 0 125 -> y = repeat 0 12) /\
  (forall x, length x = 125%nat -> mv K x = repeat 0 125 ->
     exists y, length y = 12%nat /\ vscale (cube_beta * cube_d) x = mv cube_B y).
Proof.
  rewrite <- cube_K_def, <- cube_rank.
  exact (native_certificate 125 cube_K cube_R cube_P cube_B cube_piv cube_d cube_beta cube_check).
Qed.

End NativeResidual.

Print Assumptions NativeResidual.mv_mmul.
Print Assumptions NativeResidual.native_certificate.
Print Assumptions NativeResidual.e47_minpoly.
Print Assumptions NativeResidual.e47_kernel_dimension.
Print Assumptions NativeResidual.cube_minpoly.
Print Assumptions NativeResidual.cube_golden_cluster_dimension.
