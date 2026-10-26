(* Commutant dimension of the E47 kernel, from the same weight counts.
   Self-contained: Coq standard library only, no axioms, no Admitted.
   Companion to E47Commutant.lean (same statements).

   WHAT IS FORMALIZED HERE
   - The weight counts w and multiplicities mult are re-derived here exactly as
     in E47WeightAlgebra, so this file stands alone: mult j = w j - w (j+1),
     evaluating to 1,3,5,4,3,2,1 for j = 0..6.
   - The Casimir filter K = (C-6)(C-30) annihilates exactly the spin-2 and
     spin-5 blocks, so the retained spins are {2, 5} with mult 2 = 5, mult 5 = 2.
   - kernelDim = mult 2 * 5 + mult 5 * 11 = 25 + 22 = 47.
   - commutantDim = mult 2 ^ 2 + mult 5 ^ 2 = 25 + 4 = 29.
   - carrierCommutantDim = sum_j (mult j)^2 = 65.
   - stateGeometryDim = commutantDim - 1 = 28.
   - The two discrepancies against plate RUB5-C17, stated as inequalities:
     commutantDim <> 25 and stateGeometryDim <> 24.

   WHAT IS NOT FORMALIZED
   - No operator, matrix or algebra is defined in this file. Nothing here is a
     theorem about M_5(C), M_2(C) or any commutant as an algebra; the names are
     descriptive only.
   - The following standard facts are taken as textbook input and appear only in
     this comment, not as axioms, exactly as in E47WeightAlgebra:
       (i)   a finite-dimensional sl2 module splits into irreducible ladders, so
             the number of spin-j summands is dim(weight j) - dim(weight j+1);
       (ii)  the Casimir acts as j(j+1) on a spin-j summand;
       (iii) (double commutant / Schur) for a multiplicity-space decomposition
             V = (+)_j V_j (x) C^{m_j}, the algebra of operators commuting with
             the group action is (+)_j M_{m_j}(C), of dimension sum_j m_j^2,
             and no block off the diagonal survives because V_j and V_k are
             inequivalent for j <> k.
     Given (i)-(iii), the numbers proved here are exactly the commutant
     dimension and the dimension of its unit-trace state body. The commutant was
     additionally computed numerically, as the nullity of the adjoint-action
     Casimir superoperator on End(E47), in
     E47-Kartekeya/certificates/rub5_c17_descent_derivation.py (result 29). *)

From Coq Require Import List ZArith Lia Nat.
Import ListNotations.

Module Commutant.

Definition vals : list Z := [-2; -1; 0; 1; 2]%Z.

(* Basis of the carrier: m-values of the three spin-2 factors. *)
Definition triples : list (Z * Z * Z) :=
  flat_map (fun a => flat_map (fun b => map (fun c => (a, b, c)) vals) vals) vals.

Definition tsum (t : Z * Z * Z) : Z := (fst (fst t) + snd (fst t) + snd t)%Z.

(* Weight count: number of basis triples with total Jz = m. *)
Definition w (m : Z) : nat :=
  length (filter (fun t => Z.eqb (tsum t) m) triples).

(* Highest-weight multiplicity of spin j. *)
Definition mult (j : nat) : nat := w (Z.of_nat j) - w (Z.of_nat (j + 1)).

(* Dimension of the spin-j irreducible. *)
Definition irrepDim (j : nat) : nat := 2 * j + 1.

Definition spins : list nat := [0; 1; 2; 3; 4; 5; 6].

(* Spins retained by K = (C-6)(C-30): those with j(j+1) in {6, 30}. *)
Definition retained : list nat :=
  filter (fun j => orb (Nat.eqb (j * (j + 1)) 6) (Nat.eqb (j * (j + 1)) 30)) spins.

(* ### 1. The carrier, restated *)

Theorem basis_size : length triples = 125.
Proof. reflexivity. Qed.

Theorem multiplicities : map mult spins = [1; 3; 5; 4; 3; 2; 1].
Proof. reflexivity. Qed.

Theorem dimension_identity :
  fold_right Nat.add 0 (map (fun j => mult j * irrepDim j) spins) = 125.
Proof. reflexivity. Qed.

(* ### 2. The retained blocks *)

Theorem retained_spins : retained = [2; 5].
Proof. reflexivity. Qed.

Theorem retained_multiplicities : mult 2 = 5 /\ mult 5 = 2.
Proof. split; reflexivity. Qed.

Definition kernelDim : nat :=
  fold_right Nat.add 0 (map (fun j => mult j * irrepDim j) retained).

Theorem kernel_dim_value : kernelDim = 47.
Proof. reflexivity. Qed.

Theorem kernel_dim_splits : kernelDim = 25 + 22.
Proof. reflexivity. Qed.

(* ### 3. Commutant dimension *)

(* Dimension of the algebra commuting with the group action on the retained
   blocks: the sum of squared multiplicities. *)
Definition commutantDim : nat :=
  fold_right Nat.add 0 (map (fun j => mult j * mult j) retained).

Theorem commutant_dim_value : commutantDim = 29.
Proof. reflexivity. Qed.

(* The two blocks contributing to it: 5^2 from spin 2, 2^2 from spin 5. *)
Theorem commutant_dim_splits : commutantDim = 25 + 4.
Proof. reflexivity. Qed.

(* Same law applied to the whole carrier rather than the kernel. *)
Definition carrierCommutantDim : nat :=
  fold_right Nat.add 0 (map (fun j => mult j * mult j) spins).

Theorem carrier_commutant_dim_value : carrierCommutantDim = 65.
Proof. reflexivity. Qed.

(* ### 4. State geometry *)

(* Real affine dimension of the unit-trace body of the commutant. *)
Definition stateGeometryDim : nat := commutantDim - 1.

Theorem state_geometry_dim_value : stateGeometryDim = 28.
Proof. reflexivity. Qed.

(* Its decomposition: 24 from the spin-2 block, 3 from the spin-5 block,
   and 1 for the population split between them. *)
Theorem state_geometry_splits : stateGeometryDim = 24 + 3 + 1.
Proof. reflexivity. Qed.

(* ### 5. Discrepancies against plate RUB5-C17 *)

(* The plate's terminal algebra M_5(C) alone would have dimension 25. *)
Theorem commutant_exceeds_single_block : commutantDim <> 25.
Proof. unfold commutantDim; simpl; lia. Qed.

Theorem commutant_excess : commutantDim - 25 = 4.
Proof. reflexivity. Qed.

(* The plate's declared 24-dimensional state geometry is the spin-2 block only. *)
Theorem state_geometry_exceeds_single_block : stateGeometryDim <> 24.
Proof. unfold stateGeometryDim, commutantDim; simpl; lia. Qed.

Theorem state_geometry_excess : stateGeometryDim - 24 = 4.
Proof. reflexivity. Qed.

(* The dropped block is one qubit: multiplicity 2. *)
Theorem dropped_block_is_a_qubit : mult 5 = 2.
Proof. reflexivity. Qed.

End Commutant.
