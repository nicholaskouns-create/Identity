(* E47 universal Casimir syzygies in the free noncommutative integer
   polynomial algebra on U,D,Z. No concrete 125-state bracket is assumed.
   Each certificate checks 40 words of length <=3, degree and alphabet.
   Transport to the actual 125x125 matrix algebra remains a separate step. *)
From Coq Require Import List Arith ZArith Bool.
Import ListNotations.
Open Scope Z_scope.

Module E47CasimirSyzygies.
Definition word := list nat.
Definition term := (word * Z)%type.
Definition poly := list term.
Definition atom (k : nat) : poly := [([k], 1)].
Definition padd (p q : poly) : poly := p ++ q.
Definition pneg (p : poly) : poly :=
  map (fun t => (fst t, - snd t)) p.
Definition psub (p q : poly) : poly := padd p (pneg q).
Definition pmul (p q : poly) : poly :=
  flat_map (fun t => map (fun s => (fst t ++ fst s, snd t * snd s)) q) p.
Definition pscale (n : Z) (p : poly) : poly :=
  map (fun t => (fst t, n * snd t)) p.
Definition coeff (p : poly) (w : word) : Z :=
  fold_right Z.add 0
    (map snd (filter (fun t =>
      if list_eq_dec Nat.eq_dec (fst t) w then true else false) p)).

Definition letters : list nat := seq 0 3.
Definition words3 : list word :=
  [[]] ++
  map (fun i => [i]) letters ++
  flat_map (fun i => map (fun j => [i;j]) letters) letters ++
  flat_map (fun i => flat_map (fun j =>
    map (fun k => [i;j;k]) letters) letters) letters.
Definition degreeOK (p : poly) : bool :=
  forallb (fun t => Nat.leb (length (fst t)) 3) p.
Definition alphabetOK (p : poly) : bool :=
  forallb (fun t => forallb (fun n => Nat.ltb n 3) (fst t)) p.
Definition sameCoeffs (p q : poly) : bool :=
  forallb (fun w => Z.eqb (coeff p w) (coeff q w)) words3.
Definition certificate (p q : poly) : bool :=
  degreeOK p && degreeOK q &&
  alphabetOK p && alphabetOK q && sameCoeffs p q.

Definition u : poly := atom 0%nat.
Definition d : poly := atom 1%nat.
Definition z : poly := atom 2%nat.
Definition rZU : poly := psub (psub (pmul z u) (pmul u z)) u.
Definition rZD : poly := padd (psub (pmul z d) (pmul d z)) d.
Definition rUD : poly := psub (psub (pmul u d) (pmul d u)) (pscale 2 z).
Definition casimir : poly := padd (pmul d u) (padd (pmul z z) z).
Definition comm (p q : poly) : poly := psub (pmul p q) (pmul q p).
Definition czRhs : poly := padd (pneg (pmul d rZU)) (pneg (pmul rZD u)).
Definition cuRhs : poly := padd (pneg (pmul rUD u))
  (padd (pmul z rZU) (pmul rZU z)).
Definition cdRhs : poly := padd (pmul d rUD)
  (padd (pmul z rZD) (pmul rZD z)).

Theorem words3_cardinality : length words3 = 40%nat.
Proof. vm_compute. reflexivity. Qed.
Theorem casimir_Z_syzygy : certificate (comm casimir z) czRhs = true.
Proof. vm_compute. reflexivity. Qed.
Theorem casimir_U_syzygy : certificate (comm casimir u) cuRhs = true.
Proof. vm_compute. reflexivity. Qed.
Theorem casimir_D_syzygy : certificate (comm casimir d) cdRhs = true.
Proof. vm_compute. reflexivity. Qed.
Theorem mutated_U_syzygy_rejected :
  certificate (comm casimir u) (padd cuRhs z) = false.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions words3_cardinality.
Print Assumptions casimir_Z_syzygy.
Print Assumptions casimir_U_syzygy.
Print Assumptions casimir_D_syzygy.
Print Assumptions mutated_U_syzygy_rejected.
End E47CasimirSyzygies.
