/- MC-121: exact finite spectral-selector action on the seven E47 Casimir eigenvalues.
   Paired with SpectralMask128.v. This module treats eigenvalues and sector
   dimensions as explicit constants established by the separate weight census.
   It does NOT identify the sectors with eigenspaces of the concrete 125x125 C.
   Nor does it assert a general spectral theorem for arbitrary operators. -/
set_option maxRecDepth 8192
set_option maxHeartbeats 0

namespace E47SpectralMask128

def eigenvalue (j : Nat) : Int :=
  match j with
  | 0 => 0
  | 1 => 2
  | 2 => 6
  | 3 => 12
  | 4 => 20
  | 5 => 30
  | 6 => 42
  | _ => -1

def sectorDim (j : Nat) : Nat :=
  match j with
  | 0 => 1
  | 1 => 9
  | 2 => 25
  | 3 => 28
  | 4 => 27
  | 5 => 22
  | 6 => 13
  | _ => 0

/-- A bit in [0,127] chooses one of the seven distinct spectral roots. -/
def selected (mask j : Nat) : Bool :=
  mask / (2 ^ j) % 2 == 1

/-- Product of (x - eigenvalue j) for precisely the selected roots. -/
def selector (mask : Nat) (x : Int) : Int :=
  ((List.range 7).filter (selected mask)).foldl
    (fun acc j => acc * (x - eigenvalue j)) 1

/-- Weighted number of sectors where the selector vanishes. -/
def kernelDimFromAction (mask : Nat) : Nat :=
  (List.range 7).foldl
    (fun acc j =>
      acc + (if selector mask (eigenvalue j) == 0 then sectorDim j else 0)) 0

/-- Weighted number of bits explicitly selected by the mask. -/
def selectedDim (mask : Nat) : Nat :=
  (List.range 7).foldl
    (fun acc j => acc + (if selected mask j then sectorDim j else 0)) 0

/-- Exhaustive exact check: 128 masks x 7 eigenvalues = 896 root-action cases. -/
theorem all_128_selector_zero_patterns :
    ((List.range 128).all fun mask =>
      (List.range 7).all fun j =>
        ((selector mask (eigenvalue j) == 0) == selected mask j)) = true := by
  decide

/-- The two independently defined weighted dimensions agree for all 128 masks. -/
theorem all_128_selector_dimensions :
    ((List.range 128).all fun mask =>
      kernelDimFromAction mask == selectedDim mask) = true := by
  decide

theorem empty_selector_dimension : kernelDimFromAction 0 = 0 := by decide
theorem full_selector_dimension : kernelDimFromAction 127 = 125 := by decide
theorem e47_selector_dimension : kernelDimFromAction 36 = 47 := by decide
theorem maximal_quadratic_selector_dimension :
    kernelDimFromAction 24 = 55 := by decide

end E47SpectralMask128

#print axioms E47SpectralMask128.all_128_selector_zero_patterns
#print axioms E47SpectralMask128.all_128_selector_dimensions
#print axioms E47SpectralMask128.empty_selector_dimension
#print axioms E47SpectralMask128.full_selector_dimension
#print axioms E47SpectralMask128.e47_selector_dimension
#print axioms E47SpectralMask128.maximal_quadratic_selector_dimension
