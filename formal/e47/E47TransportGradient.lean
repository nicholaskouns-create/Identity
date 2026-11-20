/-!
E47 transport-gradient: an exact algebraic 2-mode witness and carrier census.
This is a finite 2-mode instance of the skew + dissipation equations,
NOT a proof of all operator assertions for the 47x47 concrete matrix.
Lean 4 core, no Mathlib and no axioms.
-/
namespace E47Transport
theorem spin2_triple_dimension : 1 + 9 + 25 + 28 + 27 + 22 + 13 = 125 := by decide
theorem protected_dimension : 25 + 22 = 47 := by decide
theorem complementary_dimension : 125 - 47 = 78 := by decide
theorem contraction_bound_fraction : 15 * 17 < 17 * 17 := by decide
theorem skew_integer_witness : (3 : Int) * (-4) + 4 * 3 = 0 := by decide
theorem dissipative_integer_witness :
    (2 : Int) * 3 * (-4 - 2 * 3) + 2 * 4 * (3 - 2 * 4) = -104 := by decide
end E47Transport
