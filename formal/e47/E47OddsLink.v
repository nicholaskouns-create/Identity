(* Link: the abstract odds contraction (E47OddsContraction.v) holds for EVERY
   integer vector x in Z^125 of the real integer 125x125 sl2 model
   (E47MatrixProjector.v).
   Coq standard library only, no axioms, no Admitted.
   Depends on E47MatrixProjector.v and E47OddsContraction.v (compile both first,
   in the same directory:  coqc -q E47MatrixProjector.v; coqc -q E47OddsContraction.v;
   coqc -q E47OddsLink.v).  There is no Lean companion: the dense 125x125 Lean
   proofs of E47MatrixProjector ran out of memory, so none was attempted here.

   THE IDEA
   The integer Casimir C of E47MatrixProjector.v is not a symmetric matrix, but it
   is self-adjoint for a positive integer diagonal weight W = W1 (x) W1 (x) W1,
   W1 = diag(1, 4, 24, 144, 576), i.e. w_0 = 1, w_{k+1} = (k+1)(4-k) w_k.
   Reason (per factor): <e_{k+1}, Jm e_k>_W = w_{k+1} and
   <Jp e_{k+1}, e_k>_W = (k+1)(4-k) w_k, so Jm and Jp are W-adjoint to each other,
   Jz is diagonal, hence Jm*Jp and C = Jz^2 + Jz + Jm*Jp are W-self-adjoint.
   So every polynomial in C, in particular the spectral idempotents and the filter
   numerator G = D*I - K^2 (D = 99144, K = (C-6)(C-30)), is W-self-adjoint, and
   squared W-norms of level components add up. This is the W-orthogonal (real,
   Hermitian-type) structure the abstract odds lemma needs.

   WHAT IS PROVED HERE
   Part 1 (general list-matrix algebra, no computation): for the list-of-lists
     matrices of E47MatrixProjector, mv (mmul A B) x = mv A (mv B x) and
     <A x, y> = <x, A^T y> (for 125x125 matrices and length-125 vectors).
   Part 2 (vm_compute on the explicit 125x125 integer matrices):
     (a) W has positive integer diagonal = kron(W1,W1,W1); W*Jm = (W*Jp)^T;
         W*C = C^T*W.
     (b) E_i := (Dd/d_i) N_i  (Dd = 12!, N_i the spectral idempotents of
         E47MatrixProjector.v) satisfy E_i*E_i = Dd*E_i and W*E_i = E_i^T*W
         for i = 0..6.
     (c) level mass  mass_i(x) := <E_i x, E_i x>_W  (= Dd^2 times the squared
         W-norm of the true spectral component; all scalings are explicit):
         mass_i(x) >= 0; masses of different levels are W-orthogonal
         (<E_i x, E_j x>_W = 0); and for G = D*I - K^2:
         E_i*G = num(c_i)*E_i, hence mass_i(G x) = num(c_i)^2 * mass_i(x).
     (d) with in(x) = mass_6 + mass_30 (levels 2 and 5) and out(x) = the five
         other levels: in(Gx) = D^2 in(x); the abstract theorems odds_one_step and
         odds_k_steps of E47OddsContraction are INSTANTIATED with
         m := fun c => mass at the level with Casimir c, giving
           289*out(Gx)*in(x) <= 225*out(x)*in(Gx)   and
           289^k*out(G^k x)*in(x) <= 225^k*out(x)*in(G^k x)
         for every x in Z^125, plus the equality cases at Casimir 12 and 42.
     (e) numeric sanity on explicit integer vectors (all ones; and a vector built
         from columns of E_2 and E_3 on which the naive bound on R fails).

   WHAT IS NOT PROVED HERE (taken as standard linear algebra / not formalized)
   - That the W-self-adjoint operator C has real spectrum with the W-orthogonal
     eigenspaces and that "E_i = spectral projector onto the level-i eigenspace" is
     a statement about eigenspaces: here E_i are explicit idempotent matrices with
     E_i E_j = 0 (checked by the W-orthogonality of masses) and sum E_i = Dd*I (from
     E47MatrixProjector.resolution_of_identity); the identification with
     eigenspaces of C (rank = trace for idempotents) is the same input as in
     E47MatrixProjector.v.
   - The identification of this W-weighted real model with the Euclidean
     (Hermitian, complex) model on C^125 is the diagonal similarity W^(1/2), which
     is not formalized. The weighted norm used here is a genuine (positive definite)
     inner product on Z^125 but is not the Euclidean one on the integer
     coordinates; the odds statement is about this weighted norm.
   - Only integer vectors x are treated (rational/real vectors follow by scaling
     but are not stated). The additivity sum_i mass_i(x) = Dd^2 <x,x>_W is checked
     in simulation/e47_tqgnn/odds_link_check.py, not proved in Coq.
   - The k-step bound is the cross-multiplied odds inequality (no division). *)

From Coq Require Import List ZArith Lia Bool.
Import ListNotations.
Require Import E47MatrixProjector.
Require Import E47OddsContraction.
Open Scope Z_scope.
Set Warnings "-deprecated".


Module OddsLink.
Import MatrixProjector.

(* ================= Part 1: list-matrix algebra ================= *)

Definition mv (A : Mat) (x : list Z) : list Z := map (fun r => dot r x) A.

Definition Wf (n : nat) (A : Mat) : Prop :=
  length A = n /\ forall r, In r A -> length r = n.

Lemma is_square_Wf : forall n A, is_square n A = true -> Wf n A.
Proof.
  intros n A H. unfold is_square in H. apply andb_true_iff in H as [H1 H2].
  apply Nat.eqb_eq in H1. split; [exact H1|].
  intros r Hr. rewrite forallb_forall in H2. apply Nat.eqb_eq. apply H2. exact Hr.
Qed.

Lemma dot_comm : forall u v, dot u v = dot v u.
Proof.
  induction u as [|a u IH]; intros [|b v]; simpl; try reflexivity.
  rewrite IH. ring.
Qed.

Lemma dot_nil_r : forall u, dot u [] = 0.
Proof. destruct u; reflexivity. Qed.

Lemma dot_zero_vec : forall x l, dot x (map (Z.mul 0) l) = 0.
Proof.
  induction x as [|a x IH]; intros [|b l]; simpl; try reflexivity.
  rewrite IH. ring.
Qed.

Lemma dot_zero_map : forall (r : list Z) (B : list (list Z)),
  dot r (map (fun _ => 0) B) = 0.
Proof.
  induction r as [|a r IH]; intros [|b B]; simpl; try reflexivity.
  rewrite IH. ring.
Qed.

Lemma dot_map_add : forall (f g : list Z -> Z) (r : list Z) (B : list (list Z)),
  length r = length B ->
  dot r (map (fun b => f b + g b) B) = dot r (map f B) + dot r (map g B).
Proof.
  intros f g. induction r as [|a r IH]; intros [|b B] H; simpl in *;
    try reflexivity; try discriminate.
  injection H as H. rewrite (IH B H). ring.
Qed.

Lemma dot_map_mul : forall (k : Z) (f : list Z -> Z) (r : list Z) (B : list (list Z)),
  dot r (map (fun b => k * f b) B) = k * dot r (map f B).
Proof.
  intros k f. induction r as [|a r IH]; intros [|b B]; simpl; try ring.
  rewrite IH. ring.
Qed.

Lemma dot_scale : forall (k : Z) (r x : list Z), dot (map (Z.mul k) r) x = k * dot r x.
Proof.
  intros k. induction r as [|a r IH]; intros [|b x]; simpl; try ring.
  rewrite IH. ring.
Qed.

Lemma transpose_len : forall n M, length (transpose_n n M) = n.
Proof. induction n as [|k IH]; intro M; simpl; [reflexivity | rewrite IH; reflexivity]. Qed.

Lemma transpose_rows : forall n M r, In r (transpose_n n M) -> length r = length M.
Proof.
  induction n as [|k IH]; intros M r H; simpl in H.
  - contradiction.
  - destruct H as [<- | H].
    + rewrite map_length. reflexivity.
    + rewrite (IH _ _ H). rewrite map_length. reflexivity.
Qed.

Lemma Wf_transpose : forall n A, Wf n A -> Wf n (transpose_n n A).
Proof.
  intros n A [H1 H2]. split; [apply transpose_len|].
  intros r Hr. rewrite (transpose_rows _ _ _ Hr). exact H1.
Qed.

(* The key lemma: r . (B x) = (r^T B) . x, where r^T B is the list of dot products
   of r with the columns of B. *)
Lemma dot_mv_transpose : forall n (B : Mat) x r,
  (forall b, In b B -> length b = n) -> length x = n -> length r = length B ->
  dot r (mv B x) = dot (map (fun c => dot r c) (transpose_n n B)) x.
Proof.
  induction n as [|k IH]; intros B x r HB Hx Hr.
  - destruct x; [|discriminate]. simpl transpose_n. rewrite dot_nil_r.
    assert (E : mv B [] = map (fun _ => 0) B)
      by (unfold mv; apply map_ext; intro b; apply dot_nil_r).
    rewrite E. apply dot_zero_map.
  - destruct x as [|x0 x']; [discriminate|]. injection Hx as Hx.
    assert (E : mv B (x0 :: x') =
                map (fun b => x0 * hd 0 b + dot (tl b) x') B).
    { unfold mv. apply map_ext_in. intros b Hb.
      pose proof (HB b Hb) as Hl. destruct b as [|b0 b']; [discriminate|].
      simpl. ring. }
    assert (HB' : forall b, In b (map (tl (A:=Z)) B) -> length b = k).
    { intros b Hb. apply in_map_iff in Hb as [b0 [<- Hb0]].
      pose proof (HB b0 Hb0) as Hl. destruct b0 as [|c b']; [discriminate|].
      simpl in *. lia. }
    assert (Hr' : length r = length (map (tl (A:=Z)) B)) by (rewrite map_length; exact Hr).
    pose proof (IH (map (tl (A:=Z)) B) x' r HB' Hx Hr') as IH'.
    simpl transpose_n. simpl map. simpl dot.
    rewrite E.
    transitivity (dot r (map (fun b => x0 * hd 0 b) B) + dot r (map (fun b => dot (tl b) x') B)).
    + exact (dot_map_add (fun b => x0 * hd 0 b) (fun b => dot (tl b) x') r B Hr).
    + rewrite (dot_map_mul x0 (hd 0) r B).
      assert (E2 : map (fun b => dot (tl b) x') B = mv (map (tl (A:=Z)) B) x')
        by (unfold mv; rewrite map_map; reflexivity).
      rewrite E2, IH'. ring.
Qed.

Lemma mv_len : forall A x, length (mv A x) = length A.
Proof. intros. unfold mv. apply map_length. Qed.

Lemma Wf_hd : forall n B, Wf n B -> (0 < n)%nat -> length (hd [] B) = n.
Proof.
  intros n B [H1 H2] Hn. destruct B as [|r B].
  - simpl in H1. lia.
  - simpl. apply H2. left. reflexivity.
Qed.

(* mv is multiplicative: (A B) x = A (B x), for 125x125 matrices. *)
Lemma mv_mmul125 : forall A B x,
  Wf 125 A -> Wf 125 B -> length x = 125%nat ->
  mv (mmul A B) x = mv A (mv B x).
Proof.
  intros A B x HA HB Hx. unfold mv at 1. unfold mmul.
  rewrite (Wf_hd 125 B HB) by lia. rewrite map_map.
  unfold mv. apply map_ext_in. intros a Ha.
  destruct HA as [_ HA]. destruct HB as [HBl HBr].
  symmetry. apply dot_mv_transpose.
  - intros b Hb. apply HBr, Hb.
  - exact Hx.
  - rewrite (HA a Ha). symmetry. exact HBl.
Qed.

(* Adjointness against the transpose: <A x, y> = <x, A^T y>. *)
Lemma dot_mv_adjoint : forall A x y,
  Wf 125 A -> length x = 125%nat -> length y = 125%nat ->
  dot (mv A x) y = dot x (mv (transpose_n 125 A) y).
Proof.
  intros A x y [HAl HAr] Hx Hy.
  rewrite dot_comm.
  rewrite (dot_mv_transpose 125 A x y HAr Hx) by (rewrite HAl; exact Hy).
  rewrite dot_comm. f_equal. unfold mv. apply map_ext. intro c. apply dot_comm.
Qed.

(* Weighted bilinear form  <u,v>_W = sum_k w_k u_k v_k. *)
Definition wbil (ws u v : list Z) : Z := dot (zipw Z.mul ws u) v.

Lemma zipw_cons : forall {X Y Z : Type} (f : X -> Y -> Z) a u b v,
  zipw f (a :: u) (b :: v) = f a b :: zipw f u v.
Proof. reflexivity. Qed.
Lemma zipw_nil_l : forall {X Y Z : Type} (f : X -> Y -> Z) v, zipw f [] v = [].
Proof. reflexivity. Qed.
Lemma zipw_nil_r : forall {X Y Z : Type} (f : X -> Y -> Z) u, zipw f u [] = [].
Proof. destruct u; reflexivity. Qed.

Lemma wbil_self_nonneg : forall ws u,
  (forall w, In w ws -> 0 <= w) -> 0 <= wbil ws u u.
Proof.
  unfold wbil. induction ws as [|w ws IH]; intros [|a u] H.
  - rewrite zipw_nil_l. simpl. lia.
  - rewrite zipw_nil_l. simpl. lia.
  - rewrite zipw_nil_r. simpl. lia.
  - rewrite zipw_cons. simpl.
    apply Z.add_nonneg_nonneg.
    + replace (w * a * a) with (w * (a * a)) by ring.
      apply Z.mul_nonneg_nonneg; [apply H; left; reflexivity | apply Z.square_nonneg].
    + apply IH. intros w' Hw'. apply H. right. exact Hw'.
Qed.

Lemma wbil_sym : forall ws u v, wbil ws u v = wbil ws v u.
Proof.
  unfold wbil. induction ws as [|w ws IH]; intros [|a u] [|b v];
    try (rewrite ?zipw_nil_l, ?zipw_nil_r; simpl; reflexivity).
  rewrite !zipw_cons. simpl. rewrite IH. ring.
Qed.

Lemma wbil_scale : forall ws k u,
  wbil ws (map (Z.mul k) u) (map (Z.mul k) u) = k * k * wbil ws u u.
Proof.
  unfold wbil. induction ws as [|w ws IH]; intros k [|a u].
  - rewrite zipw_nil_l. simpl. ring.
  - rewrite zipw_nil_l. simpl. ring.
  - rewrite zipw_nil_r. simpl. ring.
  - simpl map. rewrite !zipw_cons. simpl. rewrite IH. ring.
Qed.

Definition rowscale (ws : list Z) (A : Mat) : Mat :=
  zipw (fun w r => map (Z.mul w) r) ws A.

Lemma mv_rowscale : forall ws A x,
  zipw Z.mul ws (mv A x) = mv (rowscale ws A) x.
Proof.
  induction ws as [|w ws IH]; intros [|r A] x.
  - reflexivity.
  - reflexivity.
  - reflexivity.
  - change (mv (r :: A) x) with (dot r x :: mv A x).
    rewrite zipw_cons. unfold rowscale. rewrite zipw_cons.
    change (mv (map (Z.mul w) r :: zipw (fun w0 r0 => map (Z.mul w0) r0) ws A) x)
      with (dot (map (Z.mul w) r) x :: mv (zipw (fun w0 r0 => map (Z.mul w0) r0) ws A) x).
    rewrite dot_scale. f_equal. apply IH.
Qed.

Lemma mv_mscale : forall k A x, mv (mscale k A) x = map (Z.mul k) (mv A x).
Proof.
  intros k A x. unfold mv, mscale. rewrite !map_map. apply map_ext.
  intro r. apply dot_scale.
Qed.

(* <A x, B x>_W = x . ((W A)^T B) x. *)
Lemma wbil_mv : forall ws A B x,
  Wf 125 (rowscale ws A) -> Wf 125 B -> length x = 125%nat ->
  wbil ws (mv A x) (mv B x)
  = dot x (mv (mmul (transpose_n 125 (rowscale ws A)) B) x).
Proof.
  intros ws A B x HA HB Hx. unfold wbil. rewrite mv_rowscale.
  assert (Hl : length (mv B x) = 125%nat) by (rewrite mv_len; apply HB).
  rewrite (dot_mv_adjoint _ x (mv B x) HA Hx Hl).
  rewrite (mv_mmul125 _ B x (Wf_transpose _ _ HA) HB Hx).
  reflexivity.
Qed.

(* Boolean matrix equality, to check many closed identities at once. *)
Fixpoint leqb {X : Type} (f : X -> X -> bool) (u v : list X) : bool :=
  match u, v with
  | [], [] => true
  | a :: u', b :: v' => f a b && leqb f u' v'
  | _, _ => false
  end.

Lemma leqb_eq : forall {X : Type} (f : X -> X -> bool) u v,
  (forall a b, f a b = true -> a = b) -> leqb f u v = true -> u = v.
Proof.
  intros X f. induction u as [|a u IH]; intros [|b v] Hf H; simpl in H;
    try discriminate; try reflexivity.
  apply andb_true_iff in H as [H1 H2]. rewrite (Hf _ _ H1), (IH v Hf H2). reflexivity.
Qed.

Definition meqb (A B : Mat) : bool := leqb (leqb Z.eqb) A B.

Lemma meqb_eq : forall A B, meqb A B = true -> A = B.
Proof.
  intros A B H. unfold meqb in H. apply (leqb_eq (leqb Z.eqb) A B); [|exact H].
  intros a b Hab. apply (leqb_eq Z.eqb); [|exact Hab]. intros. apply Z.eqb_eq. assumption.
Qed.

(* ================= Part 2: the weight, the levels, the filter ================= *)

(* (a) the weight W = W1 (x) W1 (x) W1 *)
Definition w1 : list Z := [1; 4; 24; 144; 576].
Lemma w1_recurrence :
  map (fun k => nth (S k) w1 0) (seq 0 4)
  = map (fun k => Z.of_nat ((S k) * (4 - k)) * nth k w1 0) (seq 0 4).
Proof. vm_compute. reflexivity. Qed.

Definition wts : list Z :=
  flat_map (fun a => flat_map (fun b => map (fun c => a * b * c) w1) w1) w1.

Definition W5 : Mat := mk 5 (fun i j => if Nat.eqb i j then nth i w1 0 else 0).
Definition Wmat : Mat := Eval vm_compute in kron (kron W5 W5) W5.
Lemma Wmat_def : Wmat = kron (kron W5 W5) W5. Proof. vm_compute. reflexivity. Qed.

Theorem W_positive_diagonal :
  length wts = 125%nat /\ forallb (fun w => 0 <? w) wts = true /\
  Wmat = mk 125 (fun i j => if Nat.eqb i j then nth i wts 0 else 0).
Proof. vm_compute. repeat split; reflexivity. Qed.

Lemma wts_nonneg : forall w, In w wts -> 0 <= w.
Proof.
  intros w H. assert (Hf : forallb (fun w => 0 <? w) wts = true)
    by (vm_compute; reflexivity).
  rewrite forallb_forall in Hf. pose proof (Hf w H) as H0.
  apply Z.ltb_lt in H0. lia.
Qed.

Definition Tr (A : Mat) : Mat := transpose_n 125 A.

(* W*Jm = (W*Jp)^T  (Jm, Jp are W-adjoint), W*Jz symmetric, W*C = C^T*W. *)
Theorem weight_adjoint_Jm_Jp : mmul Wmat Jm3 = mmul (Tr Jp3) Wmat.
Proof. vm_compute. reflexivity. Qed.
Theorem weight_adjoint_Jp_Jm : mmul Wmat Jp3 = mmul (Tr Jm3) Wmat.
Proof. vm_compute. reflexivity. Qed.
Theorem weight_adjoint_Jz : mmul Wmat Jz3 = mmul (Tr Jz3) Wmat.
Proof. vm_compute. reflexivity. Qed.
Theorem weight_selfadjoint_C : mmul Wmat C = mmul (Tr C) Wmat.
Proof. vm_compute. reflexivity. Qed.

(* (b) scaled spectral idempotents E_i = (Dd/d_i) N_i *)
Definition Elist : list Mat :=
  Eval vm_compute in map (fun i => mscale (Dd / dcoef i) (nth i Nlist [])) (seq 0 7).
Lemma Elist_def : Elist = map (fun i => mscale (Dd / dcoef i) (nth i Nlist [])) (seq 0 7).
Proof. vm_compute. reflexivity. Qed.
Definition E (i : nat) : Mat := nth i Elist [].

Definition lev : list nat := seq 0 7.
Definition allpairs : list (nat * nat) := flat_map (fun i => map (fun j => (i, j)) lev) lev.

Lemma E_square : forall i, In i lev -> Wf 125 (E i).
Proof.
  intros i Hi. apply is_square_Wf.
  assert (H : forallb (fun i => is_square 125 (E i)) lev = true) by (vm_compute; reflexivity).
  rewrite forallb_forall in H. apply H. exact Hi.
Qed.

Lemma rowscale_E_square : forall i, In i lev -> Wf 125 (rowscale wts (E i)).
Proof.
  intros i Hi. apply is_square_Wf.
  assert (H : forallb (fun i => is_square 125 (rowscale wts (E i))) lev = true)
    by (vm_compute; reflexivity).
  rewrite forallb_forall in H. apply H. exact Hi.
Qed.

Theorem E_idempotent : forall i, In i lev -> mmul (E i) (E i) = mscale Dd (E i).
Proof.
  intros i Hi.
  assert (H : forallb (fun i => meqb (mmul (E i) (E i)) (mscale Dd (E i))) lev = true)
    by (vm_compute; reflexivity).
  rewrite forallb_forall in H. apply meqb_eq. apply H. exact Hi.
Qed.

(* W*E_i = E_i^T*W *)
Theorem E_weight_selfadjoint : forall i, In i lev -> mmul Wmat (E i) = mmul (Tr (E i)) Wmat.
Proof.
  intros i Hi.
  assert (H : forallb (fun i => meqb (mmul Wmat (E i)) (mmul (Tr (E i)) Wmat)) lev = true)
    by (vm_compute; reflexivity).
  rewrite forallb_forall in H. apply meqb_eq. apply H. exact Hi.
Qed.

(* the same in the form used below: W*E_i is symmetric. *)
Lemma rowscale_E_symmetric : forall i, In i lev -> Tr (rowscale wts (E i)) = rowscale wts (E i).
Proof.
  intros i Hi.
  assert (H : forallb (fun i => meqb (Tr (rowscale wts (E i))) (rowscale wts (E i))) lev = true)
    by (vm_compute; reflexivity).
  rewrite forallb_forall in H. apply meqb_eq. apply H. exact Hi.
Qed.

(* sum of the E_i: from E47MatrixProjector.resolution_of_identity *)
Theorem E_resolution : fold_right madd zero125 Elist = mscale Dd I125.
Proof.
  rewrite Elist_def.
  pose proof resolution_of_identity as H.
  replace (map (fun i => mscale (Dd / dcoef i) (nth i Nlist [])) (seq 0 7))
    with (map (fun p => mscale (Dd / dcoef (fst p)) (snd p)) (combine (seq 0 7) Nlist)).
  - exact H.
  - vm_compute. reflexivity.
Qed.

(* the filter numerator G = D*I - K^2, D = 99144 *)
Definition Gm : Mat := Eval vm_compute in msub (mscale OddsContraction.D I125) (mmul K K).
Lemma Gm_def : Gm = msub (mscale OddsContraction.D I125) (mmul K K).
Proof. vm_compute. reflexivity. Qed.

Lemma Gm_square : Wf 125 Gm.
Proof. apply is_square_Wf. vm_compute. reflexivity. Qed.

Theorem G_on_E : forall i, In i lev ->
  mmul (E i) Gm = mscale (OddsContraction.num (node i)) (E i).
Proof.
  intros i Hi.
  assert (H : forallb (fun i => meqb (mmul (E i) Gm)
                                     (mscale (OddsContraction.num (node i)) (E i))) lev = true)
    by (vm_compute; reflexivity).
  rewrite forallb_forall in H. apply meqb_eq. apply H. exact Hi.
Qed.

(* W-orthogonality of different levels, at the matrix level: (W E_i) E_j = 0. *)
Theorem E_orthogonal_matrices : forall i j, In i lev -> In j lev -> i <> j ->
  mmul (rowscale wts (E i)) (E j) = zero125.
Proof.
  intros i j Hi Hj Hij.
  assert (H : forallb (fun p => Nat.eqb (fst p) (snd p) ||
                                meqb (mmul (rowscale wts (E (fst p))) (E (snd p))) zero125)
                      allpairs = true)
    by (vm_compute; reflexivity).
  rewrite forallb_forall in H.
  assert (Hp : In (i, j) allpairs).
  { unfold allpairs. apply in_flat_map. exists i. split; [exact Hi|].
    apply in_map_iff. exists j. split; [reflexivity | exact Hj]. }
  pose proof (H _ Hp) as H1. simpl in H1.
  apply orb_true_iff in H1 as [H1 | H1].
  - apply Nat.eqb_eq in H1. contradiction.
  - apply meqb_eq. exact H1.
Qed.

(* ---------- masses ---------- *)

Definition lvl_mass (i : nat) (x : list Z) : Z :=
  wbil wts (mv (E i) x) (mv (E i) x).

Theorem lvl_mass_nonneg : forall i x, 0 <= lvl_mass i x.
Proof. intros. unfold lvl_mass. apply wbil_self_nonneg, wts_nonneg. Qed.

(* (c) masses of different levels are W-orthogonal *)
Theorem lvl_orthogonal : forall i j x, In i lev -> In j lev -> i <> j -> length x = 125%nat ->
  wbil wts (mv (E i) x) (mv (E j) x) = 0.
Proof.
  intros i j x Hi Hj Hij Hx.
  rewrite (wbil_mv wts (E i) (E j) x (rowscale_E_square i Hi) (E_square j Hj) Hx).
  change (transpose_n 125 (rowscale wts (E i))) with (Tr (rowscale wts (E i))).
  rewrite (rowscale_E_symmetric i Hi), (E_orthogonal_matrices i j Hi Hj Hij).
  unfold zero125. rewrite mv_mscale. apply dot_zero_vec.
Qed.

Lemma length_mvG : forall x, length (mv Gm x) = 125%nat.
Proof. intro x. rewrite mv_len. apply Gm_square. Qed.

(* (c) Gamma action: mass_i(G x) = num(c_i)^2 mass_i(x) *)
Theorem lvl_mass_gamma : forall i x, In i lev -> length x = 125%nat ->
  lvl_mass i (mv Gm x) = OddsContraction.num (node i) * OddsContraction.num (node i) * lvl_mass i x.
Proof.
  intros i x Hi Hx. unfold lvl_mass.
  rewrite <- (mv_mmul125 (E i) Gm x (E_square i Hi) Gm_square Hx).
  rewrite (G_on_E i Hi), mv_mscale. apply wbil_scale.
Qed.

(* ================= (d) instantiating the abstract odds theorems ================= *)

Definition lvl_of (c : Z) : option nat :=
  if Z.eqb c 0 then Some 0%nat else if Z.eqb c 2 then Some 1%nat
  else if Z.eqb c 6 then Some 2%nat else if Z.eqb c 12 then Some 3%nat
  else if Z.eqb c 20 then Some 4%nat else if Z.eqb c 30 then Some 5%nat
  else if Z.eqb c 42 then Some 6%nat else None.

Lemma lvl_of_spec : forall c i, lvl_of c = Some i -> In i lev /\ c = node i.
Proof.
  intros c i H. unfold lvl_of in H.
  destruct (Z.eqb_spec c 0) as [->|n0]; [injection H as <-; split; [unfold lev; apply in_seq; lia | vm_compute; reflexivity]|].
  destruct (Z.eqb_spec c 2) as [->|n1]; [injection H as <-; split; [unfold lev; apply in_seq; lia | vm_compute; reflexivity]|].
  destruct (Z.eqb_spec c 6) as [->|n2]; [injection H as <-; split; [unfold lev; apply in_seq; lia | vm_compute; reflexivity]|].
  destruct (Z.eqb_spec c 12) as [->|n3]; [injection H as <-; split; [unfold lev; apply in_seq; lia | vm_compute; reflexivity]|].
  destruct (Z.eqb_spec c 20) as [->|n4]; [injection H as <-; split; [unfold lev; apply in_seq; lia | vm_compute; reflexivity]|].
  destruct (Z.eqb_spec c 30) as [->|n5]; [injection H as <-; split; [unfold lev; apply in_seq; lia | vm_compute; reflexivity]|].
  destruct (Z.eqb_spec c 42) as [->|n6]; [injection H as <-; split; [unfold lev; apply in_seq; lia | vm_compute; reflexivity]|].
  discriminate.
Qed.

(* mass at Casimir level c (0 off the seven levels) *)
Definition mass_of (x : list Z) : OddsContraction.mass :=
  fun c => match lvl_of c with Some i => lvl_mass i x | None => 0 end.

Lemma mass_of_nonneg : forall x, OddsContraction.Nonneg (mass_of x).
Proof.
  intros x c. unfold mass_of. destruct (lvl_of c); [apply lvl_mass_nonneg | lia].
Qed.

Lemma mass_of_gamma : forall x, length x = 125%nat ->
  forall c, mass_of (mv Gm x) c = OddsContraction.step (mass_of x) c.
Proof.
  intros x Hx c. unfold OddsContraction.step, mass_of.
  destruct (lvl_of c) as [i|] eqn:H.
  - destruct (lvl_of_spec c i H) as [Hi ->]. apply lvl_mass_gamma; assumption.
  - ring.
Qed.

Fixpoint gpow (k : nat) (x : list Z) : list Z :=
  match k with O => x | S k' => mv Gm (gpow k' x) end.

Lemma gpow_len : forall k x, length x = 125%nat -> length (gpow k x) = 125%nat.
Proof. induction k as [|k IH]; intros x Hx; [exact Hx | exact (length_mvG _)]. Qed.

Lemma mass_of_gpow : forall k x, length x = 125%nat ->
  forall c, mass_of (gpow k x) c = OddsContraction.iter k (mass_of x) c.
Proof.
  induction k as [|k IH]; intros x Hx c; [reflexivity|].
  change (gpow (S k) x) with (mv Gm (gpow k x)).
  change (OddsContraction.iter (S k) (mass_of x)) with
    (OddsContraction.step (OddsContraction.iter k (mass_of x))).
  rewrite (mass_of_gamma _ (gpow_len k x Hx) c).
  unfold OddsContraction.step. rewrite (IH x Hx c). reflexivity.
Qed.

(* in = E47 part (levels 6, 30 = indices 2, 5); out = the other five levels. *)
Definition in_lvl (x : list Z) : Z := lvl_mass 2 x + lvl_mass 5 x.
Definition out_lvl (x : list Z) : Z :=
  lvl_mass 0 x + lvl_mass 1 x + lvl_mass 3 x + lvl_mass 4 x + lvl_mass 6 x.

Lemma inm_ext : forall m1 m2, (forall c, m1 c = m2 c) -> OddsContraction.inm m1 = OddsContraction.inm m2.
Proof. intros m1 m2 H. unfold OddsContraction.inm. rewrite !H. reflexivity. Qed.
Lemma outm_ext : forall m1 m2, (forall c, m1 c = m2 c) -> OddsContraction.outm m1 = OddsContraction.outm m2.
Proof. intros m1 m2 H. unfold OddsContraction.outm. rewrite !H. reflexivity. Qed.

Lemma inm_mass_of : forall x, OddsContraction.inm (mass_of x) = in_lvl x.
Proof. intro x. reflexivity. Qed.
Lemma outm_mass_of : forall x, OddsContraction.outm (mass_of x) = out_lvl x.
Proof. intro x. reflexivity. Qed.

Lemma in_lvl_gpow_eq : forall k x, length x = 125%nat ->
  in_lvl (gpow k x) = OddsContraction.inm (OddsContraction.iter k (mass_of x)).
Proof.
  intros k x Hx. rewrite <- inm_mass_of. apply inm_ext. apply mass_of_gpow. exact Hx.
Qed.
Lemma out_lvl_gpow_eq : forall k x, length x = 125%nat ->
  out_lvl (gpow k x) = OddsContraction.outm (OddsContraction.iter k (mass_of x)).
Proof.
  intros k x Hx. rewrite <- outm_mass_of. apply outm_ext. apply mass_of_gpow. exact Hx.
Qed.

(* in(Gx) = D^2 in(x): Gamma is the identity on the kernel part (up to the scale D) *)
Theorem in_gamma : forall x, length x = 125%nat ->
  in_lvl (mv Gm x) = OddsContraction.D * OddsContraction.D * in_lvl x.
Proof.
  intros x Hx.
  rewrite <- (inm_mass_of x), <- (OddsContraction.step_in (mass_of x)).
  rewrite <- (inm_mass_of (mv Gm x)). apply inm_ext. apply mass_of_gamma. exact Hx.
Qed.

Theorem in_gamma_k : forall k x, length x = 125%nat ->
  in_lvl (gpow k x) = (OddsContraction.D * OddsContraction.D) ^ Z.of_nat k * in_lvl x.
Proof.
  intros k x Hx. rewrite in_lvl_gpow_eq by exact Hx.
  rewrite OddsContraction.iter_in. reflexivity.
Qed.

(* One step: for every integer vector x of the 125x125 model. *)
Theorem odds_link_one_step : forall x, length x = 125%nat ->
  289 * out_lvl (mv Gm x) * in_lvl x <= 225 * out_lvl x * in_lvl (mv Gm x).
Proof.
  intros x Hx.
  pose proof (OddsContraction.odds_one_step (mass_of x) (mass_of_nonneg x)) as H.
  assert (E1 : OddsContraction.outm (OddsContraction.step (mass_of x)) = out_lvl (mv Gm x)).
  { rewrite <- outm_mass_of. symmetry. apply outm_ext. apply mass_of_gamma. exact Hx. }
  assert (E2 : OddsContraction.inm (OddsContraction.step (mass_of x)) = in_lvl (mv Gm x)).
  { rewrite <- inm_mass_of. symmetry. apply inm_ext. apply mass_of_gamma. exact Hx. }
  rewrite E1, E2, inm_mass_of, outm_mass_of in H. exact H.
Qed.

(* k steps: 289^k out(G^k x) in(x) <= 225^k out(x) in(G^k x). *)
Theorem odds_link_k_steps : forall k x, length x = 125%nat ->
  289 ^ Z.of_nat k * out_lvl (gpow k x) * in_lvl x
    <= 225 ^ Z.of_nat k * out_lvl x * in_lvl (gpow k x).
Proof.
  intros k x Hx.
  pose proof (OddsContraction.odds_k_steps k (mass_of x) (mass_of_nonneg x)) as H.
  rewrite <- (out_lvl_gpow_eq k x Hx), <- (in_lvl_gpow_eq k x Hx),
          inm_mass_of, outm_mass_of in H.
  exact H.
Qed.

(* Equality cases: all off-kernel mass at Casimir 12 (index 3) or 42 (index 6). *)
Theorem odds_link_equality_12 : forall x, length x = 125%nat ->
  lvl_mass 0 x = 0 -> lvl_mass 1 x = 0 -> lvl_mass 4 x = 0 -> lvl_mass 6 x = 0 ->
  289 * out_lvl (mv Gm x) = 225 * (OddsContraction.D * OddsContraction.D) * out_lvl x.
Proof.
  intros x Hx h0 h2 h20 h42.
  pose proof (OddsContraction.equality_case_12 (mass_of x) (mass_of_nonneg x)
                h0 h2 h20 h42) as H.
  assert (E1 : OddsContraction.outm (OddsContraction.step (mass_of x)) = out_lvl (mv Gm x)).
  { rewrite <- outm_mass_of. symmetry. apply outm_ext. apply mass_of_gamma. exact Hx. }
  rewrite E1, outm_mass_of in H. exact H.
Qed.

Theorem odds_link_equality_42 : forall x, length x = 125%nat ->
  lvl_mass 0 x = 0 -> lvl_mass 1 x = 0 -> lvl_mass 3 x = 0 -> lvl_mass 4 x = 0 ->
  289 * out_lvl (mv Gm x) = 225 * (OddsContraction.D * OddsContraction.D) * out_lvl x.
Proof.
  intros x Hx h0 h2 h12 h20.
  pose proof (OddsContraction.equality_case_42 (mass_of x) (mass_of_nonneg x)
                h0 h2 h12 h20) as H.
  assert (E1 : OddsContraction.outm (OddsContraction.step (mass_of x)) = out_lvl (mv Gm x)).
  { rewrite <- outm_mass_of. symmetry. apply outm_ext. apply mass_of_gamma. exact Hx. }
  rewrite E1, outm_mass_of in H. exact H.
Qed.

(* ================= (e) numeric sanity on explicit integer vectors ================= *)

Definition col (a : nat) (M : Mat) : list Z := map (fun r => nth a r 0) M.

Definition x_ones : list Z := repeat 1 125.
(* a vector inside the Casimir-6 and Casimir-12 blocks: column 4 of E_2 plus column 3 of E_3 *)
Definition x_ex : list Z := zipw Z.add (col 4 (E 2)) (col 3 (E 3)).

Lemma x_lengths : length x_ones = 125%nat /\ length x_ex = 125%nat.
Proof. split; vm_compute; reflexivity. Qed.

Lemma ones_masses :
  map (fun i => lvl_mass i x_ones) lev =
  [45311622478036992000; 0; 42423006545062133760000; 67431875512488689664000;
   794666052550863618048000; 0; 95504834022001060478976000].
Proof. vm_compute. reflexivity. Qed.

Lemma ones_odds_one_step :
  Z.leb (289 * out_lvl (mv Gm x_ones) * in_lvl x_ones)
        (225 * out_lvl x_ones * in_lvl (mv Gm x_ones)) = true.
Proof. vm_compute. reflexivity. Qed.

Lemma ex_masses :
  map (fun i => lvl_mass i x_ex) lev =
  [0; 0; 16846040274833222914541617152000000000; 3537668457714976812053739601920000000; 0; 0; 0].
Proof. vm_compute. reflexivity. Qed.

Lemma ex_masses_after_one_step :
  map (fun i => lvl_mass i (mv Gm x_ex)) lev =
  [0; 0; 165588704353447601578872156229963087872000000000;
   27072893704845671884434980560089120768000000000; 0; 0; 0].
Proof. vm_compute. reflexivity. Qed.

(* on x_ex the whole off-kernel mass is at Casimir 12, so the odds bound is an EQUALITY ... *)
Lemma ex_odds_equality :
  289 * out_lvl (mv Gm x_ex) = 225 * (OddsContraction.D * OddsContraction.D) * out_lvl x_ex.
Proof. vm_compute. reflexivity. Qed.

(* ... while the naive bound on R = out/(in+out) fails at k = 1 on this explicit integer vector:
   R_1 > (225/289) R_0, cross-multiplied. *)
Theorem naive_bound_fails_on_integer_vector :
  225 * out_lvl x_ex * (in_lvl (mv Gm x_ex) + out_lvl (mv Gm x_ex))
    < 289 * out_lvl (mv Gm x_ex) * (in_lvl x_ex + out_lvl x_ex).
Proof. vm_compute. reflexivity. Qed.

Theorem odds_bound_on_integer_vector :
  289 * out_lvl (mv Gm x_ex) * in_lvl x_ex <= 225 * out_lvl x_ex * in_lvl (mv Gm x_ex).
Proof. apply odds_link_one_step. destruct x_lengths as [_ H]. exact H. Qed.

End OddsLink.

Print Assumptions OddsLink.W_positive_diagonal.
Print Assumptions OddsLink.weight_adjoint_Jm_Jp.
Print Assumptions OddsLink.weight_selfadjoint_C.
Print Assumptions OddsLink.E_weight_selfadjoint.
Print Assumptions OddsLink.E_idempotent.
Print Assumptions OddsLink.E_resolution.
Print Assumptions OddsLink.G_on_E.
Print Assumptions OddsLink.lvl_mass_nonneg.
Print Assumptions OddsLink.lvl_orthogonal.
Print Assumptions OddsLink.lvl_mass_gamma.
Print Assumptions OddsLink.in_gamma.
Print Assumptions OddsLink.odds_link_one_step.
Print Assumptions OddsLink.odds_link_k_steps.
Print Assumptions OddsLink.odds_link_equality_12.
Print Assumptions OddsLink.naive_bound_fails_on_integer_vector.
Print Assumptions OddsLink.odds_bound_on_integer_vector.
Print Assumptions OddsLink.ones_masses.
Print Assumptions OddsLink.odds_link_equality_42.
Print Assumptions OddsLink.odds_link_k_steps.
