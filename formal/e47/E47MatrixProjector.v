(* Integer 125x125 sl2 model of three spin-2 particles, and the exact
   rank-47 projector built from its Casimir.
   Self-contained: Coq standard library only, no axioms, no Admitted.
   Companion to E47MatrixProjector.lean (see that file for what it covers).
   All matrix statements are closed computations (vm_compute) on explicit
   125x125 integer matrices stored as list (list Z).

   THE MODEL
   Per factor (spin 2, basis index k = 0..4 for m = 2-k, so m = 2,1,0,-1,-2):
     Jz = diag(2,1,0,-1,-2)
     Jm e_k = e_{k+1}                        (0/1 shift, lowering)
     Jp e_k = k(5-k) e_{k-1}                 (raising, entries (j-m)(j+m+1))
   These are the usual spin-2 operators after a diagonal rescaling of the basis,
   which removes every square root. The same rescaling D (x) D (x) D applied to
   the three-fold tensor product turns the normalized total ladders into
   the sums of the matrices above, so this model is similar to the real
   (Hermitian) one and all polynomial identities in the Casimir carry over.
   Total operators are Kronecker sums:  Jtot a = a(x)1(x)1 + 1(x)a(x)1 + 1(x)1(x)a.
   The Casimir is C = Jz^2 + Jz + Jm*Jp, an integer 125x125 matrix, and
   2C = 2Jz^2 + Jp*Jm + Jm*Jp.

   WHAT IS FORMALIZED HERE (each is a closed equality between explicit matrices)
   1. Dimensions: Jz, Jp, Jm, C are 125x125.
   2. sl2 relations on the 125-dim space: [Jz,Jp] = Jp, [Jz,Jm] = -Jm,
      [Jp,Jm] = 2Jz, and 2C = 2Jz^2 + Jp Jm + Jm Jp.
   3. The diagonal of Jz has the weight counts 19,18,15,10,6,3,1 for m = 0..6 and
      agrees with the weight function w of E47WeightAlgebra.v (restated here).
   4. Minimal polynomial identity: M(C) = 0 with
      M(x) = x(x-2)(x-6)(x-12)(x-20)(x-30)(x-42).
      So every eigenvalue of C is one of the seven Casimir values.
   5. A = C(C-2)(C-12)(C-20)(C-31)(C-42) (the integer matrix pr(C)) satisfies
      A*A = 1814400*A, trace A = 47*1814400, and K*A = 0 for K = (C-6)(C-30);
      A equals the expanded polynomial with coefficients 1,-107,4088,-66940,
      430848,-624960,0. So P = A/1814400 is an idempotent with K P = 0 and trace 47.
   6. Power traces trace(C^k), k = 0..6, equal sum_j mult_j (2j+1) (j(j+1))^k
      with the multiplicities 1,3,5,4,3,2,1 of the weight algebra.
   7. Spectral projectors: for each of the seven nodes c_i, with
      N_i = prod_{l<>i}(C - c_l I) and d_i = prod_{l<>i}(c_i - c_l):
      N_i*N_i = d_i*N_i, trace N_i = d_i * (mult_i (2 j_i + 1)), and
      sum_i (Dd/d_i) N_i = Dd*I for Dd = lcm of the |d_i|.
      So E_i = N_i/d_i are idempotents summing to I with traces
      1,9,25,28,27,22,13.

   WHAT IS NOT FORMALIZED
   - Rank equals trace for an idempotent, and "an integer matrix with M(C) = 0
     whose spectral idempotents have those traces has eigenvalue c_i with
     multiplicity trace(E_i)", are standard linear algebra, taken as input.
     Together with items 4-7 they give: C has exactly the eigenvalues
     0,2,6,12,20,30,42 with multiplicities 1,9,25,28,27,22,13, and
     rank P = rank ker K = 47.
   - That this integer model is similar to the Hermitian operators Jx, Jy, Jz
     checked numerically in simulation/e47_tqgnn/ is the explicit diagonal
     rescaling described above. That rescaling is not itself formalized, and
     neither is the identification of a complex Hermitian matrix with its
     real-integer similar form. Singular values and the 2-norm rate (15/17)^n are
     not proved here.
   - Nothing here uses the sl2 classification of irreducibles. The multiplicities
     are computed from the matrices, not assumed. *)

From Coq Require Import List ZArith Lia Nat.
Import ListNotations.
Open Scope Z_scope.

Module MatrixProjector.

(* ---------------- Integer matrices as list (list Z) ---------------- *)

Definition Mat := list (list Z).

Fixpoint dot (u v : list Z) : Z :=
  match u, v with
  | a :: u', b :: v' => a * b + dot u' v'
  | _, _ => 0
  end.

(* Transpose by columns; [n] is the number of columns. *)
Fixpoint transpose_n (n : nat) (M : Mat) : Mat :=
  match n with
  | O => []
  | S k => map (hd 0) M :: transpose_n k (map (tl (A:=Z)) M)
  end.

Definition mmul (A B : Mat) : Mat :=
  let Bt := transpose_n (length (hd [] B)) B in
  map (fun r => map (fun c => dot r c) Bt) A.

Definition zipw {X Y Z : Type} (f : X -> Y -> Z) (u : list X) (v : list Y) : list Z :=
  map (fun p => f (fst p) (snd p)) (combine u v).

Definition madd (A B : Mat) : Mat := zipw (fun r s => zipw Z.add r s) A B.
Definition mscale (k : Z) (A : Mat) : Mat := map (map (Z.mul k)) A.
Definition msub (A B : Mat) : Mat := madd A (mscale (-1) B).

Definition mk (n : nat) (f : nat -> nat -> Z) : Mat :=
  map (fun i => map (fun j => f i j) (seq 0 n)) (seq 0 n).

Definition ident (n : nat) : Mat := mk n (fun i j => if Nat.eqb i j then 1 else 0).

Definition diag (A : Mat) : list Z := map (fun i => nth i (nth i A []) 0) (seq 0 (length A)).
Definition mtrace (A : Mat) : Z := fold_right Z.add 0 (diag A).

Definition kron (A B : Mat) : Mat :=
  flat_map (fun ra => map (fun rb => flat_map (fun a => map (fun b => a * b) rb) ra) B) A.

Definition is_square (n : nat) (A : Mat) : bool :=
  Nat.eqb (length A) n && forallb (fun r => Nat.eqb (length r) n) A.

Definition mpow_poly (C : Mat) (roots : list Z) (n : nat) : Mat :=
  fold_left (fun R r => mmul R (msub C (mscale r (ident n)))) roots (ident n).

(* ---------------- The spin-2 factor and the three-fold sum ---------------- *)

Definition Jz5 : Mat :=
  [[2;0;0;0;0];[0;1;0;0;0];[0;0;0;0;0];[0;0;0;-1;0];[0;0;0;0;-2]].
(* Jp e_k = k(5-k) e_{k-1}: entry (k-1,k) = k(5-k) = 4,6,6,4 for k = 1..4. *)
Definition Jp5 : Mat :=
  [[0;4;0;0;0];[0;0;6;0;0];[0;0;0;6;0];[0;0;0;0;4];[0;0;0;0;0]].
(* Jm e_k = e_{k+1}. *)
Definition Jm5 : Mat :=
  [[0;0;0;0;0];[1;0;0;0;0];[0;1;0;0;0];[0;0;1;0;0];[0;0;0;1;0]].
Definition I5 : Mat := ident 5.

Definition Jtot (a : Mat) : Mat :=
  madd (madd (kron (kron a I5) I5) (kron (kron I5 a) I5)) (kron (kron I5 I5) a).

Definition Jz3 : Mat := Eval vm_compute in Jtot Jz5.
Definition Jp3 : Mat := Eval vm_compute in Jtot Jp5.
Definition Jm3 : Mat := Eval vm_compute in Jtot Jm5.

Lemma Jz3_def : Jz3 = Jtot Jz5.  Proof. vm_compute. reflexivity. Qed.
Lemma Jp3_def : Jp3 = Jtot Jp5.  Proof. vm_compute. reflexivity. Qed.
Lemma Jm3_def : Jm3 = Jtot Jm5.  Proof. vm_compute. reflexivity. Qed.

(* Casimir: C = Jz^2 + Jz + Jm*Jp. *)
Definition Cdef : Mat := madd (madd (mmul Jz3 Jz3) Jz3) (mmul Jm3 Jp3).
Definition C : Mat := Eval vm_compute in Cdef.
Lemma C_def : C = Cdef.  Proof. vm_compute. reflexivity. Qed.

Definition I125 : Mat := ident 125.
Definition zero125 : Mat := mscale 0 I125.

(* ---------------- 1. Dimensions ---------------- *)

Lemma dims_125 :
  is_square 125 Jz3 = true /\ is_square 125 Jp3 = true /\
  is_square 125 Jm3 = true /\ is_square 125 C = true.
Proof. vm_compute. repeat split; reflexivity. Qed.

(* ---------------- 2. sl2 relations on the 125-dim space ---------------- *)

Definition comm (X Y : Mat) : Mat := msub (mmul X Y) (mmul Y X).

Lemma sl2_zp : comm Jz3 Jp3 = Jp3.
Proof. vm_compute. reflexivity. Qed.

Lemma sl2_zm : comm Jz3 Jm3 = mscale (-1) Jm3.
Proof. vm_compute. reflexivity. Qed.

Lemma sl2_pm : comm Jp3 Jm3 = mscale 2 Jz3.
Proof. vm_compute. reflexivity. Qed.

(* 2C = 2 Jz^2 + Jp Jm + Jm Jp, the usual symmetric form of the Casimir. *)
Lemma casimir_symmetric_form :
  mscale 2 C = madd (mscale 2 (mmul Jz3 Jz3)) (madd (mmul Jp3 Jm3) (mmul Jm3 Jp3)).
Proof. vm_compute. reflexivity. Qed.

(* ---------------- 3. Weight counts from the diagonal of Jz ---------------- *)

Definition vals : list Z := [-2; -1; 0; 1; 2].
Definition triples : list (Z * Z * Z) :=
  flat_map (fun a => flat_map (fun b => map (fun c => (a, b, c)) vals) vals) vals.
Definition tsum (t : Z * Z * Z) : Z := (fst (fst t) + snd (fst t) + snd t).
Definition w (m : Z) : nat := length (filter (fun t => Z.eqb (tsum t) m) triples).
Definition mult (j : nat) : nat := w (Z.of_nat j) - w (Z.of_nat (S j)).

Definition wdiag (m : Z) : nat := length (filter (fun x => Z.eqb x m) (diag Jz3)).

Lemma jz_diagonal_weight_counts :
  map (fun j => wdiag (Z.of_nat j)) (seq 0 7) = [19; 18; 15; 10; 6; 3; 1]%nat.
Proof. vm_compute. reflexivity. Qed.

Lemma jz_diagonal_matches_weight_algebra :
  map (fun j => wdiag (Z.of_nat j)) (seq 0 7) = map (fun j => w (Z.of_nat j)) (seq 0 7).
Proof. vm_compute. reflexivity. Qed.

Lemma jz_is_diagonal : Jz3 = mk 125 (fun i j => if Nat.eqb i j then nth i (diag Jz3) 0 else 0).
Proof. vm_compute. reflexivity. Qed.

(* ---------------- 4. Minimal polynomial ---------------- *)

Definition nodes : list Z := [0; 2; 6; 12; 20; 30; 42].

Theorem minimal_polynomial : mpow_poly C nodes 125 = zero125.
Proof. vm_compute. reflexivity. Qed.

(* ---------------- 5. The exact projector A = pr(C) ---------------- *)

Definition A : Mat := Eval vm_compute in mpow_poly C [0; 2; 12; 20; 31; 42] 125.
Lemma A_def : A = mpow_poly C [0; 2; 12; 20; 31; 42] 125.
Proof. vm_compute. reflexivity. Qed.

Definition K : Mat := mpow_poly C [6; 30] 125.

Theorem projector_idempotent : mmul A A = mscale 1814400 A.
Proof. vm_compute. reflexivity. Qed.

Theorem projector_trace : mtrace A = 47 * 1814400.
Proof. vm_compute. reflexivity. Qed.

Theorem projector_kills_K : mmul K A = zero125.
Proof. vm_compute. reflexivity. Qed.

(* A is the expanded polynomial x^6 - 107x^5 + 4088x^4 - 66940x^3 + 430848x^2
   - 624960x evaluated at C. *)
Fixpoint mpow (X : Mat) (k : nat) : Mat :=
  match k with O => I125 | S k' => mmul X (mpow X k') end.

Definition Aexp : Mat :=
  madd (mpow C 6)
  (madd (mscale (-107) (mpow C 5))
  (madd (mscale 4088 (mpow C 4))
  (madd (mscale (-66940) (mpow C 3))
  (madd (mscale 430848 (mpow C 2))
        (mscale (-624960) C))))).

Theorem projector_expanded : A = Aexp.
Proof. vm_compute. reflexivity. Qed.

(* ---------------- 6. Power traces against the weight algebra ---------------- *)

Definition spectrum_power_sum (k : nat) : Z :=
  fold_right Z.add 0
    (map (fun j => Z.of_nat (mult j * (2 * j + 1)) * (Z.of_nat (j * (j + 1))) ^ Z.of_nat k)
         (seq 0 7)).

Theorem power_traces_match_weight_algebra :
  map (fun k => mtrace (mpow C k)) (seq 0 7) = map spectrum_power_sum (seq 0 7).
Proof. vm_compute. reflexivity. Qed.

Lemma power_trace_values :
  map (fun k => mtrace (mpow C k)) (seq 0 7) =
  [125; 2250; 58500; 1827000; 63205200; 2327148000; 89208187200].
Proof. vm_compute. reflexivity. Qed.

(* ---------------- 7. Spectral projectors ---------------- *)

(* N_i = prod_{l <> i} (C - c_l I), d_i = prod_{l <> i} (c_i - c_l). *)
Definition others (i : nat) : list Z :=
  map snd (filter (fun p => negb (Nat.eqb (fst p) i)) (combine (seq 0 7) nodes)).
Definition node (i : nat) : Z := nth i nodes 0.
Definition dcoef (i : nat) : Z := fold_left (fun a c => a * (node i - c)) (others i) 1.
Definition Nmat (i : nat) : Mat := mpow_poly C (others i) 125.
Definition blockdim (i : nat) : Z := Z.of_nat (mult i * (2 * i + 1)).

Definition Dd : Z := 479001600.   (* = 12! = lcm of the |d_i| *)

Lemma dcoefs : map dcoef (seq 0 7) =
  [3628800; -1612800; 1741824; -3110400; 8870400; -43545600; 479001600].
Proof. vm_compute. reflexivity. Qed.

Lemma Dd_is_lcm : Dd = fold_right Z.lcm 1 (map (fun i => Z.abs (dcoef i)) (seq 0 7)).
Proof. vm_compute. reflexivity. Qed.

Definition Nlist : list Mat := Eval vm_compute in map Nmat (seq 0 7).
Lemma Nlist_def : Nlist = map Nmat (seq 0 7).
Proof. vm_compute. reflexivity. Qed.

Theorem spectral_idempotents :
  map (fun N => mmul N N) Nlist = map (fun p => mscale (dcoef (fst p)) (snd p)) (combine (seq 0 7) Nlist).
Proof. vm_compute. reflexivity. Qed.

Theorem spectral_traces :
  map mtrace Nlist = map (fun i => dcoef i * blockdim i) (seq 0 7).
Proof. vm_compute. reflexivity. Qed.

(* Dividing out d_i: the idempotents E_i = N_i / d_i have traces
   mult_i * (2 j_i + 1) = 1, 9, 25, 28, 27, 22, 13. *)
Lemma spectral_dimensions :
  map blockdim (seq 0 7) = [1; 9; 25; 28; 27; 22; 13].
Proof. vm_compute. reflexivity. Qed.

Theorem resolution_of_identity :
  fold_right madd zero125
    (map (fun p => mscale (Dd / dcoef (fst p)) (snd p)) (combine (seq 0 7) Nlist))
  = mscale Dd I125.
Proof. vm_compute. reflexivity. Qed.

Lemma Dd_divisible : forallb (fun i => Z.eqb (Dd mod dcoef i) 0) (seq 0 7) = true.
Proof. vm_compute. reflexivity. Qed.

Theorem total_dimension : fold_right Z.add 0 (map blockdim (seq 0 7)) = 125.
Proof. vm_compute. reflexivity. Qed.

(* A is 1814400 (E_2 + E_5), E_i = N_i/d_i. Cleared of denominators:
   d_2 d_5 A = 1814400 (d_5 N_2 + d_2 N_5). *)
Theorem projector_from_spectral_idempotents :
  mscale (dcoef 2 * dcoef 5) A =
  mscale 1814400
    (madd (mscale (dcoef 5) (nth 2 Nlist [])) (mscale (dcoef 2) (nth 5 Nlist []))).
Proof. vm_compute. reflexivity. Qed.

End MatrixProjector.

Print Assumptions MatrixProjector.dims_125.
Print Assumptions MatrixProjector.sl2_zp.
Print Assumptions MatrixProjector.sl2_zm.
Print Assumptions MatrixProjector.sl2_pm.
Print Assumptions MatrixProjector.casimir_symmetric_form.
Print Assumptions MatrixProjector.jz_diagonal_matches_weight_algebra.
Print Assumptions MatrixProjector.minimal_polynomial.
Print Assumptions MatrixProjector.projector_idempotent.
Print Assumptions MatrixProjector.projector_trace.
Print Assumptions MatrixProjector.projector_kills_K.
Print Assumptions MatrixProjector.projector_expanded.
Print Assumptions MatrixProjector.power_traces_match_weight_algebra.
Print Assumptions MatrixProjector.spectral_idempotents.
Print Assumptions MatrixProjector.spectral_traces.
Print Assumptions MatrixProjector.resolution_of_identity.
Print Assumptions MatrixProjector.projector_from_spectral_idempotents.
