(* MC-121: exact finite spectral-selector action on the seven E47 Casimir
   eigenvalues. Paired with SpectralMask128.lean.
   The eigenvalues and dimensions are constants from the separate concrete
   weight census; this is not yet a theorem about eigenspaces of the full
   125x125 matrix or about arbitrary self-adjoint operators. *)
From Coq Require Import ZArith Arith Bool List.
Import ListNotations.
Open Scope Z_scope.

Definition eigenvalue (j : nat) : Z :=
  nth j [0; 2; 6; 12; 20; 30; 42] 0.
Definition sectorDim (j : nat) : nat :=
  nth j [1%nat; 9%nat; 25%nat; 28%nat; 27%nat; 22%nat; 13%nat] 0%nat.

Definition selected (mask j : nat) : bool :=
  Nat.eqb ((mask / (2 ^ j)) mod 2)%nat 1%nat.

Definition selector (mask : nat) (x : Z) : Z :=
  fold_left (fun acc j => acc * (x - eigenvalue j))
    (filter (selected mask) (seq 0 7)) 1.

Definition kernelDimFromAction (mask : nat) : nat :=
  fold_left
    (fun acc j => (acc +
      (if Z.eqb (selector mask (eigenvalue j)) 0
       then sectorDim j else 0%nat))%nat)
    (seq 0 7) 0%nat.

Definition selectedDim (mask : nat) : nat :=
  fold_left
    (fun acc j => (acc +
      (if selected mask j then sectorDim j else 0%nat))%nat)
    (seq 0 7) 0%nat.

Definition zeroPatternOK (mask : nat) : bool :=
  forallb
    (fun j => Bool.eqb
      (Z.eqb (selector mask (eigenvalue j)) 0)
      (selected mask j))
    (seq 0 7).

Theorem all_128_selector_zero_patterns :
  forallb zeroPatternOK (seq 0 128) = true.
Proof. vm_compute. reflexivity. Qed.

Theorem all_128_selector_dimensions :
  forallb (fun mask => Nat.eqb (kernelDimFromAction mask)
                                  (selectedDim mask))
    (seq 0 128) = true.
Proof. vm_compute. reflexivity. Qed.

Theorem empty_selector_dimension : kernelDimFromAction 0%nat = 0%nat.
Proof. vm_compute. reflexivity. Qed.
Theorem full_selector_dimension : kernelDimFromAction 127%nat = 125%nat.
Proof. vm_compute. reflexivity. Qed.
Theorem e47_selector_dimension : kernelDimFromAction 36%nat = 47%nat.
Proof. vm_compute. reflexivity. Qed.
Theorem maximal_quadratic_selector_dimension :
  kernelDimFromAction 24%nat = 55%nat.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions all_128_selector_zero_patterns.
Print Assumptions all_128_selector_dimensions.
Print Assumptions empty_selector_dimension.
Print Assumptions full_selector_dimension.
Print Assumptions e47_selector_dimension.
Print Assumptions maximal_quadratic_selector_dimension.
