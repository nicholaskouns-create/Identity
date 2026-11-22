(* E47KernelCertificate.v

   The 125-dimensional E47 kernel theorem as DIMENSIONS, not traces.

   Builds on (and imports, unchanged) three modules of the Identity repository:
     formal/e47/E47MatrixProjector.v   integer sl2 model, idempotents, traces
     formal/e47/E47OddsContraction.v   scalar odds contraction
     formal/e47/E47OddsLink.v          W-weighted masses on Z^125
   and the generated witness file E47KernelCertificateData.v.

   Closes the gaps those files record as "taken as input":
     (G1) rank = trace for idempotents / multiplicities as eigenspace dimensions
          [E47MatrixProjector.v, E47OddsLink.v]
     (G2) the five K^2 eigenvalues as supplied spectral input
          [optimal/MC88OptimalStep.v]
     (G3) additivity  sum_i mass_i(x) = Dd^2 <x,x>_W   (Python-only before)
          [E47OddsLink.v]
     (G4) the operator-norm rate (15/17)^n, all n, sharp
          [E47MatrixProjector.v]
   How: every eigenspace, and ker K, is given an explicit basis B in reduced form
   (B[P,:] = beta*I on a pivot set P). Injectivity is then the pivot identity;
   spanning is the single matrix identity  beta*E = B*E[P,:]  together with the
   generic lemma E_on_eigen (an eigenvector at level i is sent by E_j to
   delta_ij*Dd*x), proved once for every vector, with no rank or trace argument.

   Coq standard library only. No Axiom, no Admitted. Every Print Assumptions at the
   end must report "Closed under the global context". *)

From Coq Require Import List ZArith Lia Bool QArith.
Import ListNotations.
Require Import E47MatrixProjector E47OddsContraction E47OddsLink E47KernelCertificateData.
Open Scope Z_scope.

Module KernelCertificate.
Import MatrixProjector OddsLink KernelCertificateData.

(* ================= Part 0: vector and matrix algebra (generic) ================= *)
Definition vscale (k : Z) (v : list Z) : list Z := map (Z.mul k) v.
Definition vadd (u v : list Z) : list Z := zipw Z.add u v.

Lemma zipw_len : forall {X Y W : Type} (f : X -> Y -> W) u v,
  length (zipw f u v) = Nat.min (length u) (length v).
Proof. intros. unfold zipw. rewrite map_length, combine_length. reflexivity. Qed.

Lemma vadd_len : forall u v, length u = length v -> length (vadd u v) = length u.
Proof. intros u v H. unfold vadd. rewrite zipw_len, H. apply Nat.min_id. Qed.

Lemma vscale_len : forall k v, length (vscale k v) = length v.
Proof. intros. apply map_length. Qed.

Lemma dot_vscale_r : forall k r x, dot r (vscale k x) = k * dot r x.
Proof. intros k. induction r as [|a r IH]; intros [|b x]; simpl; try ring. rewrite IH. ring. Qed.

Lemma dot_vadd_r : forall r u v, length u = length v -> dot r (vadd u v) = dot r u + dot r v.
Proof.
  induction r as [|a r IH]; intros u v H.
  - reflexivity.
  - destruct u as [|b u], v as [|c v]; simpl in H; try discriminate.
    + reflexivity.
    + unfold vadd. rewrite zipw_cons. simpl. injection H as H.
      fold (vadd u v). rewrite (IH u v H). ring.
Qed.

Lemma dot_zipw_add_l : forall r s x, length r = length s ->
  dot (zipw Z.add r s) x = dot r x + dot s x.
Proof.
  induction r as [|a r IH]; intros s x H.
  - destruct s; [reflexivity | discriminate].
  - destruct s as [|b s]; [discriminate|]. injection H as H.
    rewrite zipw_cons. destruct x as [|c x]; simpl; [ring|]. rewrite (IH s x H). ring.
Qed.

Lemma zipw_map_same : forall {X W : Type} (f : Z -> Z -> W) (g h : X -> Z) l,
  zipw f (map g l) (map h l) = map (fun a => f (g a) (h a)) l.
Proof. intros. induction l as [|a l IH]; [reflexivity|]. simpl. rewrite zipw_cons, IH. reflexivity. Qed.

Lemma mv_vscale : forall A k x, mv A (vscale k x) = vscale k (mv A x).
Proof. intros. unfold mv, vscale. rewrite map_map. apply map_ext. intro r. apply dot_vscale_r. Qed.

Lemma mv_vadd : forall A u v, length u = length v -> mv A (vadd u v) = vadd (mv A u) (mv A v).
Proof.
  intros A u v H. unfold mv at 1. unfold vadd at 2. unfold mv. rewrite zipw_map_same.
  apply map_ext. intro r. apply dot_vadd_r. exact H.
Qed.

Lemma mv_madd_F2 : forall A B x, Forall2 (fun r s => length r = length s) A B ->
  mv (madd A B) x = vadd (mv A x) (mv B x).
Proof.
  intros A B x H. induction H as [|r s A B Hrs HAB IH]; [reflexivity|].
  unfold madd. rewrite zipw_cons. fold (madd A B).
  change (mv ((zipw Z.add r s) :: madd A B) x) with (dot (zipw Z.add r s) x :: mv (madd A B) x).
  rewrite IH. unfold vadd. simpl. rewrite zipw_cons. rewrite dot_zipw_add_l by exact Hrs.
  reflexivity.
Qed.

Lemma F2_of_rows : forall n (A B : list (list Z)), length A = length B ->
  (forall r, In r A -> length r = n) -> (forall s, In s B -> length s = n) ->
  Forall2 (fun r s => length r = length s) A B.
Proof.
  intros n A. induction A as [|r A IH]; intros B HL HA HB.
  - destruct B as [|s B]; [constructor | simpl in HL; discriminate].
  - destruct B as [|s B]; [simpl in HL; discriminate|]. simpl in HL. constructor.
    + rewrite (HA r (or_introl eq_refl)), (HB s (or_introl eq_refl)). reflexivity.
    + apply IH; [lia | intros; apply HA; right; assumption | intros; apply HB; right; assumption].
Qed.

Lemma Wf_F2 : forall n A B, Wf n A -> Wf n B -> Forall2 (fun r s => length r = length s) A B.
Proof.
  intros n A B [HA1 HA2] [HB1 HB2]. apply (F2_of_rows n); [lia | exact HA2 | exact HB2].
Qed.

Lemma mv_madd : forall n A B x, Wf n A -> Wf n B -> mv (madd A B) x = vadd (mv A x) (mv B x).
Proof. intros. apply mv_madd_F2. eapply Wf_F2; eassumption. Qed.

Lemma Wf_mscale : forall n k A, Wf n A -> Wf n (mscale k A).
Proof.
  intros n k A [H1 H2]. unfold mscale. split; [rewrite map_length; exact H1|].
  intros r Hr. apply in_map_iff in Hr as [r0 [<- Hr0]]. rewrite map_length. apply H2, Hr0.
Qed.

Lemma Wf_madd : forall n A B, Wf n A -> Wf n B -> Wf n (madd A B).
Proof.
  intros n A B HA HB. pose proof (Wf_F2 n A B HA HB) as HF.
  destruct HA as [HA1 HA2]. destruct HB as [HB1 HB2]. unfold madd.
  split.
  - rewrite zipw_len, HA1, HB1. apply Nat.min_id.
  - clear HA1 HB1. induction HF as [|r s A B Hrs HAB IH]; intros t Ht; [contradiction|].
    rewrite zipw_cons in Ht. destruct Ht as [<- | Ht].
    + rewrite zipw_len, Hrs, (HB2 s (or_introl eq_refl)). apply Nat.min_id.
    + apply IH; [intros; apply HA2; right; assumption | intros; apply HB2; right; assumption | exact Ht].
Qed.

Lemma Wf_msub : forall n A B, Wf n A -> Wf n B -> Wf n (msub A B).
Proof. intros. unfold msub. apply Wf_madd; [|apply Wf_mscale]; assumption. Qed.

Lemma Wf_mmul : forall n A B, Wf n A -> Wf n B -> (0 < n)%nat -> Wf n (mmul A B).
Proof.
  intros n A B [HA1 HA2] HB Hn. unfold mmul. rewrite (Wf_hd n B HB Hn).
  split; [rewrite map_length; exact HA1|].
  intros r Hr. apply in_map_iff in Hr as [a [<- Ha]]. rewrite map_length. apply transpose_len.
Qed.

(* generalised associativity for rectangular right factors *)
Lemma mv_mmul_rect : forall A B x k,
  B <> [] -> (forall b, In b B -> length b = k) -> length x = k ->
  (forall a, In a A -> length a = length B) ->
  mv (mmul A B) x = mv A (mv B x).
Proof.
  intros A B x k HBne HB Hx HA. unfold mv at 1. unfold mmul.
  assert (Hhd : length (hd [] B) = k).
  { destruct B as [|b B]; [contradiction|]. simpl. apply HB. left. reflexivity. }
  rewrite Hhd. rewrite map_map. unfold mv. apply map_ext_in. intros a Ha.
  symmetry. apply dot_mv_transpose; [exact HB | exact Hx | apply HA, Ha].
Qed.

(* identity *)
Lemma dot_unit : forall x s i,
  dot (map (fun j => if Nat.eqb i j then 1 else 0) (seq s (length x))) x =
  if andb (Nat.leb s i) (Nat.ltb i (s + length x)) then nth (i - s) x 0 else 0.
Proof.
  induction x as [|b x IH]; intros s i.
  - simpl. destruct (Nat.leb s i) eqn:E1, (Nat.ltb i (s + 0)) eqn:E2; simpl; try reflexivity.
    apply Nat.leb_le in E1. apply Nat.ltb_lt in E2. lia.
  - change (seq s (length (b :: x))) with (s :: seq (S s) (length x)).
    change (map (fun j => if Nat.eqb i j then 1 else 0) (s :: seq (S s) (length x)))
      with ((if Nat.eqb i s then 1 else 0) :: map (fun j => if Nat.eqb i j then 1 else 0) (seq (S s) (length x))).
    change (dot ((if Nat.eqb i s then 1 else 0) :: map (fun j => if Nat.eqb i j then 1 else 0) (seq (S s) (length x))) (b :: x))
      with ((if Nat.eqb i s then 1 else 0) * b + dot (map (fun j => if Nat.eqb i j then 1 else 0) (seq (S s) (length x))) x).
    rewrite IH. simpl length.
    destruct (Nat.eqb_spec i s) as [->|Hne].
    + replace (Nat.leb (S s) s) with false by (symmetry; apply Nat.leb_gt; lia).
      replace (Nat.leb s s) with true by (symmetry; apply Nat.leb_le; lia).
      replace (Nat.ltb s (s + S (length x))) with true by (symmetry; apply Nat.ltb_lt; lia).
      rewrite Nat.sub_diag. cbv [andb nth]. ring.
    + destruct (Nat.leb_spec (S s) i) as [H1|H1].
      * replace (Nat.leb s i) with true by (symmetry; apply Nat.leb_le; lia).
        replace (Nat.ltb i (S s + length x)) with (Nat.ltb i (s + S (length x)))
          by (f_equal; lia).
        simpl andb. destruct (Nat.ltb i (s + S (length x))); [|ring].
        replace (i - s)%nat with (S (i - S s)) by lia. cbv [andb nth]. ring.
      * replace (Nat.leb s i) with false by (symmetry; apply Nat.leb_gt; lia).
        replace (Nat.leb (S s) i) with false by (symmetry; apply Nat.leb_gt; lia).
        cbv [andb]. ring.
Qed.

Lemma map_nth_seq_self : forall (x : list Z), map (fun i => nth i x 0) (seq 0 (length x)) = x.
Proof.
  induction x as [|b x IH]; [reflexivity|].
  simpl. f_equal. rewrite <- seq_shift, map_map. exact IH.
Qed.

Lemma mv_ident : forall n x, length x = n -> mv (ident n) x = x.
Proof.
  intros n x Hx. subst n. unfold ident, mk, mv. rewrite map_map.
  transitivity (map (fun i => nth i x 0) (seq 0 (length x))); [|apply map_nth_seq_self].
  apply map_ext_in. intros i Hi.
  apply in_seq in Hi. rewrite dot_unit.
  replace (andb (Nat.leb 0 i) (Nat.ltb i (0 + length x))) with true
    by (symmetry; apply andb_true_iff; split; [apply Nat.leb_le | apply Nat.ltb_lt]; lia).
  rewrite Nat.sub_0_r. reflexivity.
Qed.

(* ======== eigen-polynomial lemma ======== *)
Lemma Wf_ident : forall n, Wf n (ident n).
Proof.
  intro n. unfold ident, mk. split; [rewrite map_length, seq_length; reflexivity|].
  intros r Hr. apply in_map_iff in Hr as [i [<- _]]. rewrite map_length, seq_length. reflexivity.
Qed.

Lemma C_Wf : Wf 125 C.
Proof. apply is_square_Wf. vm_compute. reflexivity. Qed.

Lemma Wf_factor : forall r, Wf 125 (msub C (mscale r (ident 125))).
Proof. intro r. apply Wf_msub; [apply C_Wf | apply Wf_mscale, Wf_ident]. Qed.

Definition pfac (c : Z) (roots : list Z) (acc : Z) : Z :=
  fold_left (fun a r => a * (c - r)) roots acc.

Lemma pfac_acc : forall c roots acc, pfac c roots acc = acc * pfac c roots 1.
Proof.
  intros c roots. induction roots as [|r rs IH]; intros acc.
  - unfold pfac. simpl. ring.
  - change (pfac c (r :: rs) acc) with (pfac c rs (acc * (c - r))).
    change (pfac c (r :: rs) 1) with (pfac c rs (1 * (c - r))).
    rewrite (IH (acc * (c - r))), (IH (1 * (c - r))). ring.
Qed.

Lemma pfac_cons : forall c r rs, pfac c (r :: rs) 1 = (c - r) * pfac c rs 1.
Proof.
  intros c r rs. change (pfac c (r :: rs) 1) with (pfac c rs (1 * (c - r))).
  rewrite pfac_acc. ring.
Qed.

Lemma vscale_vscale : forall a b v, vscale a (vscale b v) = vscale (a * b) v.
Proof. intros. unfold vscale. rewrite map_map. apply map_ext. intro. ring. Qed.

Lemma vscale_1 : forall v, vscale 1 v = v.
Proof. intro v. unfold vscale. rewrite <- (map_id v) at 2. apply map_ext. intro. ring. Qed.

Lemma vadd_vscale : forall a b v, vadd (vscale a v) (vscale b v) = vscale (a + b) v.
Proof.
  intros a b v. unfold vadd, vscale. rewrite zipw_map_same. apply map_ext. intro. ring.
Qed.

Lemma mv_msub : forall A B x, Wf 125 A -> Wf 125 B ->
  mv (msub A B) x = vadd (mv A x) (vscale (-1) (mv B x)).
Proof.
  intros A B x HA HB. unfold msub. rewrite (mv_madd 125) by (try apply Wf_mscale; assumption).
  rewrite mv_mscale. reflexivity.
Qed.

Lemma factor_on_eigen : forall c r x, length x = 125%nat -> mv C x = vscale c x ->
  mv (msub C (mscale r (ident 125))) x = vscale (c - r) x.
Proof.
  intros c r x Hx Hc.
  rewrite mv_msub by (try apply C_Wf; apply Wf_mscale, Wf_ident).
  rewrite mv_mscale, (mv_ident 125 x Hx), Hc.
  fold (vscale r x). rewrite vscale_vscale, vadd_vscale. f_equal; try ring.
Qed.

Lemma eigen_poly : forall c x, length x = 125%nat -> mv C x = vscale c x ->
  forall roots R0, Wf 125 R0 ->
  mv (fold_left (fun R r => mmul R (msub C (mscale r (ident 125)))) roots R0) x
  = vscale (pfac c roots 1) (mv R0 x).
Proof.
  intros c x Hx Hc roots. induction roots as [|r rs IH]; intros R0 HR0.
  - change (fold_left (fun R r0 => mmul R (msub C (mscale r0 (ident 125)))) [] R0) with R0.
    change (pfac c [] 1) with 1. symmetry. apply vscale_1.
  - change (fold_left (fun R r0 => mmul R (msub C (mscale r0 (ident 125)))) (r :: rs) R0)
      with (fold_left (fun R r0 => mmul R (msub C (mscale r0 (ident 125)))) rs
                      (mmul R0 (msub C (mscale r (ident 125))))).
    rewrite IH by (apply Wf_mmul; [exact HR0 | apply Wf_factor | lia]).
    rewrite (mv_mmul125 R0 _ x HR0 (Wf_factor r) Hx), (factor_on_eigen c r x Hx Hc).
    rewrite mv_vscale, vscale_vscale, pfac_cons. f_equal; try ring.
Qed.

(* ======== E_j on an eigenvector ======== *)
Lemma nth_map_seq : forall {X : Type} (f : nat -> X) (d : X) j n, (j < n)%nat ->
  nth j (map f (seq 0 n)) d = f j.
Proof.
  intros X f d j n Hj. rewrite (nth_indep _ d (f 0%nat)) by (rewrite map_length, seq_length; exact Hj).
  rewrite map_nth, seq_nth by exact Hj. reflexivity.
Qed.

Lemma E_formula : forall j, (j < 7)%nat ->
  E j = mscale (Dd / dcoef j) (mpow_poly C (others j) 125).
Proof.
  intros j Hj. unfold E. rewrite Elist_def.
  rewrite (nth_map_seq (fun i => mscale (Dd / dcoef i) (nth i Nlist [])) [] j 7 Hj).
  rewrite Nlist_def, (nth_map_seq Nmat [] j 7 Hj). reflexivity.
Qed.

Lemma scalar_table : forall i j, (i < 7)%nat -> (j < 7)%nat ->
  Dd / dcoef j * pfac (node i) (others j) 1 = if Nat.eqb i j then Dd else 0.
Proof.
  intros i j Hi Hj.
  assert (H : forallb (fun p => Z.eqb (Dd / dcoef (snd p) * pfac (node (fst p)) (others (snd p)) 1)
                                      (if Nat.eqb (fst p) (snd p) then Dd else 0)) allpairs = true)
    by (vm_compute; reflexivity).
  rewrite forallb_forall in H.
  assert (Hp : In (i, j) allpairs).
  { unfold allpairs, lev. apply in_flat_map. exists i. split; [apply in_seq; lia|].
    apply in_map_iff. exists j. split; [reflexivity | apply in_seq; lia]. }
  apply Z.eqb_eq. exact (H _ Hp).
Qed.

Theorem E_on_eigen : forall i j x, (i < 7)%nat -> (j < 7)%nat -> length x = 125%nat ->
  mv C x = vscale (node i) x ->
  mv (E j) x = vscale (if Nat.eqb i j then Dd else 0) x.
Proof.
  intros i j x Hi Hj Hx Hc. rewrite (E_formula j Hj), mv_mscale. unfold mpow_poly.
  rewrite (eigen_poly (node i) x Hx Hc (others j) (ident 125) (Wf_ident 125)).
  rewrite (mv_ident 125 x Hx). fold (vscale (Dd / dcoef j) (vscale (pfac (node i) (others j) 1) x)).
  rewrite vscale_vscale, scalar_table by assumption. reflexivity.
Qed.

(* ---------- further generic facts ---------- *)
Lemma map_const : forall {X Y : Type} (a : Y) (l : list X), map (fun _ => a) l = repeat a (length l).
Proof. intros. induction l as [|b l IH]; [reflexivity|]. simpl. rewrite IH. reflexivity. Qed.

Lemma dot_repeat0_r : forall r n, dot r (repeat 0 n) = 0.
Proof. induction r as [|a r IH]; intros [|n]; simpl; try reflexivity. rewrite IH. ring. Qed.

Lemma dot_repeat0_l : forall n y, dot (repeat 0 n) y = 0.
Proof. induction n as [|n IH]; intros [|b y]; simpl; try reflexivity. rewrite IH. ring. Qed.

Lemma mv_repeat0 : forall A n, mv A (repeat 0 n) = repeat 0 (length A).
Proof.
  intros A n. unfold mv. rewrite <- (map_const 0 A). apply map_ext. intro. apply dot_repeat0_r.
Qed.

Definition zmat (m k : nat) : Mat := repeat (repeat 0 k) m.

Lemma mv_zmat : forall m k y, mv (zmat m k) y = repeat 0 m.
Proof.
  intros m k y. unfold mv, zmat. rewrite map_repeat, dot_repeat0_l. reflexivity.
Qed.

Lemma vscale_repeat0 : forall k n, vscale k (repeat 0 n) = repeat 0 n.
Proof. intros k n. unfold vscale. rewrite map_repeat. f_equal. ring. Qed.

Lemma vscale_zero_inv : forall k v, k <> 0 -> vscale k v = repeat 0 (length v) -> v = repeat 0 (length v).
Proof.
  intros k v Hk. induction v as [|a v IH]; intro H; [reflexivity|].
  simpl in H. injection H as H1 H2. simpl. f_equal.
  - apply Z.mul_eq_0 in H1. destruct H1; [contradiction | assumption].
  - apply IH. exact H2.
Qed.

Lemma vscale_inj : forall k v w, k <> 0 -> length v = length w ->
  vscale k v = vscale k w -> v = w.
Proof.
  intros k v. induction v as [|a v IH]; intros [|b w] Hk Hl H; simpl in *; try discriminate; [reflexivity|].
  injection H as H1 H2. injection Hl as Hl. f_equal.
  - apply Z.mul_cancel_l in H1; assumption.
  - apply IH; assumption.
Qed.

Lemma vadd_repeat0_l : forall v n, length v = n -> vadd (repeat 0 n) v = v.
Proof.
  intros v n <-. induction v as [|a v IH]; [reflexivity|].
  simpl. unfold vadd in *. rewrite zipw_cons, IH. f_equal.
Qed.

Lemma vadd_repeat0_r : forall v n, length v = n -> vadd v (repeat 0 n) = v.
Proof.
  intros v n <-. induction v as [|a v IH]; [reflexivity|].
  simpl. unfold vadd in *. rewrite zipw_cons, IH. f_equal. ring.
Qed.

Lemma vadd_neg_zero : forall u v, length u = length v ->
  vadd u (vscale (-1) v) = repeat 0 (length u) -> u = v.
Proof.
  induction u as [|a u IH]; intros [|b v] Hl H; try (simpl in Hl; discriminate); [reflexivity|].
  injection Hl as Hl.
  change (vadd (a :: u) (vscale (-1) (b :: v))) with ((a + -1 * b) :: vadd u (vscale (-1) v)) in H.
  change (repeat 0 (length (a :: u))) with (0 :: repeat 0 (length u)) in H.
  injection H as H1 H2. f_equal; [destruct b; lia | apply IH; assumption].
Qed.

Lemma vadd_neg_self : forall v, vadd v (vscale (-1) v) = repeat 0 (length v).
Proof.
  induction v as [|a v IH]; [reflexivity|].
  change (vadd (a :: v) (vscale (-1) (a :: v))) with ((a + -1 * a) :: vadd v (vscale (-1) v)).
  change (repeat 0 (length (a :: v))) with (0 :: repeat 0 (length v)).
  rewrite IH. f_equal. ring.
Qed.

Lemma nth_mv : forall B y p, nth p (mv B y) 0 = dot (nth p B []) y.
Proof.
  intros B y p. unfold mv. exact (map_nth (fun r => dot r y) B [] p).
Qed.

Definition rowsel (P : list nat) (M : Mat) : Mat := map (fun p => nth p M []) P.

Lemma mv_rowsel : forall P B y, mv (rowsel P B) y = map (fun p => nth p (mv B y) 0) P.
Proof.
  intros. unfold rowsel, mv at 1. rewrite map_map. apply map_ext. intro p. symmetry. apply nth_mv.
Qed.

Lemma mv_mscale_ident : forall k n y, length y = n -> mv (mscale k (ident n)) y = vscale k y.
Proof. intros k n y Hy. rewrite mv_mscale, (mv_ident n y Hy). reflexivity. Qed.

Lemma mv_len' : forall A x, length (mv A x) = length A.
Proof. intros. unfold mv. apply map_length. Qed.

(* rectangular well-formedness: m rows of length k *)
Definition Wfr (m k : nat) (B : Mat) : Prop := length B = m /\ forall r, In r B -> length r = k.

Lemma Wfr_of_bool : forall m k B,
  Nat.eqb (length B) m && forallb (fun r => Nat.eqb (length r) k) B = true -> Wfr m k B.
Proof.
  intros m k B H. apply andb_true_iff in H as [H1 H2]. split; [apply Nat.eqb_eq; exact H1|].
  intros r Hr. rewrite forallb_forall in H2. apply Nat.eqb_eq, H2, Hr.
Qed.

(* (Fac c) x = 0  <->  C x = c x *)
Definition Fac (c : Z) : Mat := msub C (mscale c I125).

Lemma mv_Fac : forall c x, length x = 125%nat ->
  mv (Fac c) x = vadd (mv C x) (vscale (-1) (vscale c x)).
Proof.
  intros c x Hx. unfold Fac, I125.
  rewrite mv_msub by (try apply C_Wf; apply Wf_mscale, Wf_ident).
  rewrite (mv_mscale_ident c 125 x Hx). reflexivity.
Qed.

Lemma eig_iff : forall c x, length x = 125%nat ->
  (mv (Fac c) x = repeat 0 125 <-> mv C x = vscale c x).
Proof.
  intros c x Hx. rewrite (mv_Fac c x Hx). split; intro H.
  - apply vadd_neg_zero; [rewrite mv_len', vscale_len; destruct C_Wf; congruence|].
    rewrite mv_len'. destruct C_Wf as [HC _]. rewrite HC. exact H.
  - rewrite H, vadd_neg_self, vscale_len. congruence.
Qed.

(* ================= Part 1: the certificate checks (vm_compute) ================= *)

Definition Bl (i : nat) : Mat := nth i [B0;B1;B2;B3;B4;B5;B6] [].
Definition Pl (i : nat) : list nat := nth i [piv0;piv1;piv2;piv3;piv4;piv5;piv6] [].
Definition betal (i : nat) : Z := nth i [beta0;beta1;beta2;beta3;beta4;beta5;beta6] 0.
Definition diml (i : nat) : nat := length (Pl i).

Lemma cert_shape : forallb (fun i => Nat.eqb (length (Bl i)) 125 &&
   forallb (fun r => Nat.eqb (length r) (diml i)) (Bl i)) lev = true.
Proof. vm_compute. reflexivity. Qed.

Lemma cert_dims : map diml lev = [1;9;25;28;27;22;13]%nat.
Proof. vm_compute. reflexivity. Qed.

Lemma cert_betas : forallb (fun i => Z.ltb 0 (betal i)) lev = true.
Proof. vm_compute. reflexivity. Qed.

(* (c1) the columns of B_i are eigenvectors at level i *)
Lemma cert_c1 : forallb (fun i => meqb (mmul (Fac (node i)) (Bl i)) (zmat 125 (diml i))) lev = true.
Proof. vm_compute. reflexivity. Qed.

(* (c2) reduced form: rows P_i of B_i are beta_i * I *)
Lemma cert_c2 : forallb (fun i => meqb (rowsel (Pl i) (Bl i)) (mscale (betal i) (ident (diml i)))) lev = true.
Proof. vm_compute. reflexivity. Qed.

(* (c3) spanning: beta_i * E_i = B_i * E_i[P_i,:] *)
Lemma cert_c3 : forallb (fun i => meqb (mscale (betal i) (E i)) (mmul (Bl i) (rowsel (Pl i) (E i)))) lev = true.
Proof. vm_compute. reflexivity. Qed.

(* C commutes with each E_j and acts on it as node j *)
Lemma cert_EC : forallb (fun j => meqb (mmul (E j) C) (mscale (node j) (E j))) lev = true.
Proof. vm_compute. reflexivity. Qed.

Definition Kc : Mat := Eval vm_compute in K.
Lemma Kc_def : Kc = K. Proof. vm_compute. reflexivity. Qed.
Definition EK : Mat := madd (E 2) (E 5).
Definition kval (j : nat) : Z := (node j - 6) * (node j - 30).

Lemma ker_shape : Nat.eqb (length BK) 125 && forallb (fun r => Nat.eqb (length r) 47) BK = true.
Proof. vm_compute. reflexivity. Qed.
Lemma ker_piv_len : length pivK = 47%nat.
Proof. vm_compute. reflexivity. Qed.
Lemma ker_beta : betaK = 630.
Proof. reflexivity. Qed.
Lemma ker_c1 : meqb (mmul Kc BK) (zmat 125 47) = true.
Proof. vm_compute. reflexivity. Qed.
Lemma ker_c2 : meqb (rowsel pivK BK) (mscale betaK (ident 47)) = true.
Proof. vm_compute. reflexivity. Qed.
Lemma ker_c3 : meqb (mscale betaK EK) (mmul BK (rowsel pivK EK)) = true.
Proof. vm_compute. reflexivity. Qed.
Lemma ker_offlevel : forallb (fun j => meqb (mmul (E j) Kc) (mscale (kval j) (E j))) [0;1;3;4;6]%nat = true.
Proof. vm_compute. reflexivity. Qed.
Lemma kvals : map kval lev = [180; 112; 0; -108; -140; 0; 432].
Proof. vm_compute. reflexivity. Qed.

(* extraction helpers *)
Lemma in_lev : forall i, (i < 7)%nat -> In i lev.
Proof. intros i Hi. unfold lev. apply in_seq. lia. Qed.

Ltac from_forallb H i Hi :=
  rewrite forallb_forall in H; specialize (H i (in_lev i Hi)).

Lemma Bl_Wfr : forall i, (i < 7)%nat -> Wfr 125 (diml i) (Bl i).
Proof. intros i Hi. pose proof cert_shape as H. from_forallb H i Hi. apply Wfr_of_bool, H. Qed.

Lemma betal_pos : forall i, (i < 7)%nat -> 0 < betal i.
Proof. intros i Hi. pose proof cert_betas as H. from_forallb H i Hi. apply Z.ltb_lt, H. Qed.

Lemma diml_pos : forall i, (i < 7)%nat -> (0 < diml i)%nat.
Proof.
  intros i Hi. assert (H : forallb (fun i => Nat.ltb 0 (diml i)) lev = true) by (vm_compute; reflexivity).
  from_forallb H i Hi. apply Nat.ltb_lt, H.
Qed.

Lemma E_rows : forall i, (i < 7)%nat -> forall r, In r (E i) -> length r = 125%nat.
Proof. intros i Hi. destruct (E_square i (in_lev i Hi)) as [_ H]. exact H. Qed.

Lemma Pl_nonempty_rows : forall i, (i < 7)%nat -> rowsel (Pl i) (E i) <> [].
Proof.
  intros i Hi. pose proof (diml_pos i Hi) as H. unfold diml in H. unfold rowsel.
  destruct (Pl i); [simpl in H; lia | discriminate].
Qed.

Lemma rowsel_rows : forall P M k, (forall r, In r M -> length r = k) ->
  (forall p, In p P -> (p < length M)%nat) -> forall r, In r (rowsel P M) -> length r = k.
Proof.
  intros P M k HM HP r Hr. unfold rowsel in Hr. apply in_map_iff in Hr as [p [<- Hp]].
  apply HM, nth_In, HP, Hp.
Qed.

Lemma Pl_bounds : forall i, (i < 7)%nat -> forall p, In p (Pl i) -> (p < 125)%nat.
Proof.
  intros i Hi. assert (H : forallb (fun i => forallb (fun p => Nat.ltb p 125) (Pl i)) lev = true)
    by (vm_compute; reflexivity).
  from_forallb H i Hi. rewrite forallb_forall in H. intros p Hp. apply Nat.ltb_lt, H, Hp.
Qed.

(* ================= Part 2: the seven eigenspaces ================= *)

Lemma Bl_nonempty : forall i, (i < 7)%nat -> Bl i <> [].
Proof. intros i Hi. destruct (Bl_Wfr i Hi) as [H _]. destruct (Bl i); [discriminate | discriminate]. Qed.

Theorem eigenspace_contains_basis : forall i y, (i < 7)%nat -> length y = diml i ->
  mv C (mv (Bl i) y) = vscale (node i) (mv (Bl i) y).
Proof.
  intros i y Hi Hy.
  assert (Hlen : length (mv (Bl i) y) = 125%nat) by (rewrite mv_len'; apply (Bl_Wfr i Hi)).
  apply (eig_iff (node i) _ Hlen).
  pose proof cert_c1 as H. from_forallb H i Hi. apply meqb_eq in H.
  rewrite <- (mv_mmul_rect (Fac (node i)) (Bl i) y (diml i)).
  - rewrite H, mv_zmat. reflexivity.
  - apply Bl_nonempty, Hi.
  - apply (Bl_Wfr i Hi).
  - exact Hy.
  - intros a Ha. destruct (Bl_Wfr i Hi) as [HB _]. rewrite HB.
    destruct (Wf_factor (node i)) as [_ HF]. apply HF. exact Ha.
Qed.

Theorem eigenspace_basis_injective : forall i y, (i < 7)%nat -> length y = diml i ->
  mv (Bl i) y = repeat 0 125 -> y = repeat 0 (diml i).
Proof.
  intros i y Hi Hy H0.
  pose proof cert_c2 as H. from_forallb H i Hi. apply meqb_eq in H.
  assert (E1 : mv (rowsel (Pl i) (Bl i)) y = vscale (betal i) y)
    by (rewrite H; apply (mv_mscale_ident _ (diml i) y Hy)).
  rewrite mv_rowsel, H0 in E1.
  assert (E2 : map (fun p => nth p (repeat 0 125) 0) (Pl i) = repeat 0 (diml i)).
  { unfold diml. rewrite <- map_const. apply map_ext. intro p.
    destruct (Nat.lt_ge_cases p 125); [apply nth_repeat | apply nth_overflow; rewrite repeat_length; assumption]. }
  rewrite E2 in E1. rewrite <- Hy in E1 |- *.
  apply (vscale_zero_inv (betal i)); [pose proof (betal_pos i Hi); lia | symmetry; exact E1].
Qed.

Theorem eigenspace_spanned : forall i x, (i < 7)%nat -> length x = 125%nat ->
  mv C x = vscale (node i) x ->
  exists y, length y = diml i /\ vscale (betal i * Dd) x = mv (Bl i) y.
Proof.
  intros i x Hi Hx Hc.
  exists (mv (rowsel (Pl i) (E i)) x). split.
  - rewrite mv_len'. unfold rowsel, diml. apply map_length.
  - pose proof cert_c3 as H. from_forallb H i Hi. apply meqb_eq in H.
    rewrite <- (mv_mmul_rect (Bl i) (rowsel (Pl i) (E i)) x 125).
    + rewrite <- H, mv_mscale, (E_on_eigen i i x Hi Hi Hx Hc), Nat.eqb_refl.
      fold (vscale (betal i) (vscale Dd x)). symmetry. apply vscale_vscale.
    + apply Pl_nonempty_rows, Hi.
    + apply rowsel_rows; [apply (E_rows i Hi) | intros p Hp;
        destruct (E_square i (in_lev i Hi)) as [HE _]; rewrite HE; apply (Pl_bounds i Hi p Hp)].
    + exact Hx.
    + intros a Ha. destruct (Bl_Wfr i Hi) as [_ HB]. rewrite (HB a Ha).
      unfold rowsel, diml. symmetry. apply map_length.
Qed.

Theorem eigenspace_dimensions : map diml lev = [1;9;25;28;27;22;13]%nat.
Proof. exact cert_dims. Qed.

(* ================= Part 3: the resolution of identity on vectors ================= *)

Lemma Wf_zero125 : Wf 125 zero125.
Proof. unfold zero125. apply Wf_mscale, Wf_ident. Qed.

Lemma Wf_fold_madd : forall Ms, (forall M, In M Ms -> Wf 125 M) -> Wf 125 (fold_right madd zero125 Ms).
Proof.
  induction Ms as [|M Ms IH]; intro H; [apply Wf_zero125|].
  change (fold_right madd zero125 (M :: Ms)) with (madd M (fold_right madd zero125 Ms)).
  apply Wf_madd; [apply H; left; reflexivity | apply IH; intros; apply H; right; assumption].
Qed.

Lemma mv_fold_madd : forall Ms x, (forall M, In M Ms -> Wf 125 M) ->
  mv (fold_right madd zero125 Ms) x = fold_right vadd (mv zero125 x) (map (fun M => mv M x) Ms).
Proof.
  induction Ms as [|M Ms IH]; intros x H; [reflexivity|].
  change (fold_right madd zero125 (M :: Ms)) with (madd M (fold_right madd zero125 Ms)).
  rewrite (mv_madd 125 M (fold_right madd zero125 Ms) x (H M (or_introl eq_refl))
            (Wf_fold_madd Ms (fun M' HM' => H M' (or_intror HM')))).
  rewrite IH by (intros; apply H; right; assumption). reflexivity.
Qed.

Lemma Elist_len : length Elist = 7%nat.
Proof. vm_compute. reflexivity. Qed.

Lemma list7 : forall {X : Type} (l : list X) (d : X), length l = 7%nat ->
  l = [nth 0 l d; nth 1 l d; nth 2 l d; nth 3 l d; nth 4 l d; nth 5 l d; nth 6 l d].
Proof.
  intros X l d H. do 7 (destruct l as [|? l]; [simpl in H; discriminate|]).
  destruct l; [reflexivity | simpl in H; discriminate].
Qed.

Lemma Elist_expand : Elist = [E 0; E 1; E 2; E 3; E 4; E 5; E 6].
Proof. unfold E. apply list7. exact Elist_len. Qed.

Lemma vscale0 : forall x, vscale 0 x = repeat 0 (length x).
Proof. intro x. unfold vscale. rewrite <- map_const. apply map_ext. intro. ring. Qed.

Definition Ex (x : list Z) (i : nat) : list Z := mv (E i) x.

Lemma Ex_len : forall x i, (i < 7)%nat -> length (Ex x i) = 125%nat.
Proof. intros x i Hi. unfold Ex. rewrite mv_len'. apply (E_square i (in_lev i Hi)). Qed.

Theorem resolution_on_vectors : forall x, length x = 125%nat ->
  vscale Dd x = vadd (Ex x 0) (vadd (Ex x 1) (vadd (Ex x 2) (vadd (Ex x 3)
                 (vadd (Ex x 4) (vadd (Ex x 5) (vadd (Ex x 6) (repeat 0 125))))))).
Proof.
  intros x Hx. pose proof E_resolution as H.
  assert (H1 : mv (fold_right madd zero125 Elist) x = mv (mscale Dd I125) x) by (rewrite H; reflexivity).
  rewrite mv_fold_madd in H1 by (intros M HM; rewrite Elist_expand in HM;
    cbv [In] in HM; repeat (destruct HM as [<-|HM]; [apply E_square, in_lev; lia|]); contradiction).
  unfold I125 in H1. rewrite (mv_mscale_ident Dd 125 x Hx) in H1. rewrite <- H1.
  rewrite Elist_expand. unfold zero125, I125. rewrite (mv_mscale_ident 0 125 x Hx), vscale0, Hx.
  reflexivity.
Qed.

(* ================= Part 4: the kernel of K = (C-6)(C-30), dimension 47 ================= *)

Lemma K_Wf : Wf 125 K.
Proof. rewrite <- Kc_def. apply is_square_Wf. vm_compute. reflexivity. Qed.

Lemma BK_Wfr : Wfr 125 47 BK.
Proof. apply Wfr_of_bool. exact ker_shape. Qed.

Lemma offlevel_killed : forall j x, In j [0;1;3;4;6]%nat -> length x = 125%nat ->
  mv K x = repeat 0 125 -> Ex x j = repeat 0 125.
Proof.
  intros j x Hj Hx HK.
  assert (Hj7 : (j < 7)%nat) by (simpl in Hj; lia).
  pose proof ker_offlevel as H. rewrite forallb_forall in H. specialize (H j Hj). apply meqb_eq in H.
  assert (H1 : mv (E j) (mv K x) = vscale (kval j) (Ex x j)).
  { rewrite <- (mv_mmul125 (E j) K x (E_square j (in_lev j Hj7)) K_Wf Hx), <- Kc_def, H.
    apply mv_mscale. }
  rewrite HK, mv_repeat0 in H1.
  destruct (E_square j (in_lev j Hj7)) as [HE _]. rewrite HE in H1.
  rewrite <- (Ex_len x j Hj7). apply (vscale_zero_inv (kval j)).
  - assert (Hk : forallb (fun j => negb (Z.eqb (kval j) 0)) [0;1;3;4;6]%nat = true) by (vm_compute; reflexivity).
    rewrite forallb_forall in Hk. specialize (Hk j Hj). apply negb_true_iff, Z.eqb_neq in Hk. exact Hk.
  - rewrite Ex_len by exact Hj7. symmetry. exact H1.
Qed.

Theorem kernel_contains_basis : forall y, length y = 47%nat -> mv K (mv BK y) = repeat 0 125.
Proof.
  intros y Hy. rewrite <- Kc_def.
  rewrite <- (mv_mmul_rect Kc BK y 47).
  - rewrite (meqb_eq _ _ ker_c1). apply mv_zmat.
  - destruct BK_Wfr as [H _]. destruct BK; [discriminate | discriminate].
  - apply BK_Wfr.
  - exact Hy.
  - intros a Ha. destruct BK_Wfr as [H _]. rewrite H. rewrite Kc_def in Ha.
    destruct K_Wf as [_ HK]. apply HK, Ha.
Qed.

Theorem kernel_basis_injective : forall y, length y = 47%nat ->
  mv BK y = repeat 0 125 -> y = repeat 0 47.
Proof.
  intros y Hy H0. pose proof (meqb_eq _ _ ker_c2) as Hc2.
  assert (E1 : mv (rowsel pivK BK) y = vscale betaK y)
    by (rewrite Hc2; apply (mv_mscale_ident _ 47 y Hy)).
  rewrite mv_rowsel, H0 in E1.
  assert (E2 : map (fun p => nth p (repeat 0 125) 0) pivK = repeat 0 47).
  { rewrite <- ker_piv_len, <- map_const. apply map_ext. intro p.
    destruct (Nat.lt_ge_cases p 125); [apply nth_repeat | apply nth_overflow; rewrite repeat_length; assumption]. }
  rewrite E2 in E1. rewrite <- Hy in E1 |- *.
  apply (vscale_zero_inv betaK); [rewrite ker_beta; lia | symmetry; exact E1].
Qed.

Theorem kernel_spanned : forall x, length x = 125%nat -> mv K x = repeat 0 125 ->
  exists y, length y = 47%nat /\ vscale (betaK * Dd) x = mv BK y.
Proof.
  intros x Hx HK.
  assert (HD : vscale Dd x = mv EK x).
  { rewrite (resolution_on_vectors x Hx).
    rewrite (offlevel_killed 0 x) by (first [exact Hx | exact HK | cbv [In]; tauto]).
    rewrite (offlevel_killed 1 x) by (first [exact Hx | exact HK | cbv [In]; tauto]).
    rewrite (offlevel_killed 3 x) by (first [exact Hx | exact HK | cbv [In]; tauto]).
    rewrite (offlevel_killed 4 x) by (first [exact Hx | exact HK | cbv [In]; tauto]).
    rewrite (offlevel_killed 6 x) by (first [exact Hx | exact HK | cbv [In]; tauto]).
    rewrite (vadd_repeat0_r (repeat 0 125) 125) by apply repeat_length.
    rewrite (vadd_repeat0_r (Ex x 5) 125) by (apply Ex_len; lia).
    rewrite (vadd_repeat0_l (Ex x 5) 125) by (apply Ex_len; lia).
    rewrite (vadd_repeat0_l (Ex x 5) 125) by (apply Ex_len; lia).
    assert (L : length (vadd (Ex x 2) (Ex x 5)) = 125%nat)
      by (rewrite vadd_len; rewrite ?Ex_len; lia).
    rewrite (vadd_repeat0_l _ 125 L), (vadd_repeat0_l _ 125 L).
    unfold EK, Ex. symmetry. apply (mv_madd 125); apply E_square, in_lev; lia. }
  exists (mv (rowsel pivK EK) x). split.
  - rewrite mv_len'. unfold rowsel. rewrite map_length. exact ker_piv_len.
  - pose proof (meqb_eq _ _ ker_c3) as Hc3.
    rewrite <- (mv_mmul_rect BK (rowsel pivK EK) x 125).
    + rewrite <- Hc3, mv_mscale, <- HD. fold (vscale betaK (vscale Dd x)).
      symmetry. apply vscale_vscale.
    + unfold rowsel. destruct pivK eqn:Hp; [pose proof ker_piv_len as L; rewrite Hp in L; discriminate | discriminate].
    + assert (HEK : Wf 125 EK) by (apply Wf_madd; apply E_square, in_lev; lia).
      apply rowsel_rows; [apply HEK |]. intros p Hp. destruct HEK as [HE _]. rewrite HE.
      assert (Hb : forallb (fun p => Nat.ltb p 125) pivK = true) by (vm_compute; reflexivity).
      rewrite forallb_forall in Hb. apply Nat.ltb_lt, Hb, Hp.
    + exact Hx.
    + intros a Ha. destruct BK_Wfr as [_ HB]. rewrite (HB a Ha). unfold rowsel.
      rewrite map_length. symmetry. exact ker_piv_len.
Qed.

(* The headline: ker K is the image of an injective linear map from Q^47, i.e. it has
   an explicit basis of 47 vectors (the columns of BK). Over Q every kernel vector is
   a combination of them (the integer statement with the nonzero scalar betaK*Dd is
   the rational statement with denominators cleared). *)
Theorem kernel_dimension_47 :
  (forall y, length y = 47%nat -> mv K (mv BK y) = repeat 0 125) /\
  (forall y, length y = 47%nat -> mv BK y = repeat 0 125 -> y = repeat 0 47) /\
  (forall x, length x = 125%nat -> mv K x = repeat 0 125 ->
     exists y, length y = 47%nat /\ vscale (betaK * Dd) x = mv BK y).
Proof.
  split; [exact kernel_contains_basis|]. split; [exact kernel_basis_injective | exact kernel_spanned].
Qed.

Theorem omega_c : Qeq (inject_Z (Z.of_nat (length pivK)) / inject_Z 125) (47 # 125)
  /\ Qeq (47 # 125) (376 # 1000).
Proof. rewrite ker_piv_len. split; reflexivity. Qed.

(* ================= Part 5: complete spectral decomposition ================= *)

Lemma cert_CE : forallb (fun j => meqb (mmul C (E j)) (mscale (node j) (E j))) lev = true.
Proof. vm_compute. reflexivity. Qed.

Theorem E_range_eigen : forall i x, (i < 7)%nat -> length x = 125%nat ->
  mv C (Ex x i) = vscale (node i) (Ex x i).
Proof.
  intros i x Hi Hx. pose proof cert_CE as H. from_forallb H i Hi. apply meqb_eq in H.
  unfold Ex. rewrite <- (mv_mmul125 C (E i) x C_Wf (E_square i (in_lev i Hi)) Hx), H.
  apply mv_mscale.
Qed.

(* E_i E_j = delta_ij Dd E_j on every vector *)
Theorem E_orthogonal_on_vectors : forall i j x, (i < 7)%nat -> (j < 7)%nat -> length x = 125%nat ->
  mv (E i) (Ex x j) = vscale (if Nat.eqb j i then Dd else 0) (Ex x j).
Proof.
  intros i j x Hi Hj Hx.
  apply (E_on_eigen j i (Ex x j) Hj Hi (Ex_len x j Hj) (E_range_eigen j x Hj Hx)).
Qed.

Theorem spectral_decomposition : forall x, length x = 125%nat ->
  vscale Dd x = vadd (Ex x 0) (vadd (Ex x 1) (vadd (Ex x 2) (vadd (Ex x 3)
                 (vadd (Ex x 4) (vadd (Ex x 5) (vadd (Ex x 6) (repeat 0 125))))))) /\
  (forall i, (i < 7)%nat -> mv C (Ex x i) = vscale (node i) (Ex x i)).
Proof.
  intros x Hx. split; [exact (resolution_on_vectors x Hx)|].
  intros i Hi. exact (E_range_eigen i x Hi Hx).
Qed.

Lemma vscale_eq_ne : forall a b w, vscale a w = vscale b w -> a <> b -> w = repeat 0 (length w).
Proof.
  intros a b w. induction w as [|c w IH]; intros H Hab; [reflexivity|].
  change (vscale a (c :: w)) with (a * c :: vscale a w) in H.
  change (vscale b (c :: w)) with (b * c :: vscale b w) in H.
  injection H as H1 H2.
  change (repeat 0 (length (c :: w))) with (0 :: repeat 0 (length w)). f_equal.
  - assert (H3 : (a - b) * c = 0) by lia. apply Z.mul_eq_0 in H3 as [H3|H3]; [lia | exact H3].
  - apply IH; assumption.
Qed.

Lemma Dd_nonzero : Dd <> 0.
Proof. unfold Dd. lia. Qed.

(* No rational eigenvalue other than the seven Casimir values:
   if q * (C x) = p * x with x <> 0 and q <> 0, then p/q is one of the nodes. *)
Theorem eigenvalues_complete : forall p q x, q <> 0 -> length x = 125%nat ->
  x <> repeat 0 125 -> vscale q (mv C x) = vscale p x ->
  exists i, (i < 7)%nat /\ p = node i * q.
Proof.
  intros p q x Hq Hx Hnz Heq.
  destruct (existsb (fun i => Z.eqb p (node i * q)) lev) eqn:Hex.
  - apply existsb_exists in Hex as [i [Hi Hb]]. exists i. split.
    + unfold lev in Hi. apply in_seq in Hi. lia.
    + apply Z.eqb_eq, Hb.
  - exfalso. apply Hnz.
    assert (Hall : forall j, (j < 7)%nat -> Ex x j = repeat 0 125).
    { intros j Hj.
      assert (Hne : node j * q <> p).
      { intro Hc. assert (Ht : existsb (fun i => Z.eqb p (node i * q)) lev = true).
        { apply existsb_exists. exists j. split; [apply in_lev, Hj | apply Z.eqb_eq; lia]. }
        congruence. }
      pose proof cert_EC as H. from_forallb H j Hj. apply meqb_eq in H.
      assert (H1 : mv (E j) (vscale q (mv C x)) = vscale (q * node j) (Ex x j)).
      { rewrite mv_vscale, <- (mv_mmul125 (E j) C x (E_square j (in_lev j Hj)) C_Wf Hx), H,
          mv_mscale. change (map (Z.mul (node j)) (mv (E j) x)) with (vscale (node j) (Ex x j)).
        rewrite vscale_vscale. reflexivity. }
      rewrite Heq, mv_vscale in H1. fold (Ex x j) in H1.
      rewrite <- (Ex_len x j Hj). apply (vscale_eq_ne p (q * node j)); [exact H1 | lia]. }
    pose proof (resolution_on_vectors x Hx) as R.
    rewrite (Hall 0%nat), (Hall 1%nat), (Hall 2%nat), (Hall 3%nat), (Hall 4%nat), (Hall 5%nat),
      (Hall 6%nat) in R by lia.
    repeat rewrite (vadd_repeat0_l (repeat 0 125) 125) in R by apply repeat_length.
    rewrite <- Hx. apply (vscale_zero_inv Dd x Dd_nonzero). rewrite Hx. exact R.
Qed.

(* ================= Part 6: additivity of the level masses ================= *)

Lemma wts_len : length wts = 125%nat.
Proof. vm_compute. reflexivity. Qed.

Lemma zipw_mul_vadd : forall ws u1 u2, length u1 = length u2 ->
  zipw Z.mul ws (vadd u1 u2) = zipw Z.add (zipw Z.mul ws u1) (zipw Z.mul ws u2).
Proof.
  induction ws as [|w ws IH]; intros u1 u2 H; [reflexivity|].
  destruct u1 as [|a u1], u2 as [|b u2]; try (simpl in H; discriminate); [reflexivity|].
  injection H as H. unfold vadd. rewrite !zipw_cons. fold (vadd u1 u2). rewrite IH by exact H.
  f_equal. ring.
Qed.

Lemma wbil_vadd_l : forall ws u1 u2 v, length u1 = length u2 ->
  wbil ws (vadd u1 u2) v = wbil ws u1 v + wbil ws u2 v.
Proof.
  intros ws u1 u2 v H. unfold wbil. rewrite zipw_mul_vadd by exact H.
  apply dot_zipw_add_l. rewrite !zipw_len, H. reflexivity.
Qed.

Lemma wbil_vadd_r : forall ws u v1 v2, length v1 = length v2 ->
  wbil ws u (vadd v1 v2) = wbil ws u v1 + wbil ws u v2.
Proof. intros. rewrite !(wbil_sym ws u). apply wbil_vadd_l. assumption. Qed.

Lemma wbil_repeat0_r : forall ws u n, wbil ws u (repeat 0 n) = 0.
Proof. intros. unfold wbil. apply dot_repeat0_r. Qed.

Lemma wbil_repeat0_l : forall ws u n, wbil ws (repeat 0 n) u = 0.
Proof. intros. rewrite wbil_sym. apply wbil_repeat0_r. Qed.

Definition vsum (vs : list (list Z)) : list Z := fold_right vadd (repeat 0 125) vs.

Lemma vsum_len : forall vs, (forall v, In v vs -> length v = 125%nat) -> length (vsum vs) = 125%nat.
Proof.
  induction vs as [|v vs IH]; intro H; [apply repeat_length|].
  change (vsum (v :: vs)) with (vadd v (vsum vs)).
  rewrite vadd_len; [apply H; left; reflexivity|].
  rewrite IH by (intros; apply H; right; assumption). apply H. left. reflexivity.
Qed.

Lemma wbil_vsum_r : forall ws u vs, (forall v, In v vs -> length v = 125%nat) ->
  wbil ws u (vsum vs) = fold_right Z.add 0 (map (wbil ws u) vs).
Proof.
  intros ws u. induction vs as [|v vs IH]; intro H; [apply wbil_repeat0_r|].
  change (vsum (v :: vs)) with (vadd v (vsum vs)).
  rewrite wbil_vadd_r by (rewrite vsum_len by (intros; apply H; right; assumption); apply H; left; reflexivity).
  rewrite IH by (intros; apply H; right; assumption). reflexivity.
Qed.

Lemma gram : forall ws vs, ForallOrdPairs (fun a b => wbil ws a b = 0) vs ->
  (forall v, In v vs -> length v = 125%nat) ->
  wbil ws (vsum vs) (vsum vs) = fold_right Z.add 0 (map (fun v => wbil ws v v) vs).
Proof.
  intros ws vs H. induction H as [|a vs Ha Hvs IH]; intro HL; [apply wbil_repeat0_r|].
  change (vsum (a :: vs)) with (vadd a (vsum vs)).
  assert (La : length a = 125%nat) by (apply HL; left; reflexivity).
  assert (LS : length (vsum vs) = 125%nat) by (apply vsum_len; intros; apply HL; right; assumption).
  rewrite wbil_vadd_l by congruence. rewrite !wbil_vadd_r by congruence.
  assert (Z0 : wbil ws a (vsum vs) = 0).
  { rewrite wbil_vsum_r by (intros; apply HL; right; assumption).
    clear IH Hvs LS. induction Ha as [|b vs Hb Hrest IHa]; [reflexivity|].
    simpl. rewrite Hb, IHa; [reflexivity|]. intros v Hv. apply HL. destruct Hv as [<-|Hv]; [left; reflexivity|].
    right. right. exact Hv. }
  rewrite Z0, (wbil_sym ws (vsum vs) a), Z0.
  rewrite IH by (intros; apply HL; right; assumption). simpl. ring.
Qed.

Theorem mass_additivity : forall x, length x = 125%nat ->
  Dd * Dd * wbil wts x x =
  lvl_mass 0 x + lvl_mass 1 x + lvl_mass 2 x + lvl_mass 3 x + lvl_mass 4 x + lvl_mass 5 x + lvl_mass 6 x.
Proof.
  intros x Hx. rewrite <- (wbil_scale wts Dd x). fold (vscale Dd x).
  rewrite (resolution_on_vectors x Hx).
  change (vadd (Ex x 0) (vadd (Ex x 1) (vadd (Ex x 2) (vadd (Ex x 3)
           (vadd (Ex x 4) (vadd (Ex x 5) (vadd (Ex x 6) (repeat 0 125))))))))
    with (vsum [Ex x 0; Ex x 1; Ex x 2; Ex x 3; Ex x 4; Ex x 5; Ex x 6]).
  rewrite gram.
  - unfold lvl_mass. change (mv (E ?i) x) with (Ex x i). cbn [map fold_right]. ring.
  - repeat constructor; unfold Ex; apply lvl_orthogonal; try (apply in_lev; lia); try lia; exact Hx.
  - intros v Hv. cbv [In] in Hv.
    repeat (destruct Hv as [<-|Hv]; [apply Ex_len; lia|]). contradiction.
Qed.

(* ================= Part 7: the contraction (Gamma^n - P) for every n ================= *)
(* Gamma = Gm / D with D = 99144 and Gm = D*I - K^2 (E47OddsLink); P = EK / Dd, the
   W-orthogonal projector onto ker K. Cleared of denominators,
     vn n x := Dd * Gm^n x  -  D^n * EK x   =   D^n * Dd * (Gamma^n - P) x.
   The theorem  <vn,vn>_W <= 87480^(2n) * Dd^2 * <x,x>_W  is therefore exactly
     ||(Gamma^n - P) x||_W <= (15/17)^n ||x||_W,     since 17 * 87480 = 15 * 99144,
   for every integer (hence, by homogeneity, every rational) vector x, and equality is
   attained for every n at an explicit eigenvector of Casimir 12. *)

Fixpoint npow (a : Z) (n : nat) : Z := match n with O => 1 | S k => a * npow a k end.

Lemma npow_Zpow : forall a n, npow a n = a ^ Z.of_nat n.
Proof.
  intros a n. induction n as [|n IH]; [reflexivity|].
  rewrite Nat2Z.inj_succ, Z.pow_succ_r by lia. simpl. rewrite IH. ring.
Qed.

Definition Dq : Z := OddsContraction.D.
Definition num (c : Z) : Z := OddsContraction.num c.
Definition a_star : Z := 87480.

Lemma rate_identity : 17 * a_star = 15 * Dq.
Proof. reflexivity. Qed.

Lemma E_on_G : forall i y, (i < 7)%nat -> length y = 125%nat ->
  mv (E i) (mv Gm y) = vscale (num (node i)) (mv (E i) y).
Proof.
  intros i y Hi Hy. rewrite <- (mv_mmul125 (E i) Gm y (E_square i (in_lev i Hi)) Gm_square Hy).
  rewrite (G_on_E i (in_lev i Hi)). apply mv_mscale.
Qed.

Lemma E_on_gpow : forall i n x, (i < 7)%nat -> length x = 125%nat ->
  mv (E i) (gpow n x) = vscale (npow (num (node i)) n) (Ex x i).
Proof.
  intros i n x Hi Hx. induction n as [|n IH].
  - symmetry. apply vscale_1.
  - change (gpow (S n) x) with (mv Gm (gpow n x)).
    rewrite (E_on_G i (gpow n x) Hi (gpow_len n x Hx)), IH, vscale_vscale. reflexivity.
Qed.

Definition vn (n : nat) (x : list Z) : list Z :=
  vadd (vscale Dd (gpow n x)) (vscale (- npow Dq n) (mv EK x)).

Lemma mv_EK : forall x, length x = 125%nat -> mv EK x = vadd (Ex x 2) (Ex x 5).
Proof. intros x Hx. unfold EK, Ex. apply (mv_madd 125); apply E_square, in_lev; lia. Qed.

Lemma E_on_EK : forall i x, (i < 7)%nat -> length x = 125%nat ->
  mv (E i) (mv EK x) = vadd (vscale (if Nat.eqb 2 i then Dd else 0) (Ex x 2))
                            (vscale (if Nat.eqb 5 i then Dd else 0) (Ex x 5)).
Proof.
  intros i x Hi Hx. rewrite (mv_EK x Hx), mv_vadd by (rewrite !Ex_len; lia).
  rewrite (E_orthogonal_on_vectors i 2 x Hi), (E_orthogonal_on_vectors i 5 x Hi) by lia.
  reflexivity.
Qed.

Definition inK (i : nat) : bool := Nat.eqb i 2 || Nat.eqb i 5.
Definition coef (i n : nat) : Z := if inK i then 0 else Dd * npow (num (node i)) n.

Lemma num_values : map (fun i => num (node i)) lev = [66744; 86600; 99144; 87480; 79544; 99144; -87480].
Proof. vm_compute. reflexivity. Qed.

Lemma num_node2 : num (node 2) = Dq. Proof. reflexivity. Qed.
Lemma num_node5 : num (node 5) = Dq. Proof. reflexivity. Qed.

Lemma len125_vscale : forall k v, length v = 125%nat -> length (vscale k v) = 125%nat.
Proof. intros. rewrite vscale_len. assumption. Qed.

Lemma inner_simplify : forall i x, (i < 7)%nat -> length x = 125%nat ->
  vadd (vscale (if Nat.eqb 2 i then Dd else 0) (Ex x 2)) (vscale (if Nat.eqb 5 i then Dd else 0) (Ex x 5))
  = if inK i then vscale Dd (Ex x i) else repeat 0 125.
Proof.
  intros i x Hi Hx.
  assert (L2 : length (Ex x 2) = 125%nat) by (apply Ex_len; lia).
  assert (L5 : length (Ex x 5) = 125%nat) by (apply Ex_len; lia).
  destruct i as [|[|[|[|[|[|[|i]]]]]]]; [ | | | | | | | lia]; unfold inK; cbn [Nat.eqb orb];
    rewrite ?vscale0, ?L2, ?L5.
  - apply (vadd_repeat0_l _ 125), repeat_length.
  - apply (vadd_repeat0_l _ 125), repeat_length.
  - apply (vadd_repeat0_r _ 125). rewrite vscale_len. exact L2.
  - apply (vadd_repeat0_l _ 125), repeat_length.
  - apply (vadd_repeat0_l _ 125), repeat_length.
  - apply (vadd_repeat0_l _ 125). rewrite vscale_len. exact L5.
  - apply (vadd_repeat0_l _ 125), repeat_length.
Qed.

Lemma inK_num : forall i, (i < 7)%nat -> inK i = true -> num (node i) = Dq.
Proof.
  intros i Hi H. destruct i as [|[|[|[|[|[|[|i]]]]]]]; try lia; unfold inK in H; cbn [Nat.eqb orb] in H;
    try discriminate; reflexivity.
Qed.

Lemma E_on_vn : forall i n x, (i < 7)%nat -> length x = 125%nat ->
  mv (E i) (vn n x) = vscale (coef i n) (Ex x i).
Proof.
  intros i n x Hi Hx. unfold vn.
  assert (Lg : length (gpow n x) = 125%nat) by (apply gpow_len; exact Hx).
  assert (LK : length (mv EK x) = 125%nat) by (rewrite (mv_EK x Hx), vadd_len; rewrite !Ex_len; lia).
  assert (Li : length (Ex x i) = 125%nat) by (apply Ex_len; lia).
  rewrite mv_vadd by (rewrite !vscale_len; congruence).
  rewrite !mv_vscale, (E_on_gpow i n x Hi Hx), (E_on_EK i x Hi Hx), (inner_simplify i x Hi Hx).
  unfold coef. destruct (inK i) eqn:HK.
  - rewrite !vscale_vscale, vadd_vscale, (inK_num i Hi HK). f_equal. ring.
  - rewrite vscale_repeat0, vscale_vscale. apply (vadd_repeat0_r _ 125). rewrite vscale_len. exact Li.
Qed.

Lemma vn_len : forall n x, length x = 125%nat -> length (vn n x) = 125%nat.
Proof.
  intros n x Hx. unfold vn. rewrite vadd_len; rewrite !vscale_len; [apply gpow_len; exact Hx|].
  rewrite gpow_len by exact Hx. rewrite (mv_EK x Hx), vadd_len; rewrite !Ex_len; lia.
Qed.

Lemma lvl_mass_vn : forall i n x, (i < 7)%nat -> length x = 125%nat ->
  lvl_mass i (vn n x) = coef i n * coef i n * lvl_mass i x.
Proof.
  intros i n x Hi Hx. unfold lvl_mass. rewrite (E_on_vn i n x Hi Hx). apply wbil_scale.
Qed.

Lemma coef_off : forall i n, inK i = false -> coef i n = Dd * npow (num (node i)) n.
Proof. intros i n H. unfold coef. rewrite H. reflexivity. Qed.

(* The exact energy identity: only the five off-kernel levels survive, each scaled by num^(2n). *)
Theorem contraction_identity : forall n x, length x = 125%nat ->
  wbil wts (vn n x) (vn n x) =
    npow (num 0) n * npow (num 0) n * lvl_mass 0 x + npow (num 2) n * npow (num 2) n * lvl_mass 1 x +
    npow (num 12) n * npow (num 12) n * lvl_mass 3 x + npow (num 20) n * npow (num 20) n * lvl_mass 4 x +
    npow (num 42) n * npow (num 42) n * lvl_mass 6 x.
Proof.
  intros n x Hx. pose proof (mass_additivity (vn n x) (vn_len n x Hx)) as H.
  rewrite !lvl_mass_vn in H by (try lia; exact Hx).
  unfold coef, inK in H. cbn [Nat.eqb orb] in H.
  change (node 0) with 0 in H. change (node 1) with 2 in H. change (node 3) with 12 in H.
  change (node 4) with 20 in H. change (node 6) with 42 in H.
  apply (Z.mul_cancel_l _ _ (Dd * Dd)); [unfold Dd; lia|]. rewrite H. ring.
Qed.

Lemma npow_sq_le : forall b a n, Z.abs b <= a -> npow b n * npow b n <= npow a n * npow a n.
Proof.
  intros b a n Hba. induction n as [|n IH]; [simpl; lia|].
  change (npow b (S n)) with (b * npow b n). change (npow a (S n)) with (a * npow a n).
  assert (Hb2 : b * b <= a * a) by nia.
  assert (H0 : 0 <= npow b n * npow b n) by nia.
  replace (b * npow b n * (b * npow b n)) with ((b * b) * (npow b n * npow b n)) by ring.
  replace (a * npow a n * (a * npow a n)) with ((a * a) * (npow a n * npow a n)) by ring.
  apply Z.mul_le_mono_nonneg; nia.
Qed.

(* ||(Gamma^n - P) x||_W <= (15/17)^n ||x||_W, cleared of denominators *)
Theorem contraction_bound : forall n x, length x = 125%nat ->
  wbil wts (vn n x) (vn n x) <= npow a_star n * npow a_star n * (Dd * Dd * wbil wts x x).
Proof.
  intros n x Hx. rewrite (contraction_identity n x Hx), (mass_additivity x Hx).
  pose proof (npow_sq_le (num 0) a_star n ltac:(vm_compute; congruence)) as B0.
  pose proof (npow_sq_le (num 2) a_star n ltac:(vm_compute; congruence)) as B1.
  pose proof (npow_sq_le (num 12) a_star n ltac:(vm_compute; congruence)) as B3.
  pose proof (npow_sq_le (num 20) a_star n ltac:(vm_compute; congruence)) as B4.
  pose proof (npow_sq_le (num 42) a_star n ltac:(vm_compute; congruence)) as B6.
  pose proof (lvl_mass_nonneg 0 x) as M0. pose proof (lvl_mass_nonneg 1 x) as M1.
  pose proof (lvl_mass_nonneg 2 x) as M2. pose proof (lvl_mass_nonneg 3 x) as M3.
  pose proof (lvl_mass_nonneg 4 x) as M4. pose proof (lvl_mass_nonneg 5 x) as M5.
  pose proof (lvl_mass_nonneg 6 x) as M6.
  set (A := npow a_star n * npow a_star n) in *.
  assert (HA : 0 <= A) by (unfold A; nia).
  pose proof (Z.mul_le_mono_nonneg_r _ _ _ M0 B0) as P0.
  pose proof (Z.mul_le_mono_nonneg_r _ _ _ M1 B1) as P1.
  pose proof (Z.mul_le_mono_nonneg_r _ _ _ M3 B3) as P3.
  pose proof (Z.mul_le_mono_nonneg_r _ _ _ M4 B4) as P4.
  pose proof (Z.mul_le_mono_nonneg_r _ _ _ M6 B6) as P6.
  pose proof (Z.mul_nonneg_nonneg _ _ HA M2) as Q2.
  pose proof (Z.mul_nonneg_nonneg _ _ HA M5) as Q5.
  rewrite !Z.mul_add_distr_l. lia.
Qed.

(* Equality for every n at an explicit eigenvector of Casimir 12: the bound is the norm. *)
Definition xstar : list Z := mv (Bl 3) (1 :: repeat 0 27).

Lemma xstar_len : length xstar = 125%nat.
Proof. unfold xstar. rewrite mv_len'. apply (Bl_Wfr 3); lia. Qed.

Lemma xstar_eigen : mv C xstar = vscale 12 xstar.
Proof.
  unfold xstar. change 12 with (node 3). apply eigenspace_contains_basis; [lia|].
  change (diml 3) with 28%nat. reflexivity.
Qed.

Lemma xstar_nonzero : 0 < wbil wts xstar xstar.
Proof. vm_compute. reflexivity. Qed.

Lemma xstar_other_levels : forall i, (i < 7)%nat -> i <> 3%nat -> lvl_mass i xstar = 0.
Proof.
  intros i Hi H3. unfold lvl_mass. pose proof xstar_eigen as Hx3.
  change 12 with (node 3) in Hx3.
  rewrite (E_on_eigen 3 i xstar ltac:(lia) Hi xstar_len Hx3).
  destruct (Nat.eqb_spec 3 i) as [E|_]; [lia|]. rewrite vscale0, xstar_len. apply wbil_repeat0_l.
Qed.

Theorem contraction_sharp : forall n,
  wbil wts (vn n xstar) (vn n xstar) = npow a_star n * npow a_star n * (Dd * Dd * wbil wts xstar xstar).
Proof.
  intro n. rewrite (contraction_identity n xstar xstar_len), (mass_additivity xstar xstar_len).
  rewrite !(xstar_other_levels 0), !(xstar_other_levels 1), !(xstar_other_levels 2),
    !(xstar_other_levels 4), !(xstar_other_levels 5), !(xstar_other_levels 6) by lia.
  change (num 12) with a_star. ring.
Qed.

Theorem operator_norm_rate :
  17 * a_star = 15 * Dq /\
  (forall n x, length x = 125%nat ->
     wbil wts (vn n x) (vn n x) <= npow a_star n * npow a_star n * (Dd * Dd * wbil wts x x)) /\
  (0 < wbil wts xstar xstar /\ forall n,
     wbil wts (vn n xstar) (vn n xstar) = npow a_star n * npow a_star n * (Dd * Dd * wbil wts xstar xstar)).
Proof.
  split; [exact rate_identity|]. split; [exact contraction_bound|].
  split; [exact xstar_nonzero | exact contraction_sharp].
Qed.

(* ================= Part 8: the K^2 spectrum (supplied input in MC88OptimalStep.v) ========= *)

Theorem K_on_eigen : forall i x, (i < 7)%nat -> length x = 125%nat ->
  mv C x = vscale (node i) x -> mv K x = vscale (kval i) x.
Proof.
  intros i x Hi Hx Hc. unfold K, mpow_poly.
  rewrite (eigen_poly (node i) x Hx Hc [6; 30] (ident 125) (Wf_ident 125)), (mv_ident 125 x Hx).
  f_equal. unfold kval. change (pfac (node i) [6; 30] 1) with (1 * (node i - 6) * (node i - 30)). ring.
Qed.

Theorem K2_on_eigen : forall i x, (i < 7)%nat -> length x = 125%nat ->
  mv C x = vscale (node i) x -> mv (mmul K K) x = vscale (kval i * kval i) x.
Proof.
  intros i x Hi Hx Hc. rewrite (mv_mmul125 K K x K_Wf K_Wf Hx), (K_on_eigen i x Hi Hx Hc),
    mv_vscale, (K_on_eigen i x Hi Hx Hc), vscale_vscale. reflexivity.
Qed.

Theorem K2_spectrum :
  map (fun i => kval i * kval i) lev = [32400; 12544; 0; 11664; 19600; 0; 186624] /\
  map diml lev = [1;9;25;28;27;22;13]%nat.
Proof. split; [vm_compute; reflexivity | exact cert_dims]. Qed.

(* The minimax step of MC88, now on the certified spectrum: gamma = 11664 is attained on a
   28-dimensional eigenspace (Casimir 12) and Lambda = 186624 on a 13-dimensional one
   (Casimir 42). For every rational step p/q one endpoint residual is >= 15/17, and
   1/99144 attains 15/17 at both. *)
Theorem optimal_step :
  kval 3 * kval 3 = 11664 /\ kval 6 * kval 6 = 186624 /\ diml 3 = 28%nat /\ diml 6 = 13%nat /\
  (forall p q : Z, 0 < q -> 15 * q <= 17 * (q - 11664 * p) \/ 15 * q <= 17 * (186624 * p - q)) /\
  17 * (Dq - 11664) = 15 * Dq /\ 17 * (186624 - Dq) = 15 * Dq.
Proof.
  repeat split; try reflexivity. intros p q Hq. lia.
Qed.

(* P = EK/Dd is the projector onto ker K: it maps into ker K and is Dd on ker K. *)
Theorem EK_projects_onto_kernel : forall x, length x = 125%nat ->
  mv K (mv EK x) = repeat 0 125 /\ (mv K x = repeat 0 125 -> mv EK x = vscale Dd x).
Proof.
  intros x Hx. split.
  - rewrite (mv_EK x Hx), mv_vadd by (rewrite !Ex_len; lia).
    rewrite (K_on_eigen 2 (Ex x 2)), (K_on_eigen 5 (Ex x 5)) by
      (try lia; try (apply Ex_len; lia); apply E_range_eigen; lia).
    change (kval 2) with 0. change (kval 5) with 0. rewrite !vscale0, !Ex_len by lia.
    apply (vadd_repeat0_l _ 125), repeat_length.
  - intro HK.
    rewrite (resolution_on_vectors x Hx).
    rewrite (offlevel_killed 0 x), (offlevel_killed 1 x), (offlevel_killed 3 x), (offlevel_killed 4 x),
      (offlevel_killed 6 x) by (first [exact Hx | exact HK | cbv [In]; tauto]).
    rewrite (mv_EK x Hx).
    rewrite (vadd_repeat0_r (repeat 0 125) 125), (vadd_repeat0_r (Ex x 5) 125),
      (vadd_repeat0_l (Ex x 5) 125), (vadd_repeat0_l (Ex x 5) 125) by (try apply repeat_length; apply Ex_len; lia).
    assert (L : length (vadd (Ex x 2) (Ex x 5)) = 125%nat) by (rewrite vadd_len; rewrite ?Ex_len; lia).
    rewrite (vadd_repeat0_l _ 125 L), (vadd_repeat0_l _ 125 L). reflexivity.
Qed.

End KernelCertificate.

Print Assumptions KernelCertificate.E_on_eigen.
Print Assumptions KernelCertificate.eigenspace_contains_basis.
Print Assumptions KernelCertificate.eigenspace_basis_injective.
Print Assumptions KernelCertificate.eigenspace_spanned.
Print Assumptions KernelCertificate.eigenspace_dimensions.
Print Assumptions KernelCertificate.kernel_dimension_47.
Print Assumptions KernelCertificate.omega_c.
Print Assumptions KernelCertificate.spectral_decomposition.
Print Assumptions KernelCertificate.eigenvalues_complete.
Print Assumptions KernelCertificate.mass_additivity.
Print Assumptions KernelCertificate.contraction_identity.
Print Assumptions KernelCertificate.operator_norm_rate.
Print Assumptions KernelCertificate.K2_spectrum.
Print Assumptions KernelCertificate.K2_on_eigen.
Print Assumptions KernelCertificate.optimal_step.
Print Assumptions KernelCertificate.EK_projects_onto_kernel.
