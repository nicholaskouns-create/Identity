(* Weight-counting algebra behind the E47 spectral certificate.
   Self-contained: Coq standard library only, no axioms, no Admitted.
   Companion to E47WeightAlgebra.lean (same statements).

   WHAT IS FORMALIZED HERE
   - The carrier basis of H = V_2 (x) V_2 (x) V_2 is the set of triples (a,b,c)
     with a,b,c in {-2,..,2}. Total Jz is diagonal on this basis with eigenvalue
     a+b+c. [w m] is the number of basis triples with a+b+c = m.
   - w(0..6) = 19,18,15,10,6,3,1, w is symmetric, w vanishes outside -6..6, and
     the basis has 125 elements.
   - Multiplicity of spin j is defined as [mult j = w j - w (j+1)]. It evaluates
     to 1,3,5,4,3,2,1. The truncated nat subtraction is justified by a proved
     monotonicity fact (w (j+1) <= w j for j <= 6).
   - The multiplicities reproduce the weight spectrum: w m = sum_{j >= |m|} mult j
     for every m in -6..6, and sum_j mult j * (2j+1) = 125.
   - For K = (C-6)(C-30) acting as the scalar lam(j(j+1)) on a spin-j block:
     lam(j(j+1)) = 0 iff j = 2 or j = 5, for ALL natural j.
   - kernel_rank_from_weights: (w 2 - w 3)*5 + (w 5 - w 6)*11 = 47.
   - The Gamma = I - K^2/99144 contraction numbers, computed from the above.
   - Scalar identities on the Casimir spectrum for the degree-six polynomial
     pr(x) = x(x-2)(x-12)(x-20)(x-31)(x-42): pr(c) = 0 at the nodes 0,2,12,20,42,
     pr(6) = pr(30) = 1814400 = 10!/2, and pr has the coefficients
     [1,-107,4088,-66940,430848,-624960,0] (checked for every integer x).
     So P = pr(C)/1814400 takes the value 1 on spin 2 and spin 5 blocks and 0 on
     the others, as a polynomial in the scalar C-value.

   WHAT IS NOT FORMALIZED
   - The 125-by-125 matrices Jx, Jy, Jz, C, K are not defined in this file, and
     nothing here is a theorem about those operators.
   - The following standard sl2 facts are taken as textbook input and appear only
     in this comment, not as axioms: (i) every finite-dimensional sl2 module
     splits into irreducible ladders, so the number of spin-j summands equals
     dim(weight j) - dim(weight j+1); (ii) the Casimir C = Jx^2+Jy^2+Jz^2 acts as
     j(j+1) on a spin-j summand. Given those two facts, the numbers proved here
     are exactly the multiplicities, the dimensions and the kernel rank. The
     matrices themselves are checked numerically in simulation/e47_tqgnn/. *)

From Coq Require Import List ZArith Lia Nat.
Import ListNotations.

Module WeightAlgebra.

Definition vals : list Z := [-2; -1; 0; 1; 2]%Z.

(* Basis of the carrier: m-values of the three spin-2 factors. *)
Definition triples : list (Z * Z * Z) :=
  flat_map (fun a => flat_map (fun b => map (fun c => (a, b, c)) vals) vals) vals.

Definition tsum (t : Z * Z * Z) : Z := (fst (fst t) + snd (fst t) + snd t)%Z.

(* Weight count: number of basis triples with total Jz = m. *)
Definition w (m : Z) : nat :=
  length (filter (fun t => Z.eqb (tsum t) m) triples).

(* Highest-weight multiplicity of spin j. *)
Definition mult (j : nat) : nat := w (Z.of_nat j) - w (Z.of_nat (S j)).

Definition casimir (j : nat) : nat := j * (j + 1).

Definition lam (c : Z) : Z := ((c - 6) * (c - 30))%Z.

Definition gap (c : Z) : Z := Z.abs (99144 - lam c * lam c).

Definition window : list Z := map (fun i => (Z.of_nat i - 6)%Z) (seq 0 13).

(* Boolean check lifted to Forall. *)
Lemma forallb_to_Forall {A : Type} (f : A -> bool) (P : A -> Prop) (l : list A) :
  (forall x, f x = true -> P x) -> forallb f l = true -> Forall P l.
Proof.
  intros H Hl. apply Forall_forall. intros x Hx.
  apply H. rewrite forallb_forall in Hl. apply Hl, Hx.
Qed.

(* Split a statement about j in seq 0 7 into its seven cases. *)
Ltac cases7 :=
  apply Forall_forall; intros j Hj; simpl in Hj;
  repeat (destruct Hj as [<- | Hj]); try contradiction.

(* ---- 1. Weight counts ---- *)

Lemma basis_size : length triples = 125.
Proof. vm_compute. reflexivity. Qed.

Lemma weight_counts :
  w 0 = 19 /\ w 1 = 18 /\ w 2 = 15 /\ w 3 = 10 /\ w 4 = 6 /\ w 5 = 3 /\ w 6 = 1.
Proof. vm_compute. repeat split; reflexivity. Qed.

Lemma weight_symmetric : Forall (fun m => w (- m) = w m) window.
Proof.
  apply (forallb_to_Forall (fun m => Nat.eqb (w (- m)) (w m))).
  - intros x Hx. apply Nat.eqb_eq, Hx.
  - vm_compute. reflexivity.
Qed.

Lemma weight_vanishes_outside : w 7 = 0 /\ w (-7) = 0.
Proof. vm_compute. split; reflexivity. Qed.

Lemma weight_total : fold_right Nat.add 0 (map w window) = 125.
Proof. vm_compute. reflexivity. Qed.

(* Every triple has total weight in -6..6, so no weight outside that window
   is missed by weight_total. *)
Lemma weight_window :
  Forall (fun t => (-6 <= tsum t /\ tsum t <= 6)%Z) triples.
Proof.
  apply (forallb_to_Forall (fun t => andb (Z.leb (-6)%Z (tsum t)) (Z.leb (tsum t) 6%Z))).
  - intros x Hx. apply andb_prop in Hx. destruct Hx as [H1 H2].
    apply Z.leb_le in H1. apply Z.leb_le in H2. split; assumption.
  - vm_compute. reflexivity.
Qed.

(* ---- 2. Multiplicities ---- *)

Lemma weight_antitone :
  Forall (fun j => w (Z.of_nat (S j)) <= w (Z.of_nat j)) (seq 0 7).
Proof.
  apply (forallb_to_Forall (fun j => Nat.leb (w (Z.of_nat (S j))) (w (Z.of_nat j)))).
  - intros x Hx. apply Nat.leb_le, Hx.
  - vm_compute. reflexivity.
Qed.

Lemma multiplicities : map mult (seq 0 7) = [1; 3; 5; 4; 3; 2; 1].
Proof. vm_compute. reflexivity. Qed.

Lemma dimension_identity :
  fold_right Nat.add 0 (map (fun j => mult j * (2 * j + 1)) (seq 0 7)) = 125.
Proof. vm_compute. reflexivity. Qed.

(* The multiplicities reproduce the weight spectrum:
   w m = sum over spins j >= |m| of mult j. *)
Definition tailSum (m : Z) : nat :=
  fold_right Nat.add 0
    (map mult (filter (fun j => Z.leb (Z.abs m) (Z.of_nat j)) (seq 0 7))).

Lemma multiplicities_reproduce_weights :
  Forall (fun m => w m = tailSum m) window.
Proof.
  apply (forallb_to_Forall (fun m => Nat.eqb (w m) (tailSum m))).
  - intros x Hx. apply Nat.eqb_eq, Hx.
  - vm_compute. reflexivity.
Qed.

(* ---- 3. Casimir and kernel ---- *)

Lemma casimir_values : map casimir (seq 0 7) = [0; 2; 6; 12; 20; 30; 42].
Proof. vm_compute. reflexivity. Qed.

Lemma lam_zero_on_range :
  Forall (fun j => (lam (Z.of_nat (casimir j)) = 0)%Z <-> (j = 2 \/ j = 5)) (seq 0 7).
Proof.
  cases7; vm_compute; split; intro H;
    first [ discriminate | (left; reflexivity) | (right; reflexivity)
          | (destruct H as [H | H]; discriminate) | reflexivity ].
Qed.

(* For every natural j, (c-6)(c-30) = 0 with c = j(j+1) forces j = 2 or j = 5. *)
Lemma lam_zero_iff :
  forall j : nat, lam (Z.of_nat (casimir j)) = 0%Z <-> (j = 2 \/ j = 5).
Proof.
  intro j. unfold lam, casimir. split.
  - intro H.
    rewrite Nat2Z.inj_mul in H. rewrite Nat2Z.inj_add in H. simpl in H.
    assert (Hj : (Z.of_nat j <= 5 \/ 6 <= Z.of_nat j)%Z) by lia.
    destruct Hj as [Hj | Hj].
    + assert (j = 0 \/ j = 1 \/ j = 2 \/ j = 3 \/ j = 4 \/ j = 5) as Hc by lia.
      destruct Hc as [? | [? | [? | [? | [? | ?]]]]]; subst; simpl in H;
        first [ discriminate | lia ].
    + exfalso.
      assert (Hp : (42 <= Z.of_nat j * (Z.of_nat j + 1))%Z) by nia.
      assert (Hq : ((Z.of_nat j * (Z.of_nat j + 1) - 6) * (Z.of_nat j * (Z.of_nat j + 1) - 30) > 0)%Z) by nia.
      lia.
  - intros [H | H]; subst; reflexivity.
Qed.

(* Kernel rank, derived from the weight counts and not from stored multiplicities. *)
Lemma kernel_rank_from_weights : (w 2 - w 3) * 5 + (w 5 - w 6) * 11 = 47.
Proof. vm_compute. reflexivity. Qed.

(* Same number, as the sum of block dimensions over spins where lam vanishes. *)
Definition kernelDim : nat :=
  fold_right Nat.add 0
    (map (fun j => mult j * (2 * j + 1))
         (filter (fun j => Z.eqb (lam (Z.of_nat (casimir j))) 0) (seq 0 7))).

Lemma kernel_dim_from_blocks : kernelDim = 47.
Proof. vm_compute. reflexivity. Qed.

Lemma kernel_blocks_are_spin2_spin5 :
  filter (fun j => Z.eqb (lam (Z.of_nat (casimir j))) 0) (seq 0 7) = [2; 5].
Proof. vm_compute. reflexivity. Qed.

(* ---- 4. Gamma = I - K^2/99144 ---- *)

Lemma top_weight_gives_spin6 : w 6 <> 0 /\ w 7 = 0.
Proof. vm_compute. split; discriminate || reflexivity. Qed.

(* Denominator from the highest spin: lam(42)^2 * 17 = 99144 * 32. *)
Lemma denominator_from_top_spin :
  (lam (Z.of_nat (casimir 6)) * lam (Z.of_nat (casimir 6)) * 17 = 99144 * 32)%Z.
Proof. vm_compute. reflexivity. Qed.

Lemma gamma_is_one_on_kernel :
  Forall (fun j => (lam (Z.of_nat (casimir j)) = 0 -> gap (Z.of_nat (casimir j)) = 99144)%Z)
         (seq 0 7).
Proof.
  cases7; vm_compute; intro H; first [ reflexivity | discriminate ].
Qed.

(* Off the kernel, Gamma contracts by at most 15/17, with equality at spins 3 and 6. *)
Lemma gamma_contracts_off_kernel :
  Forall (fun j => (lam (Z.of_nat (casimir j)) <> 0 ->
                   gap (Z.of_nat (casimir j)) * 17 <= 15 * 99144)%Z) (seq 0 7).
Proof.
  cases7; vm_compute; intro H;
    first [ exfalso; apply H; reflexivity | discriminate ].
Qed.

Lemma gamma_contraction_extremes :
  (gap (Z.of_nat (casimir 3)) * 17 = 15 * 99144 /\
   gap (Z.of_nat (casimir 6)) * 17 = 15 * 99144)%Z.
Proof. vm_compute. split; reflexivity. Qed.

(* ---- 5. The exact projector polynomial on the Casimir spectrum ---- *)

(* pr(x) = x (x-2) (x-12) (x-20) (x-31) (x-42). The five roots 0, 2, 12, 20, 42
   are the Casimir nodes outside the kernel. The sixth root 31 is not a node; it
   is chosen so that pr(6) = pr(30). These are scalar identities on the Casimir
   spectrum {0,2,6,12,20,30,42}. They say what P = pr(C)/1814400 does on each
   spin block, given that C acts as the scalar j(j+1) there (textbook input, see
   header). They are not a statement about the 125-by-125 matrix pr(C). *)
Definition pr (x : Z) : Z := (x * (x - 2) * (x - 12) * (x - 20) * (x - 31) * (x - 42))%Z.

Definition nodes : list Z := map (fun j => Z.of_nat (casimir j)) (seq 0 7).

Lemma nodes_are_casimir_values : nodes = [0; 2; 6; 12; 20; 30; 42]%Z.
Proof. vm_compute. reflexivity. Qed.

Lemma pr_on_nodes :
  map pr nodes = [0; 0; 1814400; 0; 0; 1814400; 0]%Z.
Proof. vm_compute. reflexivity. Qed.

Fixpoint fact (n : nat) : nat := match n with O => 1 | S k => S k * fact k end.

Lemma pr_normalizer : (1814400 = Z.of_nat (fact 10 / 2))%Z.
Proof. vm_compute. reflexivity. Qed.

(* Horner evaluation of a coefficient list, highest power first. *)
Definition peval (cs : list Z) (x : Z) : Z :=
  fold_left (fun acc c => (acc * x + c)%Z) cs 0%Z.

Definition pr_coeffs : list Z := [1; -107; 4088; -66940; 430848; -624960; 0]%Z.

(* The coefficients are exact: the identity holds for every integer x. *)
Lemma pr_expanded : forall x : Z, pr x = peval pr_coeffs x.
Proof. intro x. unfold pr, peval, pr_coeffs. cbn [fold_left]. ring. Qed.

Lemma pr_degree_six_monic : length pr_coeffs = 7 /\ hd 0%Z pr_coeffs = 1%Z.
Proof. split; reflexivity. Qed.

End WeightAlgebra.

Print Assumptions WeightAlgebra.basis_size.
Print Assumptions WeightAlgebra.weight_counts.
Print Assumptions WeightAlgebra.weight_symmetric.
Print Assumptions WeightAlgebra.weight_total.
Print Assumptions WeightAlgebra.weight_window.
Print Assumptions WeightAlgebra.multiplicities.
Print Assumptions WeightAlgebra.dimension_identity.
Print Assumptions WeightAlgebra.multiplicities_reproduce_weights.
Print Assumptions WeightAlgebra.lam_zero_iff.
Print Assumptions WeightAlgebra.kernel_rank_from_weights.
Print Assumptions WeightAlgebra.kernel_dim_from_blocks.
Print Assumptions WeightAlgebra.gamma_contracts_off_kernel.
Print Assumptions WeightAlgebra.pr_on_nodes.
Print Assumptions WeightAlgebra.pr_normalizer.
Print Assumptions WeightAlgebra.pr_expanded.
Print Assumptions WeightAlgebra.pr_degree_six_monic.
