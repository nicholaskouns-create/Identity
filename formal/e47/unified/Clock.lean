/- E47-TIME-004: positivity of a discrete surrogate clock rate.
   This does NOT certify exp(psi) or a Lorentzian proper-time metric. -/
namespace E47Unified
def surrogateRate (n : Nat) : Nat := 1 + n*n
theorem surrogate_rate_positive (n : Nat) : 0 < surrogateRate n := by
  simp [surrogateRate, Nat.add_comm]
theorem sample_rate : surrogateRate 3 = 10 := by decide
end E47Unified
