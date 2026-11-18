/-! Exact integer polynomial identities for the E47 Casimir selector.
    Pure Lean 4 core; no imported tactics. Coefficients are low-degree first.
    This module proves polynomial certificates, not M(C)=0 on the tensor carrier. -/
namespace E47IntPoly
abbrev Poly := List Int
def trim : Poly → Poly
  | [] => []
  | c :: cs =>
    match trim cs with
    | [] => if c = 0 then [] else [c]
    | cs' => c :: cs'
def addRaw : Poly → Poly → Poly
  | [], q => q
  | p, [] => p
  | a :: as, b :: bs => (a + b) :: addRaw as bs
def add (p q : Poly) : Poly := trim (addRaw p q)
def scale (k : Int) (p : Poly) : Poly := trim (p.map (fun c => k*c))
def sub (p q : Poly) : Poly := add p (scale (-1) q)
def mulRaw : Poly → Poly → Poly
  | [], _ => []
  | a :: as, q => addRaw (q.map (fun b => a*b)) (0 :: mulRaw as q)
def mul (p q : Poly) : Poly := trim (mulRaw p q)
def linearFactor (r : Int) : Poly := [-r,1]
def prodRoots (rs : List Int) : Poly :=
  rs.foldl (fun acc r => mul acc (linearFactor r)) [1]
def M : Poly := prodRoots [0,2,6,12,20,30,42]
def K : Poly := prodRoots [6,30]
def T : Poly := prodRoots [0,2,12,20,31,42]
def Q : Poly := [10080,5488,-1352,71,-1]
def D : Int := 1814400
theorem bezout : add T (mul K Q) = [D] := by decide
theorem kernel_selector : mul K T = mul (linearFactor 31) M := by decide
theorem idempotence_mod_M :
    sub (mul T T) (scale D T) =
      mul M (mul (linearFactor 31) (scale (-1) Q)) := by decide
theorem selector_coefficients :
    T = [0,-624960,430848,-66940,4088,-107,1] := by decide
theorem annihilator_coefficients :
    M = [0,3628800,-3110400,808848,-89280,4648,-112,1] := by decide
#print axioms E47IntPoly.bezout
#print axioms E47IntPoly.kernel_selector
#print axioms E47IntPoly.idempotence_mod_M
end E47IntPoly
