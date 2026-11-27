/- LERI exact finite-sector certificate. Lean 4 core only.
   This proves arithmetic consequences of the listed sector data;
   the construction of the 125x125 spin matrices is separately tested
   by leri/validate.py. -/
namespace LERI
def carrierDim : Nat := 125
def e47Dim : Nat := 47
def canonicalDim : Nat := 5
def symmetricDim : Nat := 35
def gap : Nat := 11664
def maxEigen : Nat := 186624
def stepDenominator : Nat := 99144

theorem dimension_split : e47Dim + 78 = carrierDim := by decide
theorem canonical_inside_e47 : canonicalDim < e47Dim := by decide
theorem symmetric_sector_dimension : 1 + 5 + 7 + 9 + 13 = symmetricDim := by decide
theorem total_joint_sector_dimension :
    1 + 9 + 5 + 20 + 7 + 21 + 9 + 18 + 22 + 13 = carrierDim := by decide
theorem canonical_zero_multiplicity : 5 + 49 + 9 + 21 + 9 + 18 + 1 + 13 = carrierDim := by decide
theorem adjoint_multipoles : 1 + 3 + 5 + 7 + 9 = 25 := by decide
theorem density_affine_dimension : 5 * 5 - 1 = 24 := by decide
theorem spectral_midpoint : gap + maxEigen = 2 * stepDenominator := by decide
theorem low_endpoint_factor : 17 * (stepDenominator - gap) = 15 * stepDenominator := by decide
theorem high_endpoint_factor : 17 * (maxEigen - stepDenominator) = 15 * stepDenominator := by decide
theorem zero_sector : ((6 - 6) * (30 - 6)) * ((6 - 6) * (30 - 6)) = 0 := by decide
theorem gap_strict : 0 < gap := by decide
theorem max_exceeds_gap : gap < maxEigen := by decide
theorem exact_omega : 47 * 1000 = 376 * 125 := by decide
end LERI
