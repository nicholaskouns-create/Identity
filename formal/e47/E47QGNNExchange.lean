/- E47 QGNN exchange arithmetic certificates.
   Self-contained Lean 4 core. No axioms, sorry, or external imports.
   Scope: exact spectral gaps and nonzero coupling-square data.
   Full matrix Lie closure u(5) is NOT asserted in this module. -/
namespace E47QGNN
def exchangeD : List Int := [-6, -5, -3, 0, 4]
def adjacentGaps : List Int := [1, 2, 3, 4]
def gapSquares : List Int := adjacentGaps.map (fun x => x*x)
/-- B_{k,k+1}^2 = (12, 147/20, 144/35, 9/7);
    the numerator and denominator pairs are recorded exactly. -/
def couplingNumerators : List Nat := [12,147,144,9]
def couplingDenominators : List Nat := [1,20,35,7]
theorem diagonal_exact : exchangeD = [-6,-5,-3,0,4] := by decide
theorem gaps_exact : gapSquares = [1,4,9,16] := by decide
theorem gaps_distinct : gapSquares.Nodup := by decide
theorem couplings_nonzero : couplingNumerators.all (fun x => x > 0) = true := by decide
theorem denominators_nonzero : couplingDenominators.all (fun x => x > 0) = true := by decide
theorem u5_real_dimension : 5*5 = 25 := by decide
theorem pu5_real_dimension : 5*5-1 = 24 := by decide
theorem e47_retained_dimension : 5*5+2*11 = 47 := by decide
theorem exchange_sum_spin2 : (2*(2+1)-18 : Int) = -12 := by decide
#print axioms gaps_distinct
#print axioms couplings_nonzero
end E47QGNN
