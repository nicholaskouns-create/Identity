/- E47 Proof Forge: exact scalar multiplicity/rank facts.
   Does not certify the concrete 125x125 Casimir or clock calibration. -/
namespace E47ProofForge
def carrierDimension : Nat := 1 + 9 + 25 + 28 + 27 + 22 + 13
def selectedDimension : Nat := 25 + 22
theorem carrier_dimension : carrierDimension = 125 := by decide
theorem selected_dimension : selectedDimension = 47 := by decide
theorem selected_is_bounded : selectedDimension ≤ carrierDimension := by decide
end E47ProofForge
