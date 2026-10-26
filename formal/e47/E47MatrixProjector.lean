/-
  Integer 125x125 sl2 model of three spin-2 particles, and the exact rank-47
  projector built from its Casimir. Lean companion to E47MatrixProjector.v.
  The Coq file is the primary one and proves everything; this file proves a
  subset of the same statements (the rest is listed under LEAN-ONLY OMISSIONS).
  Self-contained: core Lean 4 only, no Mathlib, no declared axioms, no sorry.
  Every matrix theorem is proved with `decide +kernel`: the Lean kernel itself
  evaluates the closed Boolean. This is not `native_decide`; there is no
  `Lean.ofReduceBool` and no compiler trust. `#print axioms` at the end of the
  file shows that the theorems depend at most on Lean's three standard axioms
  (propext, Classical.choice, Quot.sound), which enter through the library
  Decidable instances, never through a declared axiom of this file.

  THE MODEL
  Per factor (spin 2, basis index k = 0..4 for m = 2-k):
    Jz = diag(2,1,0,-1,-2),  Jm e_k = e_{k+1},  Jp e_k = k(5-k) e_{k-1}.
  These are the usual spin-2 operators after a diagonal rescaling of the basis
  that removes every square root. The same rescaling D (x) D (x) D on the
  three-fold product turns the normalized total ladders into sums of these
  matrices, so the model is similar to the real Hermitian one and polynomial
  identities in the Casimir carry over. Totals are Kronecker sums
  Jtot a = a(x)1(x)1 + 1(x)a(x)1 + 1(x)1(x)a. C = Jz^2 + Jz + Jm*Jp, an integer
  125x125 matrix, and 2C = 2Jz^2 + Jp*Jm + Jm*Jp.

  REPRESENTATION AND THE PRODUCT USED
  The Lean kernel is slow on dense 125x125 lists, so the main computations use
  sparse integer matrices: a matrix is a list of rows, a row is a sorted list of
  (column, nonzero entry) pairs, and `mmul` forms row i of A*B as the sum of
  a_ik * (row k of B) over the nonzero entries a_ik. Kronecker sums, sums and
  scalings are done in the same representation. Links to plain dense matrices:
  (a) bridge_kron_sums: the sparse Kronecker sums Jz3, Jp3, Jm3, expanded to dense
  125x125 lists of lists, equal the textbook dense Kronecker sums; (b)
  bridge_product_5 and bridge_product_25: the sparse `mmul` agrees with the
  textbook dense product (`mmulDense`) on the 5-dim factor and on the 25-dim
  two-particle space (same code, sizes where the dense kernel product is cheap);
  (c) the Coq file proves all the same statements with plain dense matrices.
  General correctness of the sparse `mmul` for arbitrary matrices, and a dense
  125x125 product check inside Lean, are NOT proved in Lean: a dense 125x125
  product check needs more than 13 GB in the Lean kernel and was killed.

  WHAT IS FORMALIZED HERE (each is a closed equality between explicit matrices)
  1. Dimensions: Jz, Jp, Jm, C are 125x125.
  2. sl2 relations on the 125-dim space: [Jz,Jp] = Jp, [Jz,Jm] = -Jm,
     [Jp,Jm] = 2Jz, and 2C = 2Jz^2 + Jp Jm + Jm Jp.
  3. The diagonal of Jz (and Jz being diagonal) has weight counts 19,18,15,10,6,3,1 for m = 0..6 and
     agrees with the weight function w of E47WeightAlgebra.lean (restated).
  4. Minimal polynomial identity M(C) = 0, M(x) = x(x-2)(x-6)(x-12)(x-20)(x-30)(x-42).
  5. A = C(C-2)(C-12)(C-20)(C-31)(C-42) satisfies A*A = 1814400*A,
     trace A = 47*1814400, K*A = 0 for K = (C-6)(C-30).
  6. trace(C^k), k = 0..6, equals sum_j mult_j (2j+1) (j(j+1))^k with the
     weight-algebra multiplicities 1,3,5,4,3,2,1.
  7. The numbers behind the spectral projectors: d_i = prod_{l<>i}(c_i - c_l) =
     3628800, -1612800, 1741824, -3110400, 8870400, -43545600, 479001600,
     12! = lcm |d_i|, block sizes mult_i (2 j_i + 1) = 1,9,25,28,27,22,13, total 125.
  8. Bridges listed above.

  WHAT IS NOT FORMALIZED
  * Rank equals trace for an idempotent, and the step "M(C) = 0 plus spectral
    idempotents with these traces means eigenvalue c_i has multiplicity
    trace(E_i)", are standard linear algebra, taken as input. Together with
    items 4-7 they give: C has exactly the eigenvalues 0,2,6,12,20,30,42 with
    multiplicities 1,9,25,28,27,22,13 and rank P = rank ker K = 47.
  * LEAN-ONLY OMISSIONS, because the kernel runs out of memory (peak 8 GB or more
    each): A equals its expanded polynomial; N_i*N_i = d_i*N_i; trace N_i = d_i*size_i;
    sum_i (Dd/d_i) N_i = Dd*I; d_2 d_5 A = 1814400 (d_5 N_2 + d_2 N_5). These ARE
    proved in E47MatrixProjector.v (Coq). In Lean only the projector facts of item 5
    and the numbers of item 7 are proved.
  * The explicit diagonal rescaling that makes this integer model similar to
    the Hermitian Jx, Jy, Jz of simulation/e47_tqgnn/ is not formalized. Singular
    values and the 2-norm rate (15/17)^n are not proved here.
  * General correctness of the sparse `mmul` (see above).
-/

namespace MatrixProjector

set_option maxRecDepth 1000000

/-! ### Dense reference matrices (textbook definitions, used only by the bridge theorems) -/

abbrev Mat := List (List Int)

def dot : List Int → List Int → Int
  | a :: u, b :: v => a * b + dot u v
  | _, _ => 0

def transposeN : Nat → Mat → Mat
  | 0, _ => []
  | n + 1, M => M.map (fun r => r.headD 0) :: transposeN n (M.map List.tail)

/-- Textbook dense product. -/
def mmulDense (A B : Mat) : Mat :=
  A.map fun r => (transposeN ((B.headD []).length) B).map fun c => dot r c

def zipw (f : Int → Int → Int) : List Int → List Int → List Int
  | a :: u, b :: v => f a b :: zipw f u v
  | _, _ => []

def maddDense : Mat → Mat → Mat
  | r :: A, s :: B => zipw (· + ·) r s :: maddDense A B
  | _, _ => []

def mkDense (n : Nat) (f : Nat → Nat → Int) : Mat :=
  (List.range n).map fun i => (List.range n).map fun j => f i j

def identDense (n : Nat) : Mat := mkDense n fun i j => if i = j then 1 else 0

def kronDense (A B : Mat) : Mat :=
  A.flatMap fun ra => B.map fun rb => ra.flatMap fun a => rb.map fun b => a * b

def Jz5 : Mat := [[2,0,0,0,0],[0,1,0,0,0],[0,0,0,0,0],[0,0,0,-1,0],[0,0,0,0,-2]]
/-- Jp e_k = k(5-k) e_{k-1}: entry (k-1,k) = 4,6,6,4 for k = 1..4. -/
def Jp5 : Mat := [[0,4,0,0,0],[0,0,6,0,0],[0,0,0,6,0],[0,0,0,0,4],[0,0,0,0,0]]
/-- Jm e_k = e_{k+1}. -/
def Jm5 : Mat := [[0,0,0,0,0],[1,0,0,0,0],[0,1,0,0,0],[0,0,1,0,0],[0,0,0,1,0]]
def I5 : Mat := identDense 5

def JtotDense (a : Mat) : Mat :=
  maddDense (maddDense (kronDense (kronDense a I5) I5) (kronDense (kronDense I5 a) I5))
    (kronDense (kronDense I5 I5) a)

/-! ### Sparse integer matrices: rows are sorted lists of (column, nonzero entry) -/

abbrev SRow := List (Nat × Int)
abbrev SMat := List SRow

def addRowF : Nat → SRow → SRow → SRow
  | 0, _, _ => []
  | _ + 1, [], r => r
  | _ + 1, r, [] => r
  | f + 1, (i, a) :: u, (j, b) :: v =>
    if i < j then (i, a) :: addRowF f u ((j, b) :: v)
    else if j < i then (j, b) :: addRowF f ((i, a) :: u) v
    else if a + b = 0 then addRowF f u v
    else (i, a + b) :: addRowF f u v

def addRow (u v : SRow) : SRow := addRowF (u.length + v.length) u v

def scaleRow (k : Int) (r : SRow) : SRow :=
  if k = 0 then [] else r.map fun p => (p.1, k * p.2)

/-- Row of a product: sum of a_k * (row k of B) over the nonzero entries of the row. -/
def rowTimes (r : SRow) (B : SMat) : SRow :=
  r.foldl (fun acc p => addRow acc (scaleRow p.2 (B.getD p.1 []))) []

def mmul (A B : SMat) : SMat := A.map fun r => rowTimes r B

def madd : SMat → SMat → SMat
  | r :: A, s :: B => addRow r s :: madd A B
  | _, _ => []

def mscale (k : Int) (A : SMat) : SMat := A.map (scaleRow k)
def msub (A B : SMat) : SMat := madd A (mscale (-1) B)

def ident (n : Nat) : SMat := (List.range n).map fun i => [(i, (1 : Int))]

def mtrace (A : SMat) : Int :=
  (((List.range A.length).map fun i => ((A.getD i []).lookup i).getD 0)).sum

def diagS (A : SMat) : List Int :=
  (List.range A.length).map fun i => ((A.getD i []).lookup i).getD 0

/-- Kronecker product; row (i1,i2) lists the entries a_{i1 j1} b_{i2 j2} at column j1*nB + j2. -/
def kron (nB : Nat) (A B : SMat) : SMat :=
  A.flatMap fun ra => B.map fun rb =>
    ra.flatMap fun pa => rb.map fun pb => (pa.1 * nB + pb.1, pa.2 * pb.2)

def ofDense (A : Mat) : SMat :=
  A.map fun r => ((List.range r.length).zip r).filter (fun p => p.2 != 0)

def toDense (n : Nat) (A : SMat) : Mat :=
  A.map fun r => (List.range n).map fun j => (r.lookup j).getD 0

def sJz5 : SMat := ofDense Jz5
def sJp5 : SMat := ofDense Jp5
def sJm5 : SMat := ofDense Jm5
def sI5 : SMat := ident 5

def Jtot (a : SMat) : SMat :=
  madd (madd (kron 5 (kron 5 a sI5) sI5) (kron 5 (kron 5 sI5 a) sI5)) (kron 5 (kron 5 sI5 sI5) a)

def Jz3 : SMat := Jtot sJz5
def Jp3 : SMat := Jtot sJp5
def Jm3 : SMat := Jtot sJm5

/-- Casimir: C = Jz^2 + Jz + Jm*Jp. -/
def C : SMat := madd (madd (mmul Jz3 Jz3) Jz3) (mmul Jm3 Jp3)

def I125 : SMat := ident 125
def zero125 : SMat := (List.range 125).map fun _ => []

def isSquare (n : Nat) (A : SMat) : Bool :=
  A.length == n && A.all fun r => r.all fun p => p.1 < n

/-! ### 1. Dimensions -/

theorem dims_125 :
    isSquare 125 Jz3 = true ∧ isSquare 125 Jp3 = true ∧
    isSquare 125 Jm3 = true ∧ isSquare 125 C = true := by
  decide +kernel

/-! ### 2. sl2 relations on the 125-dim space -/

def comm (X Y : SMat) : SMat := msub (mmul X Y) (mmul Y X)

theorem sl2_zp : comm Jz3 Jp3 = Jp3 := by decide +kernel
theorem sl2_zm : comm Jz3 Jm3 = mscale (-1) Jm3 := by decide +kernel
theorem sl2_pm : comm Jp3 Jm3 = mscale 2 Jz3 := by decide +kernel

/-- 2C = 2 Jz^2 + Jp Jm + Jm Jp, the usual symmetric form of the Casimir. -/
theorem casimir_symmetric_form :
    mscale 2 C = madd (mscale 2 (mmul Jz3 Jz3)) (madd (mmul Jp3 Jm3) (mmul Jm3 Jp3)) := by
  decide +kernel

/-! ### 3. Weight counts from the diagonal of Jz -/

def vals : List Int := [-2, -1, 0, 1, 2]

def triples : List (Int × Int × Int) :=
  vals.flatMap fun a => vals.flatMap fun b => vals.map fun c => (a, b, c)

def w (m : Int) : Nat :=
  triples.countP fun t => decide (t.1 + t.2.1 + t.2.2 = m)

def mult (j : Nat) : Nat := w j - w (j + 1)

def wdiag (m : Int) : Nat := (diagS Jz3).countP fun x => decide (x = m)

theorem jz_diagonal_weight_counts :
    (List.range 7).map (fun (j : Nat) => wdiag j) = [19, 18, 15, 10, 6, 3, 1] := by
  decide +kernel

theorem jz_diagonal_matches_weight_algebra :
    (List.range 7).map (fun (j : Nat) => wdiag j) = (List.range 7).map (fun (j : Nat) => w j) := by
  decide +kernel

/-- Jz is diagonal: every row has at most the entry on the diagonal. -/
theorem jz_is_diagonal :
    ((List.range 125).zip Jz3).all (fun p => p.2.all fun e => e.1 == p.1) = true := by
  decide +kernel

/-! ### 4. Minimal polynomial -/

def mpowPoly (roots : List Int) : SMat :=
  roots.foldl (fun R r => mmul R (msub C (mscale r I125))) I125

def nodes : List Int := [0, 2, 6, 12, 20, 30, 42]

theorem minimal_polynomial : mpowPoly nodes = zero125 := by decide +kernel

/-! ### 5. The exact projector A = pr(C) -/

def A : SMat := mpowPoly [0, 2, 12, 20, 31, 42]
def K : SMat := mpowPoly [6, 30]

theorem projector_idempotent : mmul A A = mscale 1814400 A := by decide +kernel
theorem projector_trace : mtrace A = 47 * 1814400 := by decide +kernel
theorem projector_kills_K : mmul K A = zero125 := by decide +kernel

def mpow : Nat → SMat
  | 0 => I125
  | k + 1 => mmul C (mpow k)

/-! ### 6. Power traces against the weight algebra -/

def spectrumPowerSum (k : Nat) : Int :=
  (((List.range 7).map fun j =>
    ((mult j * (2 * j + 1) : Nat) : Int) * ((j * (j + 1) : Nat) : Int) ^ k)).sum

theorem power_traces_match_weight_algebra :
    (List.range 7).map (fun k => mtrace (mpow k)) = (List.range 7).map spectrumPowerSum := by
  decide +kernel

theorem power_trace_values :
    (List.range 7).map (fun k => mtrace (mpow k)) =
      [125, 2250, 58500, 1827000, 63205200, 2327148000, 89208187200] := by
  decide +kernel

/-! ### 7. Numbers behind the spectral projectors (the idempotents themselves: Coq only) -/

def others (i : Nat) : List Int :=
  (((List.range 7).zip nodes).filter fun p => p.1 != i).map (·.2)

def node (i : Nat) : Int := nodes.getD i 0
def dcoef (i : Nat) : Int := (others i).foldl (fun a c => a * (node i - c)) 1
def blockdim (i : Nat) : Int := ((mult i * (2 * i + 1) : Nat) : Int)
def Dd : Int := 479001600   -- = 12! = lcm of the |d_i|

theorem dcoefs :
    (List.range 7).map dcoef =
      [3628800, -1612800, 1741824, -3110400, 8870400, -43545600, 479001600] := by
  decide +kernel

theorem Dd_divisible : (List.range 7).all (fun i => Dd % dcoef i == 0) = true := by
  decide +kernel

theorem Dd_is_lcm :
    Dd = (((List.range 7).map fun i => (dcoef i).natAbs).foldr Nat.lcm 1 : Nat) := by
  decide +kernel

theorem spectral_dimensions :
    (List.range 7).map blockdim = [1, 9, 25, 28, 27, 22, 13] := by decide +kernel

theorem total_dimension : ((List.range 7).map blockdim).sum = 125 := by decide +kernel

/-! ### 8. Bridge from the sparse representation to the dense textbook one -/

/-- The sparse Kronecker sums, expanded to dense lists of lists, are exactly the dense
    textbook Kronecker sums. -/
theorem bridge_kron_sums :
    toDense 125 Jz3 = JtotDense Jz5 ∧ toDense 125 Jp3 = JtotDense Jp5 ∧
    toDense 125 Jm3 = JtotDense Jm5 := by
  decide +kernel

/-- The sparse product agrees with the textbook dense product on the 5-dim factor
    and on the 25-dim two-particle space. -/
theorem bridge_product_5 : toDense 5 (mmul sJp5 sJm5) = mmulDense Jp5 Jm5 := by
  decide +kernel

def Jtwo (a : SMat) : SMat := madd (kron 5 a sI5) (kron 5 sI5 a)
def JtwoDense (a : Mat) : Mat := maddDense (kronDense a I5) (kronDense I5 a)

theorem bridge_product_25 :
    toDense 25 (mmul (Jtwo sJm5) (Jtwo sJp5)) = mmulDense (JtwoDense Jm5) (JtwoDense Jp5) := by
  decide +kernel

end MatrixProjector

#print axioms MatrixProjector.dims_125
#print axioms MatrixProjector.sl2_zp
#print axioms MatrixProjector.sl2_zm
#print axioms MatrixProjector.sl2_pm
#print axioms MatrixProjector.casimir_symmetric_form
#print axioms MatrixProjector.jz_diagonal_weight_counts
#print axioms MatrixProjector.jz_diagonal_matches_weight_algebra
#print axioms MatrixProjector.jz_is_diagonal
#print axioms MatrixProjector.minimal_polynomial
#print axioms MatrixProjector.projector_idempotent
#print axioms MatrixProjector.projector_trace
#print axioms MatrixProjector.projector_kills_K
#print axioms MatrixProjector.power_traces_match_weight_algebra
#print axioms MatrixProjector.power_trace_values
#print axioms MatrixProjector.dcoefs
#print axioms MatrixProjector.Dd_divisible
#print axioms MatrixProjector.Dd_is_lcm
#print axioms MatrixProjector.spectral_dimensions
#print axioms MatrixProjector.total_dimension
#print axioms MatrixProjector.bridge_kron_sums
#print axioms MatrixProjector.bridge_product_5
#print axioms MatrixProjector.bridge_product_25
