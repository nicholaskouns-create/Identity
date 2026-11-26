import Lean
/-!
Exact seven-root moment inversion certificate, independent of the concrete
125x125 Casimir construction. The supplied candidate roots are NOT asserted
to be its spectrum. The companion Python reconstructs the concrete matrix
and independently computes tr(C^k), k=0..6, without a spectral assumption.
-/
set_option maxRecDepth 8192
set_option maxHeartbeats 0

namespace E47ConcreteMomentInversion

def roots : List Int := [0, 2, 6, 12, 20, 30, 42]
def candidateMult : List Int := [1, 9, 25, 28, 27, 22, 13]
def observedMoments : List Int :=
  [125, 2250, 58500, 1827000, 63205200, 2327148000, 89208187200]

/- Coefficients in ascending powers of x for
   L_i(x) = product_{j != i} (x - roots_j). -/
def lagrange : List (List Int) :=
  [[3628800, -3110400, 808848, -89280, 4648, -112, 1],
   [0, -1814400, 648000, -80424, 4428, -110, 1],
   [0, -604800, 417600, -65208, 4012, -106, 1],
   [0, -302400, 234000, -47904, 3448, -100, 1],
   [0, -181440, 146448, -33120, 2808, -92, 1],
   [0, -120960, 99648, -23640, 2188, -82, 1],
   [0, -86400, 72000, -17544, 1708, -70, 1]]
def denominators : List Int :=
  [3628800, -1612800, 1741824, -3110400, 8870400, -43545600, 479001600]

def evalRow (i j : Nat) : Int :=
  ((List.range 7).map fun k =>
    ((lagrange.getD i []).getD k 0) * (roots.getD j 0) ^ k).sum

def leftInverseOK : Bool :=
  (List.range 7).all fun i =>
    (List.range 7).all fun j =>
      decide (evalRow i j = if i = j then denominators.getD i 0 else (0 : Int))

def candidateMoment (k : Nat) : Int :=
  ((List.range 7).map fun i =>
    (candidateMult.getD i 0) * (roots.getD i 0) ^ k).sum

def candidateMomentsOK : Bool :=
  (List.range 7).all fun k =>
    decide (candidateMoment k = observedMoments.getD k 0)

def recoveryOK (moments : List Int) : Bool :=
  (List.range 7).all fun i =>
    decide (((List.range 7).map fun k =>
      ((lagrange.getD i []).getD k 0) * (moments.getD k 0)).sum =
      (denominators.getD i 0) * (candidateMult.getD i 0))

def mutantMoments : List Int :=
  [126, 2250, 58500, 1827000, 63205200, 2327148000, 89208187200]

theorem lagrange_left_inverse : leftInverseOK = true := by decide
theorem candidate_moment_vector : candidateMomentsOK = true := by decide
theorem exact_multiplicity_recovery : recoveryOK observedMoments = true := by decide
theorem mutant_moment_rejected : recoveryOK mutantMoments = false := by decide

end E47ConcreteMomentInversion

#print axioms E47ConcreteMomentInversion.lagrange_left_inverse
#print axioms E47ConcreteMomentInversion.candidate_moment_vector
#print axioms E47ConcreteMomentInversion.exact_multiplicity_recovery
#print axioms E47ConcreteMomentInversion.mutant_moment_rejected
