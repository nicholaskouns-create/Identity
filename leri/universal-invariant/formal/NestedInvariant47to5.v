Section Nested.
Context {X Y : Type}.
Variables (p s : X -> X) (F : X -> Y).
Theorem nested_factor (hp : forall x, F x = F (p x))
 (hs : forall x, F x = F (s x)) : forall x, F x = F (s (p x)).
Proof. intro x. transitivity (F (p x)); [apply hp | apply hs]. Qed.
End Nested.
