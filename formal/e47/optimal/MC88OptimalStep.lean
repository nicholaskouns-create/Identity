/- MC-88 Discrete Filter Optimal-Step Theorem: rational minimax certificate.
   Provenance: Notion Roll MC-88, City Proof 88.
   The five numbers are the positive K^2 eigenvalues supplied by the
   independent spectral census, NOT a theorem identifying eigenspaces of
   the concrete 125x125 Casimir.
   The minimax theorem is over rational steps p/q with q>0, represented
   by integer cross-multiplication; no real-analysis theorem is claimed. -/
import Lean

namespace MC88OptimalStep

def gamma : Int := 11664
def lambdaMax : Int := 186624
def qStar : Int := 99144
def positiveSpectrum : List Int := [11664, 12544, 19600, 32400, 186624]

/-- The optimal rational step has denominator (gamma+Lambda)/2. -/
theorem denominator_identity : gamma + lambdaMax = 2 * qStar := by decide

/-- The step 1/qStar lies strictly inside the Richardson stability interval. -/
theorem admissible_step : 0 < qStar ∧ lambdaMax < 2 * qStar := by decide

/-- Both endpoint errors have magnitude exactly 15/17 at p/q=1/qStar. -/
theorem endpoint_equioscillation :
    17 * (qStar - gamma) = 15 * qStar ∧
    17 * (lambdaMax - qStar) = 15 * qStar := by decide

/-- Every one of the five declared positive modes meets the sharp bound. -/
theorem five_modes_within_sharp_bound :
    (positiveSpectrum.all fun lam =>
      decide ((-15 * qStar : Int) ≤ 17 * (qStar - lam) ∧
              17 * (qStar - lam) ≤ 15 * qStar)) = true := by decide

/-- For any rational step p/q with q>0, at least one signed endpoint
    residual is >= (15/17)q after multiplying through by 17.
    Hence the maximum absolute endpoint error cannot be below 15/17.
    This is an exact integer certificate, not a floating-point search. -/
theorem rational_minimax_lower_bound (p q : Int) (_hq : 0 < q) :
    15 * q ≤ 17 * (q - gamma * p) ∨
    15 * q ≤ 17 * (lambdaMax * p - q) := by
  dsimp [gamma, lambdaMax]
  omega

end MC88OptimalStep

#print axioms MC88OptimalStep.denominator_identity
#print axioms MC88OptimalStep.admissible_step
#print axioms MC88OptimalStep.endpoint_equioscillation
#print axioms MC88OptimalStep.five_modes_within_sharp_bound
#print axioms MC88OptimalStep.rational_minimax_lower_bound
