/-!
E47 projector polynomial congruences, independent paired coefficient certificate.
No eigenvalues or multiplicities of the concrete 125x125 matrix are assumed.
For M(x)=x(x-2)(x-6)(x-12)(x-20)(x-30)(x-42),
N(x)=x(x-2)(x-12)(x-20)(x-31)(x-42), d=1814400,
the exact integer polynomial identities are:
  N² - d N = M Q_idem
  (x-6)(x-30) N = M (x-31).
These coefficient identities are stronger than checking seven supplied scalar values.
Transport to the concrete 125x125 matrix still requires a formal M(C)=0
certificate and polynomial-evaluation soundness; neither is asserted here.
-/
namespace E47ProjectorCongruences

def coeff (p : List Int) (i : Nat) : Int := (p[i]?).getD 0

def polyMul (p q : List Int) : List Int :=
  (List.range (p.length + q.length - 1)).map fun k =>
    ((List.range (k + 1)).map fun i => coeff p i * coeff q (k - i)).sum

def polySub (p q : List Int) : List Int :=
  (List.range (max p.length q.length)).map fun k => coeff p k - coeff q k

def polyScale (s : Int) (p : List Int) : List Int := p.map fun x => s * x

def product (factors : List (List Int)) : List Int := factors.foldl polyMul [1]

def numerator : List Int :=
  product [[0,1],[-2,1],[-12,1],[-20,1],[-31,1],[-42,1]]
def annihilator : List Int :=
  product [[0,1],[-2,1],[-6,1],[-12,1],[-20,1],[-30,1],[-42,1]]
def kernelFilter : List Int := product [[-6,1],[-30,1]]
def qIdempotence : List Int := [312480,160048,-47400,3553,-102,1]
def qKernel : List Int := [-31,1]
def denominator : Int := 1814400

theorem numerator_coefficients :
    numerator = [0,-624960,430848,-66940,4088,-107,1] := by decide

theorem annihilator_coefficients :
    annihilator = [0,3628800,-3110400,808848,-89280,4648,-112,1] := by decide

theorem idempotence_polynomial_divisibility :
    polySub (polyMul numerator numerator) (polyScale denominator numerator) =
      polyMul annihilator qIdempotence := by decide

theorem kernel_polynomial_divisibility :
    polyMul kernelFilter numerator = polyMul annihilator qKernel := by decide

def mutantNumerator : List Int :=
  product [[0,1],[-2,1],[-12,1],[-20,1],[-30,1],[-42,1]]

theorem negative_control_rejected :
    polySub (polyMul mutantNumerator mutantNumerator)
      (polyScale denominator mutantNumerator) ≠
      polyMul annihilator qIdempotence := by decide

end E47ProjectorCongruences

#print axioms E47ProjectorCongruences.numerator_coefficients
#print axioms E47ProjectorCongruences.annihilator_coefficients
#print axioms E47ProjectorCongruences.idempotence_polynomial_divisibility
#print axioms E47ProjectorCongruences.kernel_polynomial_divisibility
#print axioms E47ProjectorCongruences.negative_control_rejected
