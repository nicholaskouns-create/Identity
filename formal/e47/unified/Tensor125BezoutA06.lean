/- E47-A06: exact integer coefficient certificate, independent of Casimir spectrum.
   Polynomials have degree ix most six and are represented by coefficients 0..6.
   Multiplication is the exact convolution on these coefficients.
   This proves the finite coefficient identity, not the concrete matrix
   annihilator, projector rank, or any unverified eigenspace claim. -/
namespace E47BezoutA06

abbrev Poly7 := Fin 7 → Int

def ix (n : Nat) : Fin 7 := ⟨n % 7, Nat.mod_lt n (by decide)⟩

def factor (r : Int) : Poly7 := fun i =>
  if i.val = 0 then -r else if i.val = 1 then 1 else 0

def pmul (p q : Poly7) : Poly7 := fun i =>
  ((List.range (i.val + 1)).map
    (fun k => p (ix k) * q (ix (i.val - k)))).sum

def tPoly : Poly7 :=
  pmul (pmul (pmul (pmul (pmul
    (factor 0) (factor 2)) (factor 12)) (factor 20)) (factor 31)) (factor 42)

def kPoly : Poly7 := pmul (factor 6) (factor 30)

def qPoly : Poly7 := fun i =>
  if i.val = 0 then 10080
  else if i.val = 1 then 5488
  else if i.val = 2 then -1352
  else if i.val = 3 then 71
  else if i.val = 4 then -1
  else 0

def constant (n : Int) : Poly7 := fun i => if i.val = 0 then n else 0

theorem bezout_coefficients :
    ∀ i : Fin 7, tPoly i + pmul kPoly qPoly i = constant 1814400 i := by
  decide

theorem bezout_polynomial :
    (fun i : Fin 7 => tPoly i + pmul kPoly qPoly i) = constant 1814400 := by
  funext i
  exact bezout_coefficients i

def eval7 (p : Poly7) (x : Int) : Int :=
  ((List.range 7).map (fun i => p (ix i) * x ^ i)).sum

theorem selected_values :
    eval7 tPoly 6 = 1814400 ∧ eval7 tPoly 30 = 1814400 := by
  decide

theorem bezout_evaluations (x : Int) :
    eval7 (fun i => tPoly i + pmul kPoly qPoly i) x =
      eval7 (constant 1814400) x := by
  rw [bezout_polynomial]

end E47BezoutA06

#print axioms E47BezoutA06.bezout_coefficients
#print axioms E47BezoutA06.bezout_polynomial
#print axioms E47BezoutA06.selected_values
#print axioms E47BezoutA06.bezout_evaluations
