/- E47 canonicalization and sector arithmetic. Lean 4.35, Mathlib-free. -/
namespace E47Lawful
def S {X I : Type} (e : I → X) (p : X → I) (T : X → X) (x : X) : X :=
  e (p (T x))
theorem S_idempotent {X I : Type} (e : I → X) (p : X → I)
    (T : X → X) (h : ∀ i : I, p (T (e i)) = i) (x : X) :
    S e p T (S e p T x) = S e p T x := by
  unfold S
  rw [h]
def Pc (v : Int × Int) : Int × Int := (v.1, 0)
def Tc (v : Int × Int) : Int × Int := (v.2, v.1)
def Sc (v : Int × Int) : Int × Int := Pc (Tc v)
theorem Pc_idempotent (v : Int × Int) : Pc (Pc v) = Pc v := by
  cases v
  rfl
theorem Sc_not_idempotent : Sc (Sc ((0 : Int), 1)) ≠ Sc ((0 : Int), 1) := by
  decide
theorem sector_dims_sum : 1 + 9 + 25 + 28 + 27 + 22 + 13 = (125 : Nat) := by decide
theorem kernel_dim : 25 + 22 = (47 : Nat) := by decide
theorem complement_dim : 1 + 9 + 28 + 27 + 13 = (78 : Nat) := by decide
theorem carrier_split : (47 : Nat) + 78 = 125 := by decide
theorem omega_cross : (47 : Nat) * 1000 = 376 * 125 := by decide
end E47Lawful
