(* Concrete 125-state Casimir selector: paired finite scalar interpolation.
   N(x)=x(x-2)(x-12)(x-20)(x-31)(x-42), P=N/1814400.
   This proves exact values on seven supplied scalars, NOT that the actual
   125x125 Casimir has those eigenvalues. Matrix verification is separate. *)
From Coq Require Import ZArith List.
Import ListNotations.
Open Scope Z_scope.

Module E47ConcreteSelector.
Definition spectrum : list Z := [0; 2; 6; 12; 20; 30; 42].
Definition denominator : Z := 1814400.
Definition numerator (x : Z) : Z :=
  x * (x - 2) * (x - 12) * (x - 20) * (x - 31) * (x - 42).
Definition kernelFilter (x : Z) : Z := (x - 6) * (x - 30).

Theorem exact_values :
  map numerator spectrum = [0; 0; denominator; 0; 0; denominator; 0].
Proof. vm_compute. reflexivity. Qed.

Theorem idempotent_values :
  map (fun x => numerator x * numerator x) spectrum =
  map (fun x => denominator * numerator x) spectrum.
Proof. vm_compute. reflexivity. Qed.

Theorem annihilation_values :
  map (fun x => kernelFilter x * numerator x) spectrum =
  [0; 0; 0; 0; 0; 0; 0].
Proof. vm_compute. reflexivity. Qed.

End E47ConcreteSelector.

Print Assumptions E47ConcreteSelector.exact_values.
Print Assumptions E47ConcreteSelector.idempotent_values.
Print Assumptions E47ConcreteSelector.annihilation_values.
