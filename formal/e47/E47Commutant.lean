/-
  Commutant dimension of the E47 kernel, from the same weight counts.
  Self-contained: core Lean 4 only, no Mathlib, no declared axioms, no sorry.
  Companion to E47Commutant.v (same statements).

  WHAT IS FORMALIZED HERE
  * The weight counts w and multiplicities mult are re-derived here exactly as
    in E47WeightAlgebra, so this file stands alone: mult j = w j - w (j+1),
    evaluating to 1,3,5,4,3,2,1 for j = 0..6.
  * The Casimir filter K = (C-6)(C-30) annihilates exactly the spin-2 and
    spin-5 blocks, so the retained spins are {2, 5} with mult 2 = 5, mult 5 = 2.
  * kernelDim = mult 2 * 5 + mult 5 * 11 = 25 + 22 = 47.
  * commutantDim = mult 2 ^ 2 + mult 5 ^ 2 = 25 + 4 = 29.
  * carrierCommutantDim = sum_j (mult j)^2 = 65.
  * stateGeometryDim = commutantDim - 1 = 28.
  * The two discrepancies against plate RUB5-C17, stated as inequalities:
    commutantDim <> 25 and stateGeometryDim <> 24.

  WHAT IS NOT FORMALIZED
  * No operator, matrix or algebra is defined in this file. Nothing here is a
    theorem about M_5(C), M_2(C) or any commutant as an algebra; the names are
    descriptive only.
  * The following standard facts are taken as textbook input and appear only in
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
    E47-Kartekeya/certificates/rub5_c17_descent_derivation.py (result 29).
-/

namespace Commutant

def vals : List Int := [-2, -1, 0, 1, 2]

set_option maxRecDepth 100000

/-- Basis of the carrier: m-values of the three spin-2 factors. -/
def triples : List (Int × Int × Int) :=
  vals.flatMap fun a => vals.flatMap fun b => vals.map fun c => (a, b, c)

/-- Weight count: number of basis triples with total Jz = m. -/
def w (m : Int) : Nat :=
  triples.countP fun t => decide (t.1 + t.2.1 + t.2.2 = m)

/-- Highest-weight multiplicity of spin j. -/
def mult (j : Nat) : Nat := w j - w (j + 1)

/-- Dimension of the spin-j irreducible. -/
def irrepDim (j : Nat) : Nat := 2 * j + 1

/-- Spins retained by K = (C-6)(C-30): those with j(j+1) in {6, 30}. -/
def retained : List Nat := (List.range 7).filter fun j => j * (j + 1) == 6 || j * (j + 1) == 30

/-! ### 1. The carrier, restated -/

theorem basis_size : triples.length = 125 := by decide

theorem multiplicities :
    (List.range 7).map mult = [1, 3, 5, 4, 3, 2, 1] := by
  decide

theorem dimension_identity :
    ((List.range 7).map fun j => mult j * irrepDim j).sum = 125 := by
  decide

/-! ### 2. The retained blocks -/

theorem retained_spins : retained = [2, 5] := by decide

theorem retained_multiplicities : mult 2 = 5 ∧ mult 5 = 2 := by decide

/-- Kernel dimension, from the weight counts. -/
def kernelDim : Nat := (retained.map fun j => mult j * irrepDim j).sum

theorem kernel_dim_value : kernelDim = 47 := by decide

theorem kernel_dim_splits : kernelDim = 25 + 22 := by decide

/-! ### 3. Commutant dimension -/

/-- Dimension of the algebra commuting with the group action on the retained
    blocks: the sum of squared multiplicities. -/
def commutantDim : Nat := (retained.map fun j => mult j * mult j).sum

theorem commutant_dim_value : commutantDim = 29 := by decide

/-- The two blocks contributing to it: 5^2 from spin 2, 2^2 from spin 5. -/
theorem commutant_dim_splits : commutantDim = 25 + 4 := by decide

/-- Same law applied to the whole carrier rather than the kernel. -/
def carrierCommutantDim : Nat := ((List.range 7).map fun j => mult j * mult j).sum

theorem carrier_commutant_dim_value : carrierCommutantDim = 65 := by decide

/-! ### 4. State geometry -/

/-- Real affine dimension of the unit-trace body of the commutant. -/
def stateGeometryDim : Nat := commutantDim - 1

theorem state_geometry_dim_value : stateGeometryDim = 28 := by decide

/-- Its decomposition: 24 from the spin-2 block, 3 from the spin-5 block,
    and 1 for the population split between them. -/
theorem state_geometry_splits : stateGeometryDim = 24 + 3 + 1 := by decide

/-! ### 5. Discrepancies against plate RUB5-C17 -/

/-- The plate's terminal algebra M_5(C) alone would have dimension 25. -/
theorem commutant_exceeds_single_block : commutantDim ≠ 25 := by decide

theorem commutant_excess : commutantDim - 25 = 4 := by decide

/-- The plate's declared 24-dimensional state geometry is the spin-2 block only. -/
theorem state_geometry_exceeds_single_block : stateGeometryDim ≠ 24 := by decide

theorem state_geometry_excess : stateGeometryDim - 24 = 4 := by decide

/-- The dropped block is one qubit: multiplicity 2. -/
theorem dropped_block_is_a_qubit : mult 5 = 2 := by decide

#print axioms basis_size
#print axioms multiplicities
#print axioms dimension_identity
#print axioms retained_spins
#print axioms retained_multiplicities
#print axioms kernel_dim_value
#print axioms kernel_dim_splits
#print axioms commutant_dim_value
#print axioms commutant_dim_splits
#print axioms carrier_commutant_dim_value
#print axioms state_geometry_dim_value
#print axioms state_geometry_splits
#print axioms commutant_exceeds_single_block
#print axioms commutant_excess
#print axioms state_geometry_exceeds_single_block
#print axioms state_geometry_excess
#print axioms dropped_block_is_a_qubit

end Commutant
