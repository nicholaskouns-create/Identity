/- A fully specified finite-register E47 membership oracle.
   This is an abstract 47-state encoding, NOT a formalization of the spin-2 Casimir. -/
namespace E47EncodedOracle

def member (n : Fin 256) : Bool := decide (n.val < 47)

def gate (n : Fin 256) (target : Bool) : Bool :=
  if member n then !target else target

theorem gate_involution (n : Fin 256) (target : Bool) :
    gate n (gate n target) = target := by
  by_cases h : n.val < 47
  · simp [gate, member, h]
  · simp [gate, member, h]

theorem gate_preserves_data (n : Fin 256) (target : Bool) :
    (n, gate n target).1 = n := rfl

theorem gate_flips_member (n : Fin 256) (target : Bool)
    (h : n.val < 47) : gate n target = !target := by
  simp [gate, member, h]

theorem gate_fixes_nonmember (n : Fin 256) (target : Bool)
    (h : ¬ n.val < 47) : gate n target = target := by
  simp [gate, member, h]

theorem encoded_basis_count :
    ((List.range 256).filter (fun n => n < 47)).length = 47 := by
  decide

end E47EncodedOracle
