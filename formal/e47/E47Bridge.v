(* ===================================================================
   E47Bridge.v  —  Coq 8.18.0, standard library only.

   The Kouns–Killion Paradigm (KKP-R).
   Certificate  E47-BRIDGE-001 … 011, the Coq half of the paired run.

   PAIRING, STATED EXACTLY.  Sections 1-4, 10 and 11 are the SAME statements as
   E47Bridge.lean, over the same types, in the same List-free encoding (tables as
   nat -> nat, sums as one structural recursion).  Section 5 (the Lifshitz
   dictionary) is over R here and over nat in Lean, where d_s is a parameter
   carrying its defining relation: those are CORRESPONDING statements, not
   identical ones, and the R versions here are primary.  Section 6 is split - the
   ring half is `retention_square` here, the order half is Lean's `degree_lock`.
   No theorem name is shared between the files unless the statement is shared.

   Nothing below constructs the concrete 125x125 tensor-product matrix.
   Sections 1-3 and 11 are the isotypic (block-diagonal) model.
   =================================================================== *)

Require Import Arith PeanoNat Lia Lra ZArith.
Require Import Reals Ranalysis Ranalysis5 Rfunctions.

(* ---------------------------------------------------------------
   0.  One summation combinator
   sumUpTo n f = f 0 + ... + f (n-1), by structural recursion on nat.
   --------------------------------------------------------------- *)

Fixpoint sumUpTo (n : nat) (f : nat -> nat) : nat :=
  match n with
  | O    => 0
  | S k  => sumUpTo k f + f k
  end.

(* ---------------------------------------------------------------
   1.  Clebsch-Gordan recursion            E47-BRIDGE-001
   The multiplicity table is DERIVED from spin addition, not assumed:
   spin j (x) spin 2 = (+)_{J=|j-2|}^{j+2} spin J.
   --------------------------------------------------------------- *)

Definition WIDTH := 9.

(* |a - b| on nat, free of truncation artefacts. *)
Definition absDiff (a b : nat) : nat := Nat.max a b - Nat.min a b.

(* Indicator: does spin j coupled to spin 2 produce spin J? *)
Definition couples (j J : nat) : nat :=
  if andb (Nat.leb (absDiff j 2) J) (Nat.leb J (j + 2)) then 1 else 0.

(* One Clebsch-Gordan step: tensor with a further spin-2 factor. *)
Definition step (m : nat -> nat) : nat -> nat :=
  fun J => sumUpTo WIDTH (fun j => couples j J * m j).

Definition spin2 : nat -> nat := fun j => if Nat.eqb j 2 then 1 else 0.
Definition m2   : nat -> nat := step spin2.   (* spin2 (x) spin2           *)
Definition mult : nat -> nat := step m2.      (* spin2 (x) spin2 (x) spin2 *)

Lemma cg_two :
  m2 0 = 1 /\ m2 1 = 1 /\ m2 2 = 1 /\ m2 3 = 1 /\ m2 4 = 1 /\ m2 5 = 0.
Proof. repeat split; reflexivity. Qed.

(* The multiplicity table (1, 3, 5, 4, 3, 2, 1, 0, 0), derived. *)
Lemma cg_three :
  mult 0 = 1 /\ mult 1 = 3 /\ mult 2 = 5 /\ mult 3 = 4 /\ mult 4 = 3 /\
  mult 5 = 2 /\ mult 6 = 1 /\ mult 7 = 0 /\ mult 8 = 0.
Proof. repeat split; reflexivity. Qed.

(* ---------------------------------------------------------------
   2.  Carrier and kernel                  E47-BRIDGE-002
   --------------------------------------------------------------- *)

Definition dimJ    (J : nat) : nat := 2 * J + 1.
Definition casimir (J : nat) : nat := J * (J + 1).

(* q(x) = (x - 6)(x - 30) as an indicator on sectors: selected iff the
   Casimir eigenvalue J(J+1) is a root of q. *)
Definition selected (J : nat) : nat :=
  if orb (Nat.eqb (casimir J) 6) (Nat.eqb (casimir J) 30) then 1 else 0.

Definition carrier   : nat := sumUpTo WIDTH (fun J => mult J * dimJ J).
Definition kernelDim : nat := sumUpTo WIDTH (fun J => selected J * (mult J * dimJ J)).

Lemma carrier_125 : carrier = 125.
Proof. reflexivity. Qed.

Lemma kernel_47 : kernelDim = 47.
Proof. reflexivity. Qed.

Lemma dimension_identity : kernelDim + 78 = carrier.
Proof. reflexivity. Qed.

Lemma kernel_below_carrier : kernelDim < carrier.
Proof. rewrite kernel_47, carrier_125. lia. Qed.

(* The only selected sectors are J = 2 (eigenvalue 6) and J = 5 (eigenvalue 30). *)
Lemma selected_sectors :
  selected 2 = 1 /\ selected 5 = 1 /\
  selected 0 = 0 /\ selected 1 = 0 /\ selected 3 = 0 /\ selected 4 = 0 /\
  selected 6 = 0 /\ selected 7 = 0 /\ selected 8 = 0.
Proof. repeat split; reflexivity. Qed.

(* The canonical isotypic split: 47 = 25 + 22. *)
Lemma isotypic_split :
  mult 2 * dimJ 2 = 25 /\ mult 5 * dimJ 5 = 22 /\ 25 + 22 = kernelDim.
Proof. repeat split; reflexivity. Qed.

(* ---------------------------------------------------------------
   3.  Omega as a functional, at two arguments   E47-BRIDGE-003
   --------------------------------------------------------------- *)

Lemma omega_c_exact : kernelDim * 1000 = 376 * carrier.
Proof. reflexivity. Qed.

Definition wheelStations  := 40.
Definition wheelRegisters := 10.

Lemma omega_wheel_quarter : wheelRegisters * 4 = wheelStations.
Proof. reflexivity. Qed.

(* The CRT refinement: ten is 2 + 8, not merely the quotient 40/4. *)
Lemma wheel_crt_split : 2 + 8 = wheelRegisters.
Proof. reflexivity. Qed.

(* NO BRIDGE.  Omega_c <> Omega_wheel, machine-checked rather than footnoted. *)
Lemma no_bridge : kernelDim * wheelStations <> wheelRegisters * carrier.
Proof. rewrite kernel_47, carrier_125. unfold wheelStations, wheelRegisters. lia. Qed.

Lemma omega_c_ne_quarter : kernelDim * 4 <> carrier.
Proof. rewrite kernel_47, carrier_125. lia. Qed.

(* Omega_c as a real number, exactly 0.376. *)
Lemma omega_c_real : (47 / 125)%R = (376 / 1000)%R.
Proof. field. Qed.

(* ---------------------------------------------------------------
   4.  The wheel is the same construction   E47-BRIDGE-004
   ker(T - I) has dimension = number of orbits, so the wheel's Omega
   is Omega(A,q) with q = x - 1.
   --------------------------------------------------------------- *)

Definition F (s j : nat) : nat := Nat.modulo (3 * j + s) 40.

Fixpoint Fit (s n j : nat) : nat :=
  match n with
  | O   => j
  | S k => F s (Fit s k j)
  end.

(* Reversibility and exactness of the period, at every odd offset. *)
Definition periodOk : bool :=
  Nat.eqb
    (sumUpTo 40 (fun s =>
       if Nat.eqb (Nat.modulo s 2) 1 then
         sumUpTo 40 (fun j =>
           if andb (Nat.eqb (Fit s 4 j) j)
                   (andb (negb (Nat.eqb (Fit s 1 j) j))
                         (negb (Nat.eqb (Fit s 2 j) j)))
           then 1 else 0)
       else 40))
    1600.

Lemma wheel_period_exactly_four : periodOk = true.
Proof. vm_compute. reflexivity. Qed.

(* Least station of an orbit: its canonical name. *)
Definition orbitRep (s j : nat) : nat :=
  Nat.min (Nat.min (Fit s 0 j) (Fit s 1 j)) (Nat.min (Fit s 2 j) (Fit s 3 j)).

(* Each orbit contributes exactly one station that is its own representative,
   so counting those counts the orbits. *)
Definition orbitCount (s : nat) : nat :=
  sumUpTo 40 (fun j => if Nat.eqb (orbitRep s j) j then 1 else 0).

Definition allOddTen : bool :=
  Nat.eqb (sumUpTo 40 (fun s => if Nat.eqb (Nat.modulo s 2) 1
                                then (if Nat.eqb (orbitCount s) 10 then 1 else 0)
                                else 1)) 40.

Lemma wheel_ten_registers : allOddTen = true.
Proof. vm_compute. reflexivity. Qed.

Lemma wheel_kernel_is_registers : orbitCount 1 = wheelRegisters.
Proof. reflexivity. Qed.

(* Oddness is not decoration. *)
Lemma wheel_even_degenerates : orbitCount 0 = 13 /\ orbitCount 0 <> wheelRegisters.
Proof.
  assert (H : orbitCount 0 = 13) by reflexivity.
  split; [ exact H | rewrite H; unfold wheelRegisters; lia ].
Qed.

(* ---------------------------------------------------------------
   5.  The Lifshitz dictionary              E47-BRIDGE-005
   THE FULCRUM.  Under x -> b x, t -> b^z t:
        d_H = d + z,   d_w = 2 z,   d_s = (d + z) / z.
   Over R, with honest division.  These are the primary versions.
   --------------------------------------------------------------- *)

Open Scope R_scope.

Definition dH (d z : R) : R := d + z.
Definition dw (z : R)   : R := 2 * z.
Definition ds (d z : R) : R := (d + z) / z.

(* TRIALITY.  d_s * d_w = 2 d_H.  Three dimensions, one constraint. *)
Theorem triality : forall d z : R, z <> 0 -> ds d z * dw z = 2 * dH d z.
Proof. intros d z Hz. unfold ds, dw, dH. field. exact Hz. Qed.

(* The identity in the form it appears in the fractal-geometry literature.
   A restatement of `triality`, kept for the reading, marked as such. *)
Corollary triality_classical : forall d z : R, z <> 0 ->
  ds d z * dw z = 2 * dH d z /\ dw z = 2 * z /\ dH d z = d + z.
Proof.
  intros d z Hz.
  split. { apply triality. exact Hz. }
  split; reflexivity.
Qed.

(* MARGINALITY = SELF-DUALITY = ISOTROPY.  Three-way equivalence. *)
Theorem marginal_iff_isotropic : forall d z : R, z <> 0 -> (ds d z = 2 <-> d = z).
Proof.
  intros d z Hz. unfold ds. split.
  - intros H. field_simplify_eq in H; try exact Hz; lra.
  - intros H. rewrite H. field. exact Hz.
Qed.

Theorem self_dual_iff_isotropic : forall d z : R, dw z = dH d z <-> d = z.
Proof. intros d z. unfold dw, dH. split; intros; lra. Qed.

(* WHY d_s = 2 DOES NOT CONSTRAIN d_H.
   At z = d the spectral dimension is 2 for EVERY d, so a UV result
   d_s -> 2 leaves the Hausdorff dimension entirely free.  This is the
   theorem that makes a flow to d_H = 10 compatible with, not contrary
   to, every programme that reports D -> 2. *)
Theorem spectral_two_blind_to_d : forall d : R, d <> 0 -> ds d d = 2.
Proof. intros d Hd. unfold ds. field. exact Hd. Qed.

(* SELECTION.  d_s = 2 together with d_H = 10 forces z = d = 5,
   and then d_w = d_H = 10. *)
Theorem selection : forall d z : R, z <> 0 -> ds d z = 2 -> dH d z = 10 ->
  d = 5 /\ z = 5 /\ dw z = 10 /\ dw z = dH d z.
Proof.
  intros d z Hz Hs Hten.
  apply (marginal_iff_isotropic d z Hz) in Hs.
  unfold dH in Hten. unfold dw, dH.
  repeat split; lra.
Qed.

(* ---------------------------------------------------------------
   6.  The degree lock                      E47-BRIDGE-007
   The ring half plus the order half, over R, in one statement.
   --------------------------------------------------------------- *)

(* Ring half: if lambda^n = lambda + 1 then lambda^(2n) = (lambda+1)^2. *)
Theorem retention_square : forall (l : R) (n : nat),
  l ^ n = l + 1 -> l ^ (2 * n) = (l + 1) ^ 2.
Proof.
  intros l n H.
  replace (2 * n)%nat with (n * 2)%nat by lia.
  rewrite pow_mult. rewrite H. reflexivity.
Qed.

(* The instance that matters: n = 10. *)
Theorem retention_square_10 : forall l : R,
  l ^ 10 = l + 1 -> l ^ 20 = (l + 1) ^ 2.
Proof.
  intros l H.
  replace 20%nat with (2 * 10)%nat by lia.
  apply retention_square. exact H.
Qed.

(* Order half: for l > 1 the exponential is strictly monotone, hence injective. *)
Lemma pow_strict_mono : forall (l : R) (a b : nat),
  1 < l -> (a < b)%nat -> l ^ a < l ^ b.
Proof. intros l a b Hl Hab. apply Rlt_pow; assumption. Qed.

Lemma pow_inj : forall (l : R) (a b : nat),
  1 < l -> l ^ a = l ^ b -> a = b.
Proof.
  intros l a b Hl H.
  destruct (lt_eq_lt_dec a b) as [[Hlt | Heq] | Hgt].
  - exfalso. assert (l ^ a < l ^ b) by (apply pow_strict_mono; assumption). lra.
  - exact Heq.
  - exfalso. assert (l ^ b < l ^ a) by (apply pow_strict_mono; assumption). lra.
Qed.

(* DEGREE LOCK.  The retention ratio at dimension D closes as the square of the
   retention increment exactly when D equals the degree of the retention
   polynomial.  So the RG fixed point D* = 10 is not a free parameter: it is
   forced to equal deg(x^10 - x - 1). *)
Theorem degree_lock : forall (l : R) (n D : nat),
  1 < l -> l ^ n = l + 1 -> (l ^ (2 * D) = (l + 1) ^ 2 <-> D = n).
Proof.
  intros l n D Hl Hn. split.
  - intros H.
    assert (Hn2 : l ^ (2 * n) = (l + 1) ^ 2) by (apply retention_square; exact Hn).
    assert (Heq : l ^ (2 * D) = l ^ (2 * n)) by (rewrite H, Hn2; reflexivity).
    apply (pow_inj l) in Heq; [ lia | exact Hl ].
  - intros H. rewrite H. apply retention_square. exact Hn.
Qed.

(* ---------------------------------------------------------------
   7.  Existence of lambda                  E47-BRIDGE-008
   p(x) = x^10 - x - 1 has a root in [1,2], by the intermediate value
   theorem of the Coq standard library.
   --------------------------------------------------------------- *)

Definition p (x : R) : R := x ^ 10 - x - 1.

Lemma p_continuous : forall a : R, continuity_pt p a.
Proof. intros a. unfold p. reg. Qed.

Lemma p_one_negative : p 1 < 0.
Proof. unfold p. simpl. lra. Qed.

Lemma p_two_positive : 0 < p 2.
Proof. unfold p. simpl. lra. Qed.

Theorem lambda_exists : { l : R | 1 <= l <= 2 /\ p l = 0 }.
Proof.
  apply IVT_interv.
  - intros a _. apply p_continuous.
  - lra.
  - apply p_one_negative.
  - apply p_two_positive.
Qed.

(* The root satisfies the retention relation, hence the square identity. *)
Theorem lambda_retention : forall l : R, p l = 0 -> l ^ 10 = l + 1.
Proof. intros l H. unfold p in H. lra. Qed.

Close Scope R_scope.

(* Rational bracket, the same statement Lean proves:
   p(a/b) < 0  <->  a^10 < b^9 (a+b). *)
Lemma lambda_lower_bracket : (43 ^ 10 <? 40 ^ 9 * (43 + 40))%Z = true.
Proof. reflexivity. Qed.

Lemma lambda_upper_bracket : (10 ^ 9 * (11 + 10) <? 11 ^ 10)%Z = true.
Proof. reflexivity. Qed.

(* ---------------------------------------------------------------
   8.  The RG fixed point                   E47-BRIDGE-009
   dD/d(ln b) = sigma (10 - D).  The fixed point is the kernel of the
   generator: the same construction as sections 2 and 4 with q = x.
   --------------------------------------------------------------- *)

Open Scope R_scope.

Definition rgGenerator (sigma D : R) : R := sigma * (10 - D).

(* deg(x^10 - x - 1), named so the coincidence below relates two definitions
   rather than letting the numeral 10 assert itself. *)
Definition retentionDegree : R := 10.

Theorem rg_fixed_point_unique : forall sigma D : R,
  sigma <> 0 -> (rgGenerator sigma D = 0 <-> D = 10).
Proof.
  intros sigma D Hs. unfold rgGenerator. split.
  - intros H. apply Rmult_integral in H. destruct H; lra.
  - intros H. rewrite H. ring.
Qed.

(* The flow is a contraction onto the fixed point: the deviation decays. *)
Theorem rg_contraction : forall sigma D : R, 0 < sigma ->
  rgGenerator sigma D = - sigma * (D - 10).
Proof. intros sigma D _. unfold rgGenerator. ring. Qed.

(* THREE TENS.  If the Hausdorff dimension of a marginal (d_s = 2) Lifshitz
   point equals the degree of the retention polynomial, then that dimension is
   exactly the zero of the RG generator, the point is self-dual, and the scaling
   data is forced to d = z = 5.  Corresponds to Lean's `three_tens`.
   sigma is unconstrained: the generator vanishes at the fixed point for every
   sigma, so no sigma <> 0 hypothesis is carried. *)
Corollary three_tens : forall sigma d z : R, z <> 0 ->
  ds d z = 2 -> dH d z = retentionDegree ->
  rgGenerator sigma (dH d z) = 0 /\ dw z = dH d z /\ d = 5 /\ z = 5.
Proof.
  intros sigma d z Hz Hs Hten.
  unfold retentionDegree in Hten.
  destruct (selection d z Hz Hs Hten) as [Hd [Hz5 [Hdw10 _]]].
  unfold rgGenerator. rewrite Hten.
  split. { ring. }
  split. { exact Hdw10. }
  split; assumption.
Qed.

Close Scope R_scope.

(* ---------------------------------------------------------------
   9.  Carrier against the selected dimension   E47-BRIDGE-006
   Arithmetic observation only.  No causal link asserted.
   --------------------------------------------------------------- *)

Lemma multiplet_dimension : dimJ 2 = 5.
Proof. reflexivity. Qed.

Lemma carrier_is_multiplet_cube : (dimJ 2) ^ 3 = carrier.
Proof. reflexivity. Qed.

(* ---------------------------------------------------------------
   10.  Omega evaluated at each instance    E47-BRIDGE-010
   --------------------------------------------------------------- *)

Lemma omega_table :
  kernelDim * 125 = 47 * carrier /\
  orbitCount 1 * 40 = 10 * wheelStations /\
  kernelDim * wheelStations <> orbitCount 1 * carrier.
Proof.
  split. { reflexivity. }
  split. { reflexivity. }
  rewrite kernel_47, carrier_125, wheel_kernel_is_registers.
  unfold wheelStations, wheelRegisters. lia.
Qed.

(* ---------------------------------------------------------------
   11.  The commutant, from the same table    E47-BRIDGE-011

   Schur: a representation decomposing with multiplicities m_J has
   commutant (+)_J M_{m_J}(C), of dimension sum_J m_J^2.  The commutant
   dimensions are therefore the SAME derived table as section 2, read
   through sum m^2 instead of sum m (2J+1).  This puts the E47Commutant
   values downstream of the Clebsch-Gordan recursion of section 1.

   Additive: nothing in sections 1-10 depends on this.
   --------------------------------------------------------------- *)

Definition commutantSelected : nat :=
  sumUpTo WIDTH (fun J => selected J * (mult J * mult J)).
Definition commutantCarrier : nat :=
  sumUpTo WIDTH (fun J => mult J * mult J).

(* dim (+) M_{m_J}(C) over the selected sectors: 5^2 + 2^2 = 29. *)
Lemma commutant_29 : commutantSelected = 29.
Proof. reflexivity. Qed.

(* Over the whole carrier: 1+9+25+16+9+4+1 = 65. *)
Lemma commutant_carrier_65 : commutantCarrier = 65.
Proof. reflexivity. Qed.

(* The projective (state-geometry) dimension: 29 - 1 = 28. *)
Lemma state_geometry_28 : commutantSelected - 1 = 28.
Proof. reflexivity. Qed.

(* One table, two readings. *)
Lemma commutant_from_multiplicities :
  mult 2 = 5 /\ mult 5 = 2 /\
  mult 2 * mult 2 + mult 5 * mult 5 = commutantSelected /\
  mult 2 * dimJ 2 + mult 5 * dimJ 5 = kernelDim.
Proof. repeat split; reflexivity. Qed.

(* ===================================================================
   Assumption ledger.
   =================================================================== *)

Print Assumptions cg_two.
Print Assumptions cg_three.
Print Assumptions carrier_125.
Print Assumptions kernel_47.
Print Assumptions dimension_identity.
Print Assumptions kernel_below_carrier.
Print Assumptions selected_sectors.
Print Assumptions isotypic_split.
Print Assumptions omega_c_exact.
Print Assumptions omega_wheel_quarter.
Print Assumptions wheel_crt_split.
Print Assumptions no_bridge.
Print Assumptions omega_c_ne_quarter.
Print Assumptions omega_c_real.
Print Assumptions wheel_period_exactly_four.
Print Assumptions wheel_ten_registers.
Print Assumptions wheel_kernel_is_registers.
Print Assumptions wheel_even_degenerates.
Print Assumptions triality.
Print Assumptions triality_classical.
Print Assumptions marginal_iff_isotropic.
Print Assumptions self_dual_iff_isotropic.
Print Assumptions spectral_two_blind_to_d.
Print Assumptions selection.
Print Assumptions retention_square.
Print Assumptions retention_square_10.
Print Assumptions pow_strict_mono.
Print Assumptions pow_inj.
Print Assumptions degree_lock.
Print Assumptions p_continuous.
Print Assumptions p_one_negative.
Print Assumptions p_two_positive.
Print Assumptions lambda_exists.
Print Assumptions lambda_retention.
Print Assumptions lambda_lower_bracket.
Print Assumptions lambda_upper_bracket.
Print Assumptions rg_fixed_point_unique.
Print Assumptions rg_contraction.
Print Assumptions three_tens.
Print Assumptions multiplet_dimension.
Print Assumptions carrier_is_multiplet_cube.
Print Assumptions omega_table.
Print Assumptions commutant_29.
Print Assumptions commutant_carrier_65.
Print Assumptions state_geometry_28.
Print Assumptions commutant_from_multiplicities.
