(*
   E47Landauer.v — the thermodynamic cost of projecting onto E47.

   Coq standard library only; no axioms, no Admitted, no native_compute.
   Companion to E47Landauer.lean; same statements, same certificates.

   STATUS: PROVED.  Compiled clean on Coq 8.18.0.  Print Assumptions returns
   "Closed under the global context" for all nine theorems -- rank_nullity,
   omega_c_exact, cost_gt_141, cost_lt_142, cost_in_bits, cost_coarse,
   scale_invariant_gt, scale_invariant_lt and cost_is_not_the_tally.

   This file was first committed carrying a notice that it had not been
   compiled, because coqc was unavailable at the time.  That notice is now
   discharged: the toolchain was obtained and the file verified unchanged.

   Claim being certified:
       S(I/125) - S(P/47) = ln(125/47) = -ln Omega_c = 1.4111954... bits

   Coq's standard library has no reals in scope here, so the transcendental
   value is bracketed by exact integer inequalities.  For positive p, q,

       log2(125/47) > p/q   <->   47^q * 2^p < 125^q
       log2(125/47) < p/q   <->   125^q < 47^q * 2^p

   since log2(125/47) > p/q <-> (125/47)^q > 2^p, cleared by 47^q > 0.
*)

Require Import ZArith.
Require Import Lia.
Open Scope Z_scope.

Module E47Landauer.

(** * 1.  The carrier and the kernel *)

Definition carrier   : Z := 125.   (* dim (V2 (x) V2 (x) V2)            *)
Definition kernel    : Z := 47.    (* dim ker (C - 6I)(C - 30I)         *)
Definition discarded : Z := 78.    (* the contracted complement         *)

Theorem rank_nullity : kernel + discarded = carrier.
Proof. unfold kernel, discarded, carrier. lia. Qed.

(** [Omega_c = 47/125 = 0.376] exactly, cleared of denominators. *)
Theorem omega_c_exact : kernel * 1000 = 376 * carrier.
Proof. unfold kernel, carrier. lia. Qed.

(** * 2.  The entropy drop, bracketed to two decimal places *)

(** [log2(125/47) > 141/100]: the cost exceeds 1.41 bits. *)
Theorem cost_gt_141 : 47^100 * 2^141 < 125^100.
Proof. vm_compute. reflexivity. Qed.

(** [log2(125/47) < 142/100]: the cost is under 1.42 bits. *)
Theorem cost_lt_142 : 125^100 < 47^100 * 2^142.
Proof. vm_compute. reflexivity. Qed.

Theorem cost_in_bits :
  47^100 * 2^141 < 125^100 /\ 125^100 < 47^100 * 2^142.
Proof. split; [exact cost_gt_141 | exact cost_lt_142]. Qed.

(** A coarser bracket, checkable by hand: between 1.4 and 1.5 bits. *)
Theorem cost_coarse :
  47^10 * 2^14 < 125^10 /\ 125^10 < 47^10 * 2^15.
Proof. split; vm_compute; reflexivity. Qed.

(** * 3.  The cost sees the ratio and nothing else

    Doubling carrier and kernel leaves every bracket unchanged.  The spectral
    gap 11664, the 78 discarded dimensions and the spectrum of K never enter.
    This is the content of "thermodynamics prices only Omega_c". *)

Theorem scale_invariant_gt : 94^100 * 2^141 < 250^100.
Proof. vm_compute. reflexivity. Qed.

Theorem scale_invariant_lt : 250^100 < 94^100 * 2^142.
Proof. vm_compute. reflexivity. Qed.

(** The discarded count is not the cost: 78 dimensions are thrown away, yet
    the price stays under 2 bits — a logarithm of a ratio, not a tally. *)
Theorem cost_is_not_the_tally : 125^1 < 47^1 * 2^2.
Proof. vm_compute. reflexivity. Qed.

(** * 4.  What is NOT claimed here

    - No real arithmetic: ln and log2 appear only in comments, pinned by the
      integer certificates above.
    - No physics.  The Landauer inequality Q >= kT * DeltaS is a theorem of
      statistical mechanics (Landauer 1961; Reeb and Wolf 2014), not of this
      file.  Only the combinatorial factor DeltaS is certified here.
    - The bound presumes a deterministic reset from the maximally mixed state
      on the carrier to the maximally mixed state on the kernel. *)

End E47Landauer.
