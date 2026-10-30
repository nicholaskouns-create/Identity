import Mathlib

/-!
# E47 29-unit arithmetic certificate

These statements verify dimension accounting only. They do not establish
the SU(2)-equivariant decomposition or the Schur-lemma commutant isomorphism.
-/

namespace E47Kernel29

def carrierDim : ℕ := 5 ^ 3
def selectedDim : ℕ := 5 * 5 + 2 * 11
def intertwinerDim : ℕ := 5 ^ 2 + 2 ^ 2
def logicalDim : ℕ := 2
def logicalOperatorDim : ℕ := logicalDim ^ 2

theorem carrier_eq : carrierDim = 125 := by
  norm_num [carrierDim]

theorem selected_eq : selectedDim = 47 := by
  norm_num [selectedDim]

theorem intertwiner_eq : intertwinerDim = 29 := by
  norm_num [intertwinerDim]

theorem qubit_algebra_eq : logicalOperatorDim = 4 := by
  norm_num [logicalOperatorDim, logicalDim]

end E47Kernel29

#print axioms E47Kernel29.carrier_eq
#print axioms E47Kernel29.selected_eq
#print axioms E47Kernel29.intertwiner_eq
#print axioms E47Kernel29.qubit_algebra_eq
