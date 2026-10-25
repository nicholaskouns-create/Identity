(* Fibonacci-Lucas tower meets the E47 kernel blocks.
   Self-contained: Coq standard library only, no axioms, no Admitted.
   Companion to E47TowerKernel.lean (same statements).
   It re-states, with identical definitions, the Fibonacci/Lucas part of
   TowerIdentity.v and the weight-counting part of E47WeightAlgebra.v, so it
   compiles on its own with plain `coqc E47TowerKernel.v`.

   WHAT IS FORMALIZED HERE
   - fib, luc as in TowerIdentity.v, and the general induction theorem
     L_n^2 - 5 F_n^2 = -4 for odd n, giving J(J+1) = 5 j(j+1) whenever
     2j+1 = F_n and 2J+1 = L_n with n odd (all odd n).
   - The weight-algebra definitions (triples, w, mult, casimir, lam) from
     E47WeightAlgebra.v, unchanged.
   - At n = 5: F_5 = 5, L_5 = 11, F_3 = 2, so j = (F_5-1)/2 = 2 and
     J = (L_5-1)/2 = 5, and J(J+1) = 30 = 5 * 6 = 5 j(j+1).
   - The kernel rank identity 47 = F_5*F_5 + F_3*L_5 = 25 + 22, and
     D(n) = F_n^2 + F_{n-2} L_n evaluates to 47 at n = 5.
   - The tower spins j = 2 and J = 5 are exactly the kernel blocks of the
     weight algebra (filter of lam = 0 over spins 0..6 is [2; 5]);
     mult 2 = 5 = F_5, mult 5 = 2 = F_3; block dimensions 2j+1 = F_5 = 5 and
     2J+1 = L_5 = 11; the Casimir values 6 and 30 = 5*6 are the two roots of
     K = (C-6)(C-30).
   - A general identity for all odd m: F_m * L_{m+2} = F_{m+1} * L_{m+1} + 1
     (for even m the sign is -1). At m = 3 this is 22 = 21 + 1.
   - Bounded uniqueness: for n = 0..30, the only n for which 2j+1 = F_n,
     2J+1 = L_n has integer solutions and both lam(j(j+1)) and lam(J(J+1))
     vanish is n = 5. This is a finite check, not a proof for all n.

   WHAT IS NOT FORMALIZED
   - The 125-by-125 matrices are not defined in this file. The statements about
     "kernel blocks" are about the scalar function lam on Casimir values
     j(j+1), exactly as in E47WeightAlgebra.v. The sl2 facts that spin-j
     summands number w(j) - w(j+1) and that C acts as j(j+1) on them are
     textbook input stated in E47WeightAlgebra.v, not proved here.
   - Nothing says why the tower index n = 5 should be physically selected.
     It is a numerical coincidence that is now machine-checked, not a theorem
     that the kernel must come from the tower.
   - The identity F_n^2 + F_{n-2} L_n = 47 holds at n = 5 only as a computation;
     D(n) is not claimed to equal the kernel rank for other n. *)

From Coq Require Import List ZArith Lia Nat.
Import ListNotations.

(* ---------------- Fibonacci and Lucas (as in TowerIdentity.v) ---------------- *)

Module Tower.

Open Scope Z_scope.

Fixpoint fib (n : nat) : Z :=
  match n with
  | O => 0
  | S O => 1
  | S (S k as m) => fib m + fib k
  end.

Fixpoint luc (n : nat) : Z :=
  match n with
  | O => 2
  | S O => 1
  | S (S k as m) => luc m + luc k
  end.

Lemma invariants : forall n : nat,
  (if Nat.even n then
     luc n * luc n - 5 * fib n * fib n = 4 /\
     luc (S n) * luc (S n) - 5 * fib (S n) * fib (S n) = -4 /\
     luc n * luc (S n) - 5 * fib n * fib (S n) = 2
   else
     luc n * luc n - 5 * fib n * fib n = -4 /\
     luc (S n) * luc (S n) - 5 * fib (S n) * fib (S n) = 4 /\
     luc n * luc (S n) - 5 * fib n * fib (S n) = -2).
Proof.
  induction n as [|n IH].
  - simpl. lia.
  - rewrite Nat.even_succ. unfold Nat.odd.
    assert (Ef : fib (S (S n)) = fib (S n) + fib n) by reflexivity.
    assert (El : luc (S (S n)) = luc (S n) + luc n) by reflexivity.
    destruct (Nat.even n) eqn:E; simpl negb; cbv iota in IH;
      destruct IH as [H0 [H1 H2]];
      rewrite Ef, El; repeat split; nia.
Qed.

Theorem lucas_fibonacci_odd : forall n : nat,
  Nat.even n = false ->
  luc n * luc n - 5 * fib n * fib n = -4.
Proof.
  intros n Hodd.
  pose proof (invariants n) as H.
  rewrite Hodd in H.
  tauto.
Qed.

Theorem tower_spin_identity : forall (n : nat) (j J : Z),
  Nat.even n = false ->
  2 * j + 1 = fib n ->
  2 * J + 1 = luc n ->
  J * (J + 1) = 5 * j * (j + 1).
Proof.
  intros n j J Hodd Hj HJ.
  pose proof (lucas_fibonacci_odd n Hodd) as H.
  nia.
Qed.

(* ---- New: F_{m+1} L_{m+1} - F_m L_{m+2} = (-1)^m, for every m ---- *)

Lemma pair_defect : forall m : nat,
  fib (S m) * luc (S m) - fib m * luc (S (S m)) =
  (if Nat.even m then 1 else -1).
Proof.
  induction m as [|m IH].
  - simpl. lia.
  - assert (Ef : fib (S (S m)) = fib (S m) + fib m) by reflexivity.
    assert (El : luc (S (S m)) = luc (S m) + luc m) by reflexivity.
    assert (El2 : luc (S (S (S m))) = luc (S (S m)) + luc (S m)) by reflexivity.
    rewrite Nat.even_succ. unfold Nat.odd.
    rewrite Ef, El2.
    rewrite El in IH |- *.
    destruct (Nat.even m) eqn:E; simpl negb; cbv iota in IH |- *; nia.
Qed.

(* For odd m: F_m * L_{m+2} = F_{m+1} * L_{m+1} + 1. *)
Theorem fib_luc_shift_odd : forall m : nat,
  Nat.even m = false ->
  fib m * luc (S (S m)) = fib (S m) * luc (S m) + 1.
Proof.
  intros m Hodd. pose proof (pair_defect m) as H. rewrite Hodd in H. lia.
Qed.

End Tower.

(* ---------------- Weight algebra (as in E47WeightAlgebra.v) ---------------- *)

Module Kernel.

Definition vals : list Z := [-2; -1; 0; 1; 2]%Z.

Definition triples : list (Z * Z * Z) :=
  flat_map (fun a => flat_map (fun b => map (fun c => (a, b, c)) vals) vals) vals.

Definition tsum (t : Z * Z * Z) : Z := (fst (fst t) + snd (fst t) + snd t)%Z.

Definition w (m : Z) : nat :=
  length (filter (fun t => Z.eqb (tsum t) m) triples).

Definition mult (j : nat) : nat := w (Z.of_nat j) - w (Z.of_nat (S j)).

Definition casimir (j : nat) : nat := j * (j + 1).

Definition lam (c : Z) : Z := ((c - 6) * (c - 30))%Z.

Definition kernelDim : nat :=
  fold_right Nat.add 0
    (map (fun j => mult j * (2 * j + 1))
         (filter (fun j => Z.eqb (lam (Z.of_nat (casimir j))) 0) (seq 0 7))).

Lemma multiplicities : map mult (seq 0 7) = [1; 3; 5; 4; 3; 2; 1].
Proof. vm_compute. reflexivity. Qed.

Lemma kernel_blocks_are_spin2_spin5 :
  filter (fun j => Z.eqb (lam (Z.of_nat (casimir j))) 0) (seq 0 7) = [2; 5].
Proof. vm_compute. reflexivity. Qed.

Lemma kernel_dim_from_blocks : kernelDim = 47.
Proof. vm_compute. reflexivity. Qed.

Lemma kernel_rank_from_weights : (w 2 - w 3) * 5 + (w 5 - w 6) * 11 = 47.
Proof. vm_compute. reflexivity. Qed.

End Kernel.

(* ---------------- The link ---------------- *)

Module TowerKernel.

Import Tower Kernel.
Open Scope Z_scope.

(* The tower at n = 5. *)
Lemma fib_5 : fib 5 = 5.   Proof. reflexivity. Qed.
Lemma luc_5 : luc 5 = 11.  Proof. reflexivity. Qed.
Lemma fib_3 : fib 3 = 2.   Proof. reflexivity. Qed.
Lemma luc_3 : luc 3 = 4.   Proof. reflexivity. Qed.

Definition tower_j (n : nat) : Z := (fib n - 1) / 2.
Definition tower_J (n : nat) : Z := (luc n - 1) / 2.

Lemma tower_spins_n5 : tower_j 5 = 2 /\ tower_J 5 = 5.
Proof. split; vm_compute; reflexivity. Qed.

Lemma tower_exact_n5 : 2 * tower_j 5 + 1 = fib 5 /\ 2 * tower_J 5 + 1 = luc 5.
Proof. split; vm_compute; reflexivity. Qed.

(* J(J+1) = 5 j(j+1), obtained from the general tower theorem at n = 5. *)
Theorem tower_identity_n5 :
  tower_J 5 * (tower_J 5 + 1) = 5 * tower_j 5 * (tower_j 5 + 1).
Proof.
  destruct tower_exact_n5 as [Hj HJ].
  exact (tower_spin_identity 5 (tower_j 5) (tower_J 5) eq_refl Hj HJ).
Qed.

Lemma tower_casimirs_n5 :
  tower_j 5 * (tower_j 5 + 1) = 6 /\ tower_J 5 * (tower_J 5 + 1) = 30.
Proof. split; vm_compute; reflexivity. Qed.

Lemma thirty_is_five_times_six : (30 = 5 * 6)%Z.
Proof. reflexivity. Qed.

(* The two Casimir values of the tower are exactly the two roots of
   K = (C-6)(C-30). *)
Lemma tower_casimirs_are_kernel_roots :
  lam (tower_j 5 * (tower_j 5 + 1)) = 0 /\ lam (tower_J 5 * (tower_J 5 + 1)) = 0.
Proof. split; vm_compute; reflexivity. Qed.

(* Kernel rank: 47 = F_5*F_5 + F_3*L_5 = 25 + 22. *)
Theorem kernel_rank_from_tower : fib 5 * fib 5 + fib 3 * luc 5 = 47.
Proof. vm_compute. reflexivity. Qed.

Lemma kernel_rank_split : fib 5 * fib 5 = 25 /\ fib 3 * luc 5 = 22.
Proof. split; vm_compute; reflexivity. Qed.

Definition D (n : nat) : Z := fib n * fib n + fib (n - 2) * luc n.

Theorem D_5 : D 5 = 47.
Proof. vm_compute. reflexivity. Qed.

(* The tower spins are exactly the kernel blocks of the weight algebra. *)
Theorem tower_spins_are_kernel_blocks :
  filter (fun j => Z.eqb (lam (Z.of_nat (casimir j))) 0) (seq 0 7)
  = [Z.to_nat (tower_j 5); Z.to_nat (tower_J 5)].
Proof. vm_compute. reflexivity. Qed.

(* mult 2 = F_5 and mult 5 = F_3. *)
Theorem multiplicities_are_fibonacci :
  Z.of_nat (mult (Z.to_nat (tower_j 5))) = fib 5 /\
  Z.of_nat (mult (Z.to_nat (tower_J 5))) = fib 3.
Proof. split; vm_compute; reflexivity. Qed.

(* Block dimensions: 2j+1 = F_5 and 2J+1 = L_5. *)
Theorem block_dimensions_are_fib_luc :
  (2 * tower_j 5 + 1 = fib 5 /\ 2 * tower_J 5 + 1 = luc 5)%Z.
Proof. exact tower_exact_n5. Qed.

(* Kernel rank computed from the weight algebra equals D(5), the tower number. *)
Theorem kernel_dim_is_D5 : Z.of_nat kernelDim = D 5.
Proof. vm_compute. reflexivity. Qed.

(* Term by term: multiplicity * block dimension = F * (F or L). *)
Theorem kernel_terms_match :
  Z.of_nat (mult 2 * (2 * 2 + 1)) = fib 5 * fib 5 /\
  Z.of_nat (mult 5 * (2 * 5 + 1)) = fib 3 * luc 5.
Proof. split; vm_compute; reflexivity. Qed.

(* General identity at the odd index m = 3 behind F_3 * L_5 = 22. *)
Theorem shift_identity_m3 : fib 3 * luc 5 = fib 4 * luc 4 + 1.
Proof. exact (fib_luc_shift_odd 3 eq_refl). Qed.

(* Bounded uniqueness: among n = 0..30, n = 5 is the only index where
   2j+1 = F_n and 2J+1 = L_n have integer solutions j, J (taken as floor
   halves) with both Casimir values j(j+1) and J(J+1) roots of K. *)
Definition both_kernel (n : nat) : bool :=
  Z.eqb (2 * tower_j n + 1) (fib n) &&
  Z.eqb (2 * tower_J n + 1) (luc n) &&
  Z.eqb (lam (tower_j n * (tower_j n + 1))) 0 &&
  Z.eqb (lam (tower_J n * (tower_J n + 1))) 0.

Theorem only_n5_below_31 :
  filter both_kernel (seq 0 31) = [5%nat].
Proof. vm_compute. reflexivity. Qed.

End TowerKernel.

Print Assumptions Tower.tower_spin_identity.
Print Assumptions Tower.fib_luc_shift_odd.
Print Assumptions TowerKernel.tower_identity_n5.
Print Assumptions TowerKernel.tower_casimirs_are_kernel_roots.
Print Assumptions TowerKernel.kernel_rank_from_tower.
Print Assumptions TowerKernel.D_5.
Print Assumptions TowerKernel.tower_spins_are_kernel_blocks.
Print Assumptions TowerKernel.multiplicities_are_fibonacci.
Print Assumptions TowerKernel.block_dimensions_are_fib_luc.
Print Assumptions TowerKernel.kernel_dim_is_D5.
Print Assumptions TowerKernel.kernel_terms_match.
Print Assumptions TowerKernel.shift_identity_m3.
Print Assumptions TowerKernel.only_n5_below_31.
