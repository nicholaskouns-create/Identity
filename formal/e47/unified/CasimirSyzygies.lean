import Lean
/-!
E47 universal Casimir syzygy certificate over the free noncommutative
integer polynomial algebra on U,D,Z. No Casimir centrality is assumed.

Residuals:
 rZU = ZU - UZ - U
 rZD = ZD - DZ + D
 rUD = UD - DU - 2Z
 C = DU + ZZ + Z

Exact free-word identities:
 [C,Z] = -D*rZU - rZD*U
 [C,U] = -rUD*U + Z*rZU + rZU*Z
 [C,D] = D*rUD + Z*rZD + rZD*Z

The finite certificate checks every coefficient on all 40 words of length
at most three, and separately checks degree and alphabet bounds on every
term. This is a symbolic algebraic bridge, not a proof that the concrete
125-dimensional generators satisfy the three residual equations.
-/
set_option maxRecDepth 8192
set_option maxHeartbeats 0

namespace E47CasimirSyzygies
abbrev Word := List Nat
abbrev Term := Word × Int
abbrev Poly := List Term

def atom (k : Nat) : Poly := [([k], 1)]
def padd (p q : Poly) : Poly := p ++ q
def pneg (p : Poly) : Poly := p.map (fun t => (t.1, -t.2))
def psub (p q : Poly) : Poly := padd p (pneg q)
def pmul (p q : Poly) : Poly :=
  p.flatMap (fun t => q.map (fun s => (t.1 ++ s.1, t.2 * s.2)))
def pscale (n : Int) (p : Poly) : Poly :=
  p.map (fun t => (t.1, n * t.2))
def coeff (p : Poly) (w : Word) : Int :=
  ((p.filter (fun t => t.1 == w)).map Prod.snd).sum

def letters : List Nat := List.range 3
def words3 : List Word :=
  [[]] ++
  (letters.map (fun i => [i])) ++
  (letters.flatMap (fun i => letters.map (fun j => [i, j]))) ++
  (letters.flatMap (fun i => letters.flatMap
    (fun j => letters.map (fun k => [i, j, k]))))

def degreeOK (p : Poly) : Bool :=
  p.all (fun t => decide (t.1.length ≤ 3))
def alphabetOK (p : Poly) : Bool :=
  p.all (fun t => t.1.all (fun n => decide (n < 3)))
def sameCoeffs (p q : Poly) : Bool :=
  words3.all (fun w => decide (coeff p w = coeff q w))
def certificate (p q : Poly) : Bool :=
  degreeOK p && degreeOK q &&
  alphabetOK p && alphabetOK q && sameCoeffs p q

def u : Poly := atom 0
def d : Poly := atom 1
def z : Poly := atom 2
def rZU : Poly := psub (psub (pmul z u) (pmul u z)) u
def rZD : Poly := padd (psub (pmul z d) (pmul d z)) d
def rUD : Poly := psub (psub (pmul u d) (pmul d u)) (pscale 2 z)
def casimir : Poly := padd (pmul d u) (padd (pmul z z) z)
def comm (p q : Poly) : Poly := psub (pmul p q) (pmul q p)

def czRhs : Poly := padd (pneg (pmul d rZU)) (pneg (pmul rZD u))
def cuRhs : Poly := padd (pneg (pmul rUD u))
  (padd (pmul z rZU) (pmul rZU z))
def cdRhs : Poly := padd (pmul d rUD)
  (padd (pmul z rZD) (pmul rZD z))

theorem words3_cardinality : words3.length = 40 := by decide
theorem casimir_Z_syzygy : certificate (comm casimir z) czRhs = true := by decide
theorem casimir_U_syzygy : certificate (comm casimir u) cuRhs = true := by decide
theorem casimir_D_syzygy : certificate (comm casimir d) cdRhs = true := by decide
theorem mutated_U_syzygy_rejected :
    certificate (comm casimir u) (padd cuRhs z) = false := by decide

end E47CasimirSyzygies

#print axioms E47CasimirSyzygies.words3_cardinality
#print axioms E47CasimirSyzygies.casimir_Z_syzygy
#print axioms E47CasimirSyzygies.casimir_U_syzygy
#print axioms E47CasimirSyzygies.casimir_D_syzygy
#print axioms E47CasimirSyzygies.mutated_U_syzygy_rejected
