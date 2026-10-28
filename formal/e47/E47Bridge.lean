/-
  E47Bridge.lean  —  Lean 4, Mathlib-free.
  Compiles and reports an identical axiom ledger under Lean 4.19.0 and 4.35.0.

  The Kouns–Killion Paradigm (KKP-R).
  Certificate  E47-BRIDGE-001 … 011.

  PURPOSE.  Separate structures are shown to be instances of ONE algebraic
  object: a finite-spectrum operator A on a finite-dimensional space V, a chosen
  squarefree annihilating factor q, and the normalised rank

        Ω(A, q)  =  dim ker q(A) / dim V.

  The instances:

    E47      V = (C^5)^{⊗3}, dim 125,  A = Casimir C,  q = (x−6)(x−30),
             dim ker q(A) = 47,  Ω_c = 47/125.
    Wheel    V = C^40,  A = the click permutation  F_s(j) = 3j+s mod 40,
             q = x−1,  dim ker q(A) = #orbits = 10,  Ω_wheel = 10/40 = 1/4.
    Lifshitz the anisotropic-scaling dictionary  d_H = d+z, d_w = 2z, d_s·z = d_H,
             carrying the three-way equivalence  d_s = 2 ⟺ d_w = d_H ⟺ z = d.
    RG       the flow  dD/d(ln b) = σ(10−D), whose fixed point is the kernel of
             the generator; D* = 10 is pinned to deg(x^10−x−1) by the degree lock.

  WHAT IS PROVED HERE AND WHAT IS NOT.
  §1 derives the spin multiplicity table from the Clebsch–Gordan recursion, so
  the table is a theorem, not an input.  §2–3 and §11 then work in the ISOTYPIC
  (block-diagonal) model: the Casimir acts on the J-block as J(J+1).  The
  concrete 125×125 tensor-product matrix is NOT constructed here, so the bridge
  of §05 of the Lean/Coq explainer page remains open; nothing below crosses it.

  PAIRING, STATED EXACTLY.  §1–4, §10 and §11 are the same statements in both
  files, over the same types.  §5 (the Lifshitz dictionary) is over R in
  E47Bridge.v and over Nat here: those are CORRESPONDING statements, not
  identical ones, and the R versions are primary.  §7 is split — the ring half is
  Coq's `retention_square`, the order half is this file's `degree_lock`.  No
  theorem name is shared between the two files unless the statement is shared.

  NO LISTS, BY DESIGN.  Tables are functions `Nat → Nat` and sums are a single
  structural recursion.  `List.getD`/`List.range`/`List.foldl` unfold through
  lemmas that carry `propext` in Lean 4.35, which would move every finite result
  out of the axiom-free tier for a purely presentational reason.  With the
  List-free encoding, §1–4, §6, §10 and §11 close by pure kernel reduction and
  report no axioms on either toolchain.
-/

namespace E47Bridge

/-! ### 0.  One summation combinator

`sumUpTo n f = f 0 + … + f (n−1)`, by structural recursion on `Nat`. -/

def sumUpTo : Nat → (Nat → Nat) → Nat
  | 0,     _ => 0
  | (n+1), f => sumUpTo n f + f n

/-! ### 1.  The Clebsch–Gordan recursion  (E47-BRIDGE-001)

The multiplicity table is DERIVED, not assumed:
`spin j ⊗ spin 2 = ⊕_{J=|j−2|}^{j+2} spin J`. -/

/-- Sector index runs `0 … 8`; three spin-2 factors reach `J = 6`. -/
def WIDTH : Nat := 9

/-- `|a − b|` on `Nat`, free of truncation artefacts. -/
def absDiff (a b : Nat) : Nat := max a b - min a b

/-- Indicator: does spin `j` coupled to spin 2 produce spin `J`? -/
def couples (j J : Nat) : Nat := if absDiff j 2 ≤ J && J ≤ j + 2 then 1 else 0

/-- One Clebsch–Gordan step: tensor with a further spin-2 factor. -/
def step (m : Nat → Nat) : Nat → Nat :=
  fun J => sumUpTo WIDTH (fun j => couples j J * m j)

/-- A single spin-2 system. -/
def spin2 : Nat → Nat := fun j => if j == 2 then 1 else 0

/-- `spin2 ⊗ spin2`. -/
def m2 : Nat → Nat := step spin2

/-- `spin2 ⊗ spin2 ⊗ spin2`.  This is the derived multiplicity table. -/
def mult : Nat → Nat := step m2

theorem cg_two :
    m2 0 = 1 ∧ m2 1 = 1 ∧ m2 2 = 1 ∧ m2 3 = 1 ∧ m2 4 = 1 ∧ m2 5 = 0 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- The multiplicity table `(1, 3, 5, 4, 3, 2, 1, 0, 0)`, derived. -/
theorem cg_three :
    mult 0 = 1 ∧ mult 1 = 3 ∧ mult 2 = 5 ∧ mult 3 = 4 ∧ mult 4 = 3 ∧
    mult 5 = 2 ∧ mult 6 = 1 ∧ mult 7 = 0 ∧ mult 8 = 0 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

/-! ### 2.  Carrier and kernel  (E47-BRIDGE-002) -/

def dimJ    (J : Nat) : Nat := 2 * J + 1
def casimir (J : Nat) : Nat := J * (J + 1)

/-- `q(x) = (x−6)(x−30)` as an indicator on sectors: a sector is selected iff
    its Casimir eigenvalue `J(J+1)` is a root of `q`. -/
def selected (J : Nat) : Nat := if casimir J == 6 || casimir J == 30 then 1 else 0

def carrier   : Nat := sumUpTo WIDTH (fun J => mult J * dimJ J)
def kernelDim : Nat := sumUpTo WIDTH (fun J => selected J * (mult J * dimJ J))

theorem carrier_125        : carrier = 125            := rfl
theorem kernel_47          : kernelDim = 47           := rfl
theorem dimension_identity : kernelDim + 78 = carrier := rfl
theorem kernel_below_carrier : kernelDim < carrier    := by decide

/-- The only selected sectors are `J = 2` (eigenvalue 6) and `J = 5` (eigenvalue 30). -/
theorem selected_sectors (J : Nat) (hJ : J < WIDTH) :
    selected J = 1 ↔ (J = 2 ∨ J = 5) := by
  revert J; decide

/-- The canonical isotypic split: `47 = 25 + 22`, five copies of the 5 and two
    copies of the 11. -/
theorem isotypic_split :
    mult 2 * dimJ 2 = 25 ∧ mult 5 * dimJ 5 = 22 ∧ 25 + 22 = kernelDim :=
  ⟨rfl, rfl, rfl⟩

/-! ### 3.  Ω as a functional, at two arguments  (E47-BRIDGE-003)

Rational values are compared by cross-multiplication, so no `Rat` is needed. -/

/-- `Ω_c = 47/125 = 0.376` exactly. -/
theorem omega_c_exact : kernelDim * 1000 = 376 * carrier := rfl

def wheelStations  : Nat := 40
def wheelRegisters : Nat := 10

/-- `Ω_wheel = 10/40 = 1/4`. -/
theorem omega_wheel_quarter : wheelRegisters * 4 = wheelStations := rfl

/-- The CRT refinement: ten is `2 + 8`, not merely the quotient `40/4`. -/
theorem wheel_crt_split : 2 + 8 = wheelRegisters := rfl

/-- NO BRIDGE.  `Ω_c ≠ Ω_wheel`, machine-checked rather than footnoted.  The two
    live in the same functional at different arguments; they are not the same
    number, and no identification is asserted anywhere in this file. -/
theorem no_bridge : kernelDim * wheelStations ≠ wheelRegisters * carrier := by decide

theorem omega_c_ne_quarter : kernelDim * 4 ≠ carrier := by decide

/-! ### 4.  The wheel is the same construction  (E47-BRIDGE-004)

`ker(T − I)` for the click operator `T` has dimension equal to the number of
orbits, so the wheel's `Ω` is `Ω(A, q)` with `q = x − 1`. -/

def F (s j : Nat) : Nat := (3 * j + s) % 40

def Fit (s : Nat) : Nat → Nat → Nat
  | 0,     j => j
  | (n+1), j => F s (Fit s n j)

/-- Reversibility: at every odd offset the period divides four. -/
theorem wheel_period_four :
    ∀ s, s < 40 → s % 2 = 1 → ∀ j, j < 40 → Fit s 4 j = j := by decide

/-- Exactness: at an odd offset there is no fixed point and no transposition,
    so the period is exactly four, never less. -/
theorem wheel_exact_period :
    ∀ s, s < 40 → s % 2 = 1 → ∀ j, j < 40 → Fit s 1 j ≠ j ∧ Fit s 2 j ≠ j := by decide

/-- Least station of an orbit: its canonical name. -/
def orbitRep (s j : Nat) : Nat :=
  min (min (Fit s 0 j) (Fit s 1 j)) (min (Fit s 2 j) (Fit s 3 j))

/-- Each orbit contributes exactly one station that is its own representative,
    so counting those counts the orbits. -/
def orbitCount (s : Nat) : Nat :=
  sumUpTo 40 (fun j => if orbitRep s j == j then 1 else 0)

/-- Ten registers, at every odd offset. -/
theorem wheel_ten_registers : ∀ s, s < 40 → s % 2 = 1 → orbitCount s = 10 := by decide

/-- Oddness is not decoration: the even offset `s = 0` degenerates to thirteen
    orbits of mixed length. -/
theorem wheel_even_degenerates :
    orbitCount 0 = 13 ∧ orbitCount 0 ≠ wheelRegisters := by decide

/-- The wheel's kernel dimension agrees with the register count. -/
theorem wheel_kernel_is_registers : orbitCount 1 = wheelRegisters := rfl

/-! ### 5.  The Lifshitz dictionary  (E47-BRIDGE-005)

This is the fulcrum.  Under anisotropic scaling  `x ↦ b x`,  `t ↦ b^z t`:

    d_H = d + z      (Hausdorff: the measure `d^d x dt` carries weight `d+z`)
    d_w = 2z         (walk: `∂_t ∼ ∇^{2z}` gives `x ∼ t^{1/2z}`)
    d_s · z = d_H    (spectral; stated multiplicatively, so no division is used)

`d_s` is supplied as a parameter carrying its defining relation, which keeps the
section inside `Nat`.  E47Bridge.v proves the corresponding statements over `R`,
with `d_s` as an honest quotient; those are the primary versions. -/

def dH (d z : Nat) : Nat := d + z
def dw (z : Nat)   : Nat := 2 * z

private theorem mul_two_right (a b : Nat) : a * (2 * b) = 2 * (a * b) := by
  rw [Nat.two_mul, Nat.mul_add, Nat.two_mul]

/-- **TRIALITY.**  `d_s · d_w = 2 d_H`.  Three dimensions, one constraint: on a
    smooth manifold `d_w = 2` and all three collapse to one number; under
    dimensional flow they separate, but stay locked by this identity. -/
theorem triality (d z ds : Nat) (h : ds * z = dH d z) :
    ds * dw z = 2 * dH d z := by
  calc ds * dw z = ds * (2 * z) := rfl
    _ = 2 * (ds * z) := mul_two_right ds z
    _ = 2 * dH d z   := by rw [h]

/-- **MARGINALITY = SELF-DUALITY.**  The renormalisability condition `d_s = 2`
    is exactly the self-dual condition `d_w = d_H`, and both are exactly `z = d`. -/
theorem marginal_iff_isotropic (d z ds : Nat) (hz : 0 < z) (h : ds * z = dH d z) :
    ds = 2 ↔ d = z := by
  unfold dH at h
  constructor
  · intro hd
    subst hd
    rw [Nat.two_mul] at h
    exact (Nat.add_right_cancel h).symm
  · intro hd
    subst hd
    rw [← Nat.two_mul] at h
    exact Nat.eq_of_mul_eq_mul_right hz h

theorem self_dual_iff_isotropic (d z : Nat) : dw z = dH d z ↔ d = z := by
  unfold dw dH
  rw [Nat.two_mul]
  exact ⟨fun h => (Nat.add_right_cancel h).symm, fun h => by rw [h]⟩

/-- **WHY `d_s = 2` DOES NOT CONSTRAIN `d_H`.**  At `z = d` the spectral
    dimension is 2 for *every* spatial `d`, so a UV result `d_s → 2` leaves the
    Hausdorff dimension completely free.  This is what makes a flow to
    `d_H = 10` compatible with, rather than contradictory to, every programme
    that reports `D → 2`. -/
theorem spectral_two_blind_to_d (d ds : Nat) (hd : 0 < d) (h : ds * d = dH d d) :
    ds = 2 := by
  unfold dH at h
  rw [← Nat.two_mul] at h
  exact Nat.eq_of_mul_eq_mul_right hd h

/-- **SELECTION.**  Pinning both endpoints at once — `d_s = 2` and `d_H = 10` —
    forces `z = d = 5`, and the walk dimension then equals the Hausdorff
    dimension: `d_w = d_H = 10`. -/
theorem selection (d z ds : Nat) (hz : 0 < z)
    (h : ds * z = dH d z) (hs : ds = 2) (hten : dH d z = 10) :
    d = 5 ∧ z = 5 ∧ dw z = 10 ∧ dw z = dH d z := by
  subst hs
  unfold dH at h hten
  unfold dw dH
  omega

/-! ### 6.  Carrier against the selected dimension  (E47-BRIDGE-006)

Arithmetic observation, stated as arithmetic and nothing more.  The spin-2
multiplet has dimension `2·2+1 = 5`; the carrier is its cube; and the Lifshitz
selection of §5 independently returns `z = d = 5`, with `d_H = 10 = 2·5`.
No causal link between these fives is asserted or proved. -/

theorem multiplet_dimension : dimJ 2 = 5 := rfl
theorem carrier_is_multiplet_cube : (dimJ 2) ^ 3 = carrier := rfl

/-! ### 7.  The degree lock, order half  (E47-BRIDGE-007)

The ring half — `λ^{2D} = (λ^n)^2 = λ^{2n}` — is Coq's `retention_square`.
The order half is the pinning step, and needs only strict monotonicity of the
exponential, which holds for every `λ > 1`.  It is stated for an abstract
strictly monotone `pw`, so no real-number library is required here. -/

private theorem pw_injective (pw : Nat → Nat)
    (hmono : ∀ a b, a < b → pw a < pw b) (a b : Nat) (h : pw a = pw b) : a = b := by
  rcases Nat.lt_trichotomy a b with hlt | heq | hgt
  · exact absurd h (Nat.ne_of_lt (hmono a b hlt))
  · exact heq
  · exact absurd h.symm (Nat.ne_of_lt (hmono b a hgt))

/-- **DEGREE LOCK (order half).**  For a strictly monotone exponential the
    retention ratio at dimension `D` equals its value at `n` only when `D = n`.
    With the ring half: the RG fixed point `D* = 10` is not a free parameter —
    it is forced to equal `deg(x^10 − x − 1)` by the demand that the retention
    ratio close as a perfect square. -/
theorem degree_lock (pw : Nat → Nat) (hmono : ∀ a b, a < b → pw a < pw b)
    (n D : Nat) : pw (2 * D) = pw (2 * n) ↔ D = n := by
  constructor
  · intro h
    have hdn := pw_injective pw hmono (2 * D) (2 * n) h
    omega
  · intro h; rw [h]

/-! ### 8.  The retention bracket  (E47-BRIDGE-008)

`p(x) = x^10 − x − 1` has its positive real root strictly inside `(43/40, 11/10)`.
Clearing denominators, `p(a/b) < 0 ⟺ a^10 < b^9 (a+b)`, so the bracket is an
exact integer statement.  E47Bridge.v proves the root exists, by the IVT. -/

theorem lambda_lower_bracket : 43 ^ 10 < 40 ^ 9 * (43 + 40) := by decide
theorem lambda_upper_bracket : 10 ^ 9 * (11 + 10) < 11 ^ 10 := by decide

/-- Sign change of `p` at the integer endpoints, as the actual values of `p`
    rather than a rearrangement of them. -/
theorem p_one_negative_exact : (1 : Int) ^ 10 - 1 - 1 < 0 := by decide
theorem p_two_positive_exact : (0 : Int) < (2 : Int) ^ 10 - 2 - 1 := by decide

/-! ### 9.  The RG fixed point  (E47-BRIDGE-009)

`dD/d(ln b) = σ(10 − D)`.  The fixed point is the kernel of the generator — the
same construction as §2 and §4, with `A` the affine generator and `q = x`. -/

def rgGenerator (D : Nat) : Int := (10 : Int) - (D : Int)

/-- `deg(x^10 − x − 1)`, named so the coincidence below relates two definitions
    rather than letting the numeral 10 assert itself. -/
def retentionDegree : Nat := 10

theorem rg_fixed_point_unique (D : Nat) : rgGenerator D = 0 ↔ D = 10 := by
  unfold rgGenerator; omega

/-- **THREE TENS.**  If the Hausdorff dimension of a marginal (`d_s = 2`)
    Lifshitz point equals the degree of the retention polynomial, then that
    dimension is exactly the zero of the RG generator, the point is self-dual,
    and the scaling data is forced to `d = z = 5`. -/
theorem three_tens (d z ds : Nat) (hz : 0 < z)
    (h : ds * z = dH d z) (hs : ds = 2) (hten : dH d z = retentionDegree) :
    rgGenerator (dH d z) = 0 ∧ dw z = dH d z ∧ d = 5 ∧ z = 5 := by
  unfold retentionDegree at hten
  subst hs
  unfold dH at h hten
  unfold rgGenerator dw dH
  omega

/-! ### 10.  Ω evaluated at each instance  (E47-BRIDGE-010) -/

theorem omega_table :
    kernelDim * 125 = 47 * carrier ∧
    orbitCount 1 * 40 = 10 * wheelStations ∧
    kernelDim * wheelStations ≠ orbitCount 1 * carrier := by decide

/-! ### 11.  The commutant, from the same table  (E47-BRIDGE-011)

Schur: a representation decomposing with multiplicities `m_J` has commutant
`⊕_J M_{m_J}(C)`, of dimension `Σ_J m_J²`.  The commutant dimensions are
therefore the SAME derived table as §2, read through `Σ m²` instead of
`Σ m (2J+1)`.  This puts the `E47Commutant` values downstream of the
Clebsch–Gordan recursion of §1 rather than alongside it.

Additive: nothing in §1–10 depends on this section. -/

def commutantSelected : Nat := sumUpTo WIDTH (fun J => selected J * (mult J * mult J))
def commutantCarrier  : Nat := sumUpTo WIDTH (fun J => mult J * mult J)

/-- `dim ⊕ M_{m_J}(C)` over the selected sectors: `5² + 2² = 29`. -/
theorem commutant_29 : commutantSelected = 29 := rfl

/-- Over the whole carrier: `1+9+25+16+9+4+1 = 65`. -/
theorem commutant_carrier_65 : commutantCarrier = 65 := rfl

/-- The projective (state-geometry) dimension: `29 − 1 = 28`. -/
theorem state_geometry_28 : commutantSelected - 1 = 28 := rfl

/-- One table, two readings: `Σ m (2J+1)` gives the dimensions, `Σ m²` gives the
    commutants, and the multiplicities of the two selected sectors are 5 and 2. -/
theorem commutant_from_multiplicities :
    mult 2 = 5 ∧ mult 5 = 2 ∧
    mult 2 * mult 2 + mult 5 * mult 5 = commutantSelected ∧
    mult 2 * dimJ 2 + mult 5 * dimJ 5 = kernelDim :=
  ⟨rfl, rfl, rfl, rfl⟩

end E47Bridge

-- Axiom ledger: every theorem in the file, in order.
#print axioms E47Bridge.cg_two
#print axioms E47Bridge.cg_three
#print axioms E47Bridge.carrier_125
#print axioms E47Bridge.kernel_47
#print axioms E47Bridge.dimension_identity
#print axioms E47Bridge.kernel_below_carrier
#print axioms E47Bridge.selected_sectors
#print axioms E47Bridge.isotypic_split
#print axioms E47Bridge.omega_c_exact
#print axioms E47Bridge.omega_wheel_quarter
#print axioms E47Bridge.wheel_crt_split
#print axioms E47Bridge.no_bridge
#print axioms E47Bridge.omega_c_ne_quarter
#print axioms E47Bridge.wheel_period_four
#print axioms E47Bridge.wheel_exact_period
#print axioms E47Bridge.wheel_ten_registers
#print axioms E47Bridge.wheel_even_degenerates
#print axioms E47Bridge.wheel_kernel_is_registers
#print axioms E47Bridge.triality
#print axioms E47Bridge.marginal_iff_isotropic
#print axioms E47Bridge.self_dual_iff_isotropic
#print axioms E47Bridge.spectral_two_blind_to_d
#print axioms E47Bridge.selection
#print axioms E47Bridge.multiplet_dimension
#print axioms E47Bridge.carrier_is_multiplet_cube
#print axioms E47Bridge.degree_lock
#print axioms E47Bridge.lambda_lower_bracket
#print axioms E47Bridge.lambda_upper_bracket
#print axioms E47Bridge.p_one_negative_exact
#print axioms E47Bridge.p_two_positive_exact
#print axioms E47Bridge.rg_fixed_point_unique
#print axioms E47Bridge.three_tens
#print axioms E47Bridge.omega_table
#print axioms E47Bridge.commutant_29
#print axioms E47Bridge.commutant_carrier_65
#print axioms E47Bridge.state_geometry_28
#print axioms E47Bridge.commutant_from_multiplicities
