import Lean

/-!
  E47 third-turn finite algebra certificate.
  Scope: formal coefficient recurrence and uniqueness, not analytic transfer.
  No Mathlib dependency, sorry, or native_decide.
-/
namespace E47ThirdTurnGF

/-- D_0 = -a_0(0); the n=1 and n>=2 coefficients of
    (1+t)^2 D(t) = (5t-1)((1+t)A_0(t)-2t A_1(t)).
    Here a0 and a1 are arbitrary integer coefficient sequences. -/
def GFRec (a0 a1 d : Nat → Int) : Prop :=
  d 0 = -a0 0 ∧
  d 1 + 2 * d 0 = -a0 1 + 4 * a0 0 + 2 * a1 0 ∧
  ∀ n : Nat,
    d (n+2) + 2*d (n+1) + d n =
      -a0 (n+2) + 4*a0 (n+1) + 5*a0 n +
      2*a1 (n+1) - 10*a1 n

/-- An exact formal-series coefficient identity uniquely fixes every D_n.
    This is conditional on the coefficient recurrence; it does not certify
    its derivation from the Clebsch-Gordan sum or the asymptotic theorem. -/
theorem generating_function_coefficients_unique
    (a0 a1 d e : Nat → Int)
    (hd : GFRec a0 a1 d) (he : GFRec a0 a1 e) :
    ∀ n : Nat, d n = e n := by
  have h0 : d 0 = e 0 := by
    have x := hd.1
    have y := he.1
    omega
  have h1 : d 1 = e 1 := by
    have x := hd.2.1
    have y := he.2.1
    omega
  have pair : ∀ n : Nat, d n = e n ∧ d (n+1) = e (n+1) := by
    intro n
    induction n with
    | zero =>
        exact ⟨h0, h1⟩
    | succ n ih =>
        rcases ih with ⟨hn, hn1⟩
        constructor
        · simpa only [Nat.succ_eq_add_one] using hn1
        · have x := hd.2.2 n
          have y := he.2.2 n
          simpa only [Nat.succ_eq_add_one, Nat.add_assoc] using (show d (n+2) = e (n+2) by omega)
  intro n
  exact (pair n).1

/-- The formal third-turn character label has period 3. -/
def chi (J : Nat) : Int :=
  if J % 3 = 0 then 1 else if J % 3 = 1 then 0 else -1

theorem chi_period_three (J : Nat) : chi (J+3) = chi J := by
  unfold chi
  have h : (J+3) % 3 = J % 3 := by omega
  rw [h]

end E47ThirdTurnGF

#print axioms E47ThirdTurnGF.generating_function_coefficients_unique
#print axioms E47ThirdTurnGF.chi_period_three
