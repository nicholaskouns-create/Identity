/-!
  Concrete 125-state Casimir projector: exact scalar interpolation data.

  This paired certificate checks the actual polynomial
    N(x) = x(x-2)(x-12)(x-20)(x-31)(x-42)
    P(x) = N(x)/1814400
  on the seven candidate Casimir eigenvalues.

  It does NOT assert that the concrete 125x125 Casimir has this spectrum.
  The independent exact-integer matrix witness checks m(C)=0, N(C)^2=d*N(C),
  K(C)N(C)=0 and rank(K)=78 by an explicit modular rank sandwich.
  Those matrix statements are not yet formalized in Lean/Coq.
-/
namespace E47ConcreteSelector

def spectrum : List Int := [0, 2, 6, 12, 20, 30, 42]
def denominator : Int := 1814400
def numerator (x : Int) : Int :=
  x * (x - 2) * (x - 12) * (x - 20) * (x - 31) * (x - 42)
def kernelFilter (x : Int) : Int := (x - 6) * (x - 30)

theorem exact_values :
    spectrum.map numerator = [0, 0, denominator, 0, 0, denominator, 0] := by
  decide

theorem idempotent_values :
    spectrum.map (fun x => numerator x * numerator x) =
      spectrum.map (fun x => denominator * numerator x) := by
  decide

theorem annihilation_values :
    spectrum.map (fun x => kernelFilter x * numerator x) =
      [0, 0, 0, 0, 0, 0, 0] := by
  decide

end E47ConcreteSelector

#print axioms E47ConcreteSelector.exact_values
#print axioms E47ConcreteSelector.idempotent_values
#print axioms E47ConcreteSelector.annihilation_values
