import Mathlib

/-!
# E47: concrete 125 × 125 spin-2 Casimir

This is an **integer matrix**, in the tensor-product weight basis.
No eigenspaces, multiplicities, or spectra are assumed as hypotheses.

The nonorthonormal basis uses the exact spin-2 representation:
  J₊|k⟩ = k(5-k)|k-1⟩,   J₋|k⟩ = |k+1⟩,   J_z|k⟩ = (2-k)|k⟩.
The total operators are sums over all three tensor factors.
C = J_z² + J_z + J₋J₊, the total su(2) Casimir.

The scaled spectral projector is a degree-six integer polynomial in C,
and is checked as an actual matrix rather than a list of eigenvalues.

Proof search uses native_decide on finite integer matrix equalities. The
proofs contain no axioms, sorry, or admitted intermediate claims.

NOTE: This source is submitted as a candidate for CI compilation; do
not report the matrix theorems as compiler-accepted until CI is green.
-/

namespace E47Concrete

abbrev M := Matrix (Fin 125) (Fin 125) ℤ

private def d₀ (i : Fin 125) : Nat := i.val / 25
private def d₁ (i : Fin 125) : Nat := i.val / 5 % 5
private def d₂ (i : Fin 125) : Nat := i.val % 5

private def weight (k : Nat) : ℤ := 2 - (k : ℤ)
private def coeff (k : Nat) : ℤ := ((k * (5-k) : Nat) : ℤ)

def z : M := fun i j =>
  if i = j then weight (d₀ i) + weight (d₁ i) + weight (d₂ i) else 0

def up : M := fun i j =>
  (if d₀ i + 1 = d₀ j ∧ d₁ i = d₁ j ∧ d₂ i = d₂ j
    then coeff (d₀ j) else 0) +
  (if d₁ i + 1 = d₁ j ∧ d₀ i = d₀ j ∧ d₂ i = d₂ j
    then coeff (d₁ j) else 0) +
  (if d₂ i + 1 = d₂ j ∧ d₀ i = d₀ j ∧ d₁ i = d₁ j
    then coeff (d₂ j) else 0)

def down : M := fun i j =>
  (if d₀ i = d₀ j + 1 ∧ d₁ i = d₁ j ∧ d₂ i = d₂ j then 1 else 0) +
  (if d₁ i = d₁ j + 1 ∧ d₀ i = d₀ j ∧ d₂ i = d₂ j then 1 else 0) +
  (if d₂ i = d₂ j + 1 ∧ d₀ i = d₀ j ∧ d₁ i = d₁ j then 1 else 0)

def scalar (a : ℤ) : M := a • (1 : M)
def casimir : M := z * z + z + down * up
def kernelOperator : M := (casimir - scalar 6) * (casimir - scalar 30)

/-!
The integer polynomial (1,814,400) P(C) equals
C⁶ - 107 C⁵ + 4088 C⁴ - 66940 C³ + 430848 C² - 624960 C.
Its values are 1,814,400 at Casimir nodes 6 and 30, and zero at
nodes 0,2,12,20,42.
-/
def selector (x : M) : M :=
  x * (x * (x * (x * (x * (x + scalar (-107)) +
    scalar 4088) + scalar (-66940)) + scalar 430848) +
    scalar (-624960))

def projectorNumerator : M := selector casimir

/-! All claims below concern the explicit 125-by-125 matrices above. -/

set_option maxRecDepth 100000 in
set_option maxHeartbeats 0 in
theorem casimir_annihilator :
    (casimir - scalar 0) * (casimir - scalar 2) *
    (casimir - scalar 6) * (casimir - scalar 12) *
    (casimir - scalar 20) * (casimir - scalar 30) *
    (casimir - scalar 42) = 0 := by
  native_decide

set_option maxRecDepth 100000 in
set_option maxHeartbeats 0 in
theorem scaled_projector_is_idempotent :
    projectorNumerator * projectorNumerator =
      (1814400 : ℤ) • projectorNumerator := by
  native_decide

set_option maxRecDepth 100000 in
set_option maxHeartbeats 0 in
theorem selected_subspace_is_kernel :
    kernelOperator * projectorNumerator = 0 := by
  native_decide

set_option maxRecDepth 100000 in
set_option maxHeartbeats 0 in
theorem scaled_projector_trace :
    Matrix.trace projectorNumerator = (47 : ℤ) * 1814400 := by
  native_decide

/-! Explicit polynomial Bézout complement to (C-6)(C-30). -/
def bezoutQuotient (x : M) : M :=
  -(x * (x * (x * (x - scalar 71) + scalar 1352) -
      scalar 5488)) + scalar 10080

set_option maxRecDepth 100000 in
set_option maxHeartbeats 0 in
theorem kernel_bezout :
    projectorNumerator +
      kernelOperator * bezoutQuotient casimir =
        scalar 1814400 := by
  native_decide

end E47Concrete
