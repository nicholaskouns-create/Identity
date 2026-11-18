/-! Sigillum wheel: exact orbit theorem in pure Lean 4 core.
    Full spectral projector operator formalization remains a separate obligation. -/
namespace SigillumOrbit
def step (s : Nat) (j : Fin 40) : Fin 40 :=
  ⟨(3*j.val+s)%40, Nat.mod_lt _ (by decide)⟩
def shift (k : Fin 20) : Nat := 2*k.val+1
theorem fourth_power :
    ∀ k : Fin 20, ∀ j : Fin 40,
      step (shift k) (step (shift k) (step (shift k) (step (shift k) j))) = j := by
  decide
theorem no_fixed_first :
    ∀ k : Fin 20, ∀ j : Fin 40, step (shift k) j ≠ j := by
  decide
theorem no_fixed_second :
    ∀ k : Fin 20, ∀ j : Fin 40,
      step (shift k) (step (shift k) j) ≠ j := by
  decide
theorem no_fixed_third :
    ∀ k : Fin 20, ∀ j : Fin 40,
      step (shift k) (step (shift k) (step (shift k) j)) ≠ j := by
  decide
#print axioms SigillumOrbit.fourth_power
#print axioms SigillumOrbit.no_fixed_second
end SigillumOrbit
