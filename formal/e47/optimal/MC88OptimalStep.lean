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


/-- Any rational step whose two signed endpoint residuals are both at
    most the sharp 15/17 bound must equal 1/99144 after cancellation.
    The statement is exact integer arithmetic, with no real-valued
    approximation and no assumptions on the concrete Casimir matrix. -/
theorem rational_sharp_step_unique (p q : Int)
    (hleft : 17 * (q - gamma * p) ≤ 15 * q)
    (hright : 17 * (lambdaMax * p - q) ≤ 15 * q) :
    q = qStar * p := by
  dsimp [gamma, lambdaMax, qStar] at *
  omega

/-- The two endpoint residuals cannot simultaneously be strictly below
    the minimax threshold. This excludes any strictly better rational
    Richardson step by exact linear integer arithmetic. -/
theorem rational_no_strict_endpoint_improvement (p q : Int) :
    ¬ (17 * (q - gamma * p) < 15 * q ∧
       17 * (lambdaMax * p - q) < 15 * q) := by
  dsimp [gamma, lambdaMax]
  omega

/-- With positive rational denominator, the two absolute endpoint
    residuals are both at most 15/17 iff the represented step equals
    1/99144. The equality q = 99144*p is invariant under rescaling
    the numerator and denominator. -/
theorem rational_sharp_endpoints_iff (p q : Int) (_hq : 0 < q) :
    ((-15 * q ≤ 17 * (q - gamma * p) ∧
       17 * (q - gamma * p) ≤ 15 * q) ∧
      (-15 * q ≤ 17 * (q - lambdaMax * p) ∧
       17 * (q - lambdaMax * p) ≤ 15 * q))
      ↔ q = qStar * p := by
  dsimp [gamma, lambdaMax, qStar]
  constructor
  · intro h
    omega
  · intro h
    omega

end MC88OptimalStep

#print axioms MC88OptimalStep.denominator_identity
#print axioms MC88OptimalStep.admissible_step
#print axioms MC88OptimalStep.endpoint_equioscillation
#print axioms MC88OptimalStep.five_modes_within_sharp_bound
#print axioms MC88OptimalStep.rational_minimax_lower_bound
#print axioms MC88OptimalStep.rational_sharp_step_unique
#print axioms MC88OptimalStep.rational_no_strict_endpoint_improvement
#print axioms MC88OptimalStep.rational_sharp_endpoints_iff
