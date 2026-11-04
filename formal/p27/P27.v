From Coq Require Import ZArith Lia.
Open Scope Z_scope.
(* Matrix-operator identities in an arbitrary noncommutative ring,
   expressed using an abstract ring signature. *)
Section Operator.
Context {R : Type}.
Context (zero one : R) (add mul sub : R -> R -> R).
Infix "+" := add. Infix "*" := mul. Infix "-" := sub.
Hypothesis add_assoc : forall a b c, (a+b)+c=a+(b+c).
Hypothesis add_comm : forall a b, a+b=b+a.
Hypothesis add_zero : forall a, a+zero=a.
Hypothesis mul_add_l : forall a b c, a*(b+c)=a*b+a*c.
Hypothesis mul_add_r : forall a b c, (a+b)*c=a*c+b*c.
Hypothesis zero_add : forall a, zero+a=a.
Theorem projector_extension : forall p e,
 p*p=p -> e*e=e -> p*e=zero -> e*p=zero ->
 (p+e)*(p+e)=p+e.
Proof.
 intros p e hp he hpe hep.
 rewrite mul_add_r, !mul_add_l, hp, he, hpe, hep.
 rewrite add_zero, zero_add.
 reflexivity.
Qed.
End Operator.
Theorem dimensions : (26+1=27 /\\ 64-27=37 /\\ 64+37=101)%Z.
Proof. lia. Qed.
Theorem contraction_denominator : (2^40=1099511627776)%Z.
Proof. reflexivity. Qed.
