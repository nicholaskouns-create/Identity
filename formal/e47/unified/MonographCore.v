From Coq Require Import ZArith List Lia.
Import ListNotations.
Open Scope Z_scope.
Module E47Monograph.
Definition casimir (j : Z) : Z := j * (j + 1).
Definition k (c : Z) : Z := (c-6)*(c-30).
Definition projectorNumerator (c : Z) : Z :=
  c*(c-2)*(c-12)*(c-20)*(c-31)*(c-42).
Definition sectors : list Z := [0;1;2;3;4;5;6].
Theorem carrier_dimension : 1+9+25+28+27+22+13 = 125.
Proof. lia. Qed.
Theorem kernel_dimension : 5*5+2*11=47.
Proof. lia. Qed.
Theorem complement_dimension : 125-47=78.
Proof. lia. Qed.
Theorem casimir_spectrum :
  map casimir sectors = [0;2;6;12;20;30;42].
Proof. vm_compute. reflexivity. Qed.
Theorem projector_sector_values :
  map (fun j => projectorNumerator (casimir j)) sectors =
    [0;0;1814400;0;0;1814400;0].
Proof. vm_compute. reflexivity. Qed.
Theorem kernel_roots : k 6=0 /\ k 30=0.
Proof. vm_compute. auto. Qed.
Theorem squared_syndrome_spectrum :
  map (fun j => k (casimir j) * k (casimir j)) sectors =
    [32400;12544;0;11664;19600;0;186624].
Proof. vm_compute. reflexivity. Qed.
Theorem minimax_step : 2*99144=11664+186624.
Proof. lia. Qed.
Theorem minimax_radius :
  17*(99144-11664)=15*99144 /\
  17*(186624-99144)=15*99144.
Proof. lia. Qed.
Theorem off_kernel_bound :
  forall j, In j sectors -> k (casimir j) <> 0 ->
    17 * Z.abs (99144 - k (casimir j)*k (casimir j)) <= 15*99144.
Proof.
  intros j Hj Hk. unfold sectors in Hj.
  simpl in Hj.
  destruct Hj as [Hj|[Hj|[Hj|[Hj|[Hj|[Hj|[Hj|[]]]]]]]];
    subst j; vm_compute in *; try contradiction; try lia; easy.
Qed.
Theorem matched_syndrome :
  forall f6 f12 f30 f42 omega : Z,
    f30-f6=omega -> f42=f12+omega -> f42-f30=f12-f6.
Proof. intros. lia. Qed.
End E47Monograph.
