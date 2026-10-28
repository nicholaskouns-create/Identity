/-
  THE TEN-REGISTER THEOREM
  for the Sigillum Dei Aemeth wheel.

  Core Lean 4 only.  No Mathlib.  No axioms.  Every proof by `decide`,
  so the kernel re-executes the arithmetic itself.

  The wheel has 40 stations.  One click is  j |-> 3j + s  (mod 40).
  Claim: for every odd offset s, the wheel is a reversible machine whose
  state space splits into exactly TEN independent four-state registers.
-/
namespace Sigillum

/-- Stations on the rim. -/
def N : Nat := 40

/-- One click of the wheel at offset `s`. -/
def F (s j : Nat) : Nat := (3 * j + s) % N

/-- Four clicks from `j`. -/
def orbit (s j : Nat) : List Nat := [j, F s j, F s (F s j), F s (F s (F s j))]

/-- Canonical name of a register: its least station. -/
def rep (s j : Nat) : Nat := (orbit s j).foldr min j

/-- The stations that name their own register, i.e. one per register. -/
def reps (s : Nat) : List Nat := (List.range N).filter (fun j => rep s j == j)

/- ---------------------------------------------------------------- -/
/- PART I.  The machine is reversible and has period four.          -/
/-          True for every offset, odd or even.                     -/
/- ---------------------------------------------------------------- -/

theorem step_injective :
    ∀ s, s < N → ∀ i, i < N → ∀ j, j < N → F s i = F s j → i = j := by decide

theorem period_four :
    ∀ s, s < N → ∀ j, j < N → F s (F s (F s (F s j))) = j := by decide

/- ---------------------------------------------------------------- -/
/- PART II.  For ODD offsets the machine is primitive:              -/
/-           no station is fixed, no pair swaps.                     -/
/- ---------------------------------------------------------------- -/

theorem no_fixed_station :
    ∀ s, s < N → s % 2 = 1 → ∀ j, j < N → F s j ≠ j := by decide

theorem no_two_cycle :
    ∀ s, s < N → s % 2 = 1 → ∀ j, j < N → F s (F s j) ≠ j := by decide

/- ---------------------------------------------------------------- -/
/- PART III.  THE TEN-REGISTER THEOREM.                             -/
/-            Period four + primitive  =>  every orbit has length 4, -/
/-            and 40 = 4 * 10 forces exactly ten of them.            -/
/- ---------------------------------------------------------------- -/

theorem ten_registers :
    ∀ s, s < N → s % 2 = 1 → (reps s).length = 10 := by decide

/-- The compression ratio of the device: 40 states in, 10 registers out. -/
theorem omega_wheel : 10 * 4 = N := by decide

/-- Contrast: an even offset is NOT a ten-register machine. -/
theorem even_offset_degenerates : (reps 0).length = 13 := by decide

/- ---------------------------------------------------------------- -/
/- PART IV.  Constructive witness at the canonical offset s = 1.    -/
/-           The ten registers, written out.                        -/
/- ---------------------------------------------------------------- -/

def registers : List (List Nat) :=
  [[0,1,4,13], [2,7,22,27], [3,10,31,14], [5,16,9,28],  [6,19,18,15],
   [8,25,36,29], [11,34,23,30], [12,37,32,17], [20,21,24,33], [26,39,38,35]]

theorem witness_count  : registers.length = 10 := by decide
theorem witness_widths : registers.all (fun r => r.length == 4) = true := by decide
theorem witness_total  : registers.flatten.length = N := by decide

/-- Every station lies in some register. -/
theorem witness_covers :
    (List.range N).all (fun j => registers.any (fun r => r.contains j)) = true := by decide

/-- Each register is closed under one click: the registers do not talk. -/
theorem witness_closed :
    registers.all (fun r => r.all (fun j => r.contains (F 1 j))) = true := by decide

/- ---------------------------------------------------------------- -/
/- PART V.  The CRT refinement:  10 = 2 + 8, not merely 40 / 4.     -/
/-          Z_40 = Z_8 x Z_5.  The mod-5 factor has one fixed point  -/
/-          (station 2) and one four-cycle; the mod-8 factor has two  -/
/-          four-cycles.  Pairing them gives 2 + 2*4 = 10.           -/
/- ---------------------------------------------------------------- -/

theorem mod5_fixed_point : (3 * 2 + 1) % 5 = 2 := by decide

theorem crt_two_plus_eight :
    ((reps 1).filter (fun j => j % 5 == 2)).length = 2
  ∧ ((reps 1).filter (fun j => j % 5 != 2)).length = 8 := by decide

theorem crt_sums : 2 + 8 = 10 := by decide

end Sigillum

/-
  Axiom ledger.  `scripts/axiom_ledger.py` parses these lines and classifies
  every theorem; a `native_decide` axiom or a `sorryAx` here fails the gate.
  All fifteen report "does not depend on any axioms" on Lean 4.35.0.
-/
#print axioms Sigillum.step_injective
#print axioms Sigillum.period_four
#print axioms Sigillum.no_fixed_station
#print axioms Sigillum.no_two_cycle
#print axioms Sigillum.ten_registers
#print axioms Sigillum.omega_wheel
#print axioms Sigillum.even_offset_degenerates
#print axioms Sigillum.witness_count
#print axioms Sigillum.witness_widths
#print axioms Sigillum.witness_total
#print axioms Sigillum.witness_covers
#print axioms Sigillum.witness_closed
#print axioms Sigillum.mod5_fixed_point
#print axioms Sigillum.crt_two_plus_eight
#print axioms Sigillum.crt_sums
