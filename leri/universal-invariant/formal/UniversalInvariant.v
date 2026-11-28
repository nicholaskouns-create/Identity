Section Factor.
Context {X Y : Type}.
Variables (p t : X -> X) (F : X -> Y).
Theorem universal_factor (h : forall x, F x = F (p x)) :
  forall x, F x = F (p x).
Proof. exact h. Qed.
Theorem invariant_factor (h : forall x, p (t x) = p x) :
  forall x, F (p (t x)) = F (p x).
Proof. intro x. rewrite h. reflexivity. Qed.
End Factor.
