/-! KKP-R E47 Certainty Gate and Reset.
    Lean 4 core, no Mathlib, no sorry, no new axioms.
    The proof assumes P(embed y)=embed y; it does not build Casimir P.
    A Nat-valued error/energy certificate supplies the gate threshold. -/
namespace KKPRCertaintyCycle
abbrev Carrier := Fin 125 → Int
abbrev Protected := Fin 47 → Int

def omega (score : Protected → Nat) (threshold : Nat) (y : Protected) : Bool :=
  decide (score y ≤ threshold)
def selected (score : Protected → Nat) (threshold : Nat)
    (baseline y : Protected) : Protected :=
  if omega score threshold y then y else baseline
def alpha (q : Protected → Carrier) (score : Protected → Nat)
    (threshold : Nat) (baseline y : Protected) : Carrier :=
  q (selected score threshold baseline y)
def cycle (sigma gamma : Carrier → Carrier)
    (lambda : Carrier → Protected) (psi : Protected → Protected)
    (q : Protected → Carrier) (score : Protected → Nat)
    (threshold : Nat) (baseline : Protected) (x : Carrier) : Carrier :=
  alpha q score threshold baseline (psi (lambda (gamma (sigma x))))
theorem omega_sound (score : Protected → Nat) (threshold : Nat)
    (y : Protected) (h : omega score threshold y = true) :
    score y ≤ threshold := by
  simpa [omega] using h
theorem selected_certified (score : Protected → Nat) (threshold : Nat)
    (baseline y : Protected) (hbase : score baseline ≤ threshold) :
    score (selected score threshold baseline y) ≤ threshold := by
  by_cases h : score y ≤ threshold
  · simp [selected, omega, h]
  · simp [selected, omega, h, hbase]
theorem cycle_invariant (P : Carrier → Carrier)
    (q : Protected → Carrier) (hPq : ∀ y, P (q y) = q y)
    (sigma gamma : Carrier → Carrier)
    (lambda : Carrier → Protected) (psi : Protected → Protected)
    (score : Protected → Nat) (threshold : Nat)
    (baseline : Protected) (x : Carrier) :
    P (cycle sigma gamma lambda psi q score threshold baseline x) =
       cycle sigma gamma lambda psi q score threshold baseline x := by
  exact hPq _
theorem cycle_certified (sigma gamma : Carrier → Carrier)
    (lambda : Carrier → Protected) (psi : Protected → Protected)
    (score : Protected → Nat) (threshold : Nat)
    (baseline : Protected) (hbase : score baseline ≤ threshold)
    (x : Carrier) :
    score (selected score threshold baseline
      (psi (lambda (gamma (sigma x))))) ≤ threshold := by
  exact selected_certified score threshold baseline _ hbase
def iterate (f : Carrier → Carrier) : Nat → Carrier → Carrier
  | 0, x => x
  | n + 1, x => f (iterate f n x)
theorem repeated_invariant (P : Carrier → Carrier) (f : Carrier → Carrier)
    (hf : ∀ x, P (f x) = f x) (n : Nat) (x : Carrier) :
    P (iterate f (n + 1) x) = iterate f (n + 1) x := by
  simp only [iterate]
  exact hf _
theorem full_cycle_repeated_invariant (P : Carrier → Carrier)
    (q : Protected → Carrier) (hPq : ∀ y, P (q y) = q y)
    (sigma gamma : Carrier → Carrier)
    (lambda : Carrier → Protected) (psi : Protected → Protected)
    (score : Protected → Nat) (threshold : Nat)
    (baseline : Protected) (n : Nat) (x : Carrier) :
    P (iterate (cycle sigma gamma lambda psi q score threshold baseline)
         (n + 1) x) =
    iterate (cycle sigma gamma lambda psi q score threshold baseline)
      (n + 1) x := by
  apply repeated_invariant
  intro v
  exact cycle_invariant P q hPq sigma gamma lambda psi score threshold baseline v
end KKPRCertaintyCycle
