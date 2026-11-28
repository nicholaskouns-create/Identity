-- Algebraic factorization after convergence establishes F x = F (p x).
theorem universal_factor {X Y : Type} (p : X → X) (F : X → Y)
    (h : ∀ x, F x = F (p x)) : F = F ∘ p := by
  funext x
  exact h x
theorem invariant_factor {X Y : Type} (p t : X → X) (f : X → Y)
    (h : ∀ x, p (t x) = p x) (x : X) :
    f (p (t x)) = f (p x) := by rw [h x]
