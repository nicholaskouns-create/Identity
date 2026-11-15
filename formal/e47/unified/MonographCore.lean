namespace E47Monograph
def casimir (j : Nat) : Int := (j : Int) * ((j : Int) + 1)
def k (c : Int) : Int := (c - 6) * (c - 30)
def projectorNumerator (c : Int) : Int :=
  c * (c-2) * (c-12) * (c-20) * (c-31) * (c-42)
theorem carrier_dimension : ([1,9,25,28,27,22,13] : List Nat).foldl (· + ·) 0 = 125 := by decide
theorem kernel_dimension : 5*5 + 2*11 = 47 := by decide
theorem complement_dimension : 125 - 47 = 78 := by decide
theorem casimir_spectrum :
  (List.range 7).map casimir = [0,2,6,12,20,30,42] := by decide
theorem projector_sector_values :
  (List.range 7).map (fun j => projectorNumerator (casimir j)) =
    [0,0,1814400,0,0,1814400,0] := by decide
theorem kernel_roots : k 6 = 0 ∧ k 30 = 0 := by decide
theorem squared_syndrome_spectrum :
  (List.range 7).map (fun j => k (casimir j) * k (casimir j)) =
    [32400,12544,0,11664,19600,0,186624] := by decide
theorem minimax_step : 2 * 99144 = 11664 + 186624 := by decide
theorem minimax_radius :
  17 * (99144 - 11664) = 15 * 99144 ∧
  17 * (186624 - 99144) = 15 * 99144 := by decide
theorem off_kernel_bound :
  (List.range 7).all (fun j =>
    let v := k (casimir j)
    if v == 0 then true else
      17 * (99144 - v*v).natAbs <= 15 * 99144) = true := by decide
theorem matched_syndrome (f6 f12 f30 f42 omega : Int)
    (hLogical : f30 - f6 = omega)
    (hMatch : f42 = f12 + omega) :
    f42 - f30 = f12 - f6 := by
  omega
end E47Monograph
