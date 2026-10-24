/- E47-RET-003: integer polynomial and retention identity at a sample root.
   The real root of x^10-x-1 is NOT certified by this finite arithmetic file. -/
namespace E47Unified
def polynomialAt (x : Nat) : Int := (x ^ 10 : Nat) - (x : Int) - 1
theorem polynomial_at_one : polynomialAt 1 = -1 := by decide
theorem polynomial_at_two_positive : 0 < polynomialAt 2 := by decide
theorem corrected_degree_ten : 2 ^ 10 = 1024 := by decide
end E47Unified
