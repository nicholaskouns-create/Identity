# Lean and Rocq sources for the E47 certificate

These are unmodified upstream snapshots. They do not contain a proof of the E47 statement, and they do not say anything about consciousness or personal identity. The checked statement remains a linear-map fact: `H = V₂⊗³` has dimension 125, `rank ker K = 47`, and `||Γⁿ − P||₂ = (15/17)ⁿ`.

The scalar integers in that statement are proved without these snapshots in [`formal/e47/`](e47/E47Spectral.lean) (Lean) and [`formal/e47/E47Spectral.v`](e47/E47Spectral.v) (Coq). Those files do not formalize the 125-by-125 matrices. Two further files, [`E47WeightAlgebra.lean`](e47/E47WeightAlgebra.lean) and [`E47WeightAlgebra.v`](e47/E47WeightAlgebra.v), derive those integers from the Jz weight counts of the 125 basis triples (a,b,c) in {-2..2}³: weights 19, 18, 15, 10, 6, 3, 1, multiplicities `w(j) - w(j+1)` = 1, 3, 5, 4, 3, 2, 1, kernel rank `(w 2 - w 3)*5 + (w 5 - w 6)*11 = 47`, and "(c-6)(c-30) = 0 iff j(j+1) ∈ {6, 30}" for every natural j. They also check the degree-six polynomial `pr(x) = x(x-2)(x-12)(x-20)(x-31)(x-42)` on the Casimir spectrum (value 1814400 = 10!/2 at 6 and 30, zero at the other nodes). Scope: weight counting and scalar identities only. The 125-by-125 matrices are not defined there, and the sl2 facts that spin-j summands number `w(j) - w(j+1)` and that C acts as j(j+1) on them are textbook input stated in the file headers, not axioms and not proved. Neither file imports Mathlib. Neither uses `sorry`/`Admitted`. `#print axioms` / `Print Assumptions` report none, except the Lean theorems `lam_zero_iff` (propext) and `pr_expanded` (Lean's standard propext, Classical.choice, Quot.sound).

The NumPy reconstruction that checks the matrices, and checks the same integers, is [`simulation/e47_tqgnn/`](../simulation/e47_tqgnn/README.md). The earlier orthonormal carrier check is still [`simulation/validate_e47.py`](../simulation/validate_e47.py).

**Matrix projector (real 125×125 matrices, exact integers).** [`e47/E47MatrixProjector.v`](e47/E47MatrixProjector.v) (Coq, primary) is a theorem about the explicit integer sl2 model of three spin-2 particles (per factor Jz = diag(2,1,0,−1,−2), Jm e_k = e_{k+1}, Jp e_k = k(5−k) e_{k−1}, Kronecker sums, C = Jz² + Jz + Jm·Jp), with plain dense matrices. It proves the sl2 relations, the minimal polynomial x(x−2)(x−6)(x−12)(x−20)(x−30)(x−42), the exact projector A = C(C−2)(C−12)(C−20)(C−31)(C−42) with A² = 1814400·A, trace A = 47·1814400 and (C−6)(C−30)·A = 0, the power traces against the weight algebra, and the spectral idempotents with traces giving the multiplicities 1, 9, 25, 28, 27, 22, 13. Rank equals trace for an idempotent, and the passage from these identities to eigenvalue multiplicities, are standard linear algebra and are taken as input; the rescaling from this integer model to the Hermitian one, and the singular values, are not formalized. [`e47/E47MatrixProjector.lean`](e47/E47MatrixProjector.lean) (Lean 4, core only) proves a subset with sparse integer matrices and `decide +kernel`: no `native_decide`, no `Lean.ofReduceBool`; `#print axioms` shows at most propext, Classical.choice, Quot.sound. It leaves out A = expanded polynomial and the spectral idempotent identities, because the Lean kernel runs out of memory on them (they are Coq-only), and it checks the sparse code against textbook dense matrices only for the Kronecker sums and for small products (5 and 25 dimensions), not for a dense 125×125 product. The Lean file takes about 4–5 minutes and 7 GB, so it runs in its own workflow, [`e47-matrix-projector.yml`](../.github/workflows/e47-matrix-projector.yml). The exact-integer NumPy check is [`simulation/e47_tqgnn/matrix_projector_check.py`](../simulation/e47_tqgnn/matrix_projector_check.py) (21 checks).

The slices do not build by themselves. Mathlib files import the rest of Mathlib, and the MathComp files import the rest of MathComp and Rocq. They are here as the reference database for a later formalization.

## What maps onto the certificate

| Certificate piece | Where it can be stated | What is actually in the snapshot |
| --- | --- | --- |
| Triple tensor product, dimension 125 | Mathlib `PiTensorProduct`, `TensorProduct`, `Matrix/Kronecker`; MathComp `algebra/tensor.v` | The tensor and Kronecker-product libraries. Not the spin-2 triple product. |
| Casimir eigenvalues and the spectral decomposition | MathComp `algebra/spectral.v` (Gram-Schmidt, Schur, `spectralmx`); Mathlib `LinearAlgebra/Eigenspace` | Eigenvalues, eigenspaces, and unitary diagonalization for normal matrices. Not `C = J²`. |
| `rank ker K = 47` | MathComp `algebra/mxalgebra.v` (`\rank`, `kermx`); Mathlib `LinearAlgebra/Matrix/Rank.lean` | Rank and kernel of a matrix. Not this particular `K`. |
| Unitary change of basis | Mathlib `LinearAlgebra/UnitaryGroup.lean`; MathComp `spectral.v` (`unitarymx`) | The unitary group and unitary matrices. |
| Finite-group multiplicity language | MathComp `group_representation/` (`character.v`, `mxrepresentation.v`) | Characters of finite groups. SU(2) is not a finite group, so this does not compute the multiplicities 1, 9, 25, 28, 27, 22, 13. |
| `||Γⁿ − P||₂` | MathComp Analysis `matrix_normedtype.v` | `mx_norm` is the max entrywise absolute value, not the operator 2-norm used by the certificate. |
| Proof search while writing a Lean proof | Aesop | A Lean 4 tactic. Not connected to a Lake build here. |

`theories/kernel.v` in the analysis snapshot is a measure-theoretic probability kernel. It is not `ker K`.

## Apps

- **Lean 4.35.0** for Linux is downloaded by `formal/fetch.sh` into `formal/toolchain/`. `lean --version` reports `4.35.0`. The archive is 567 MB, so it is not in git.
- **Rocq 9.3.0** source is `formal/apps/rocq-9.3.0.tar.gz` (LGPL-2.1). It has not been compiled. Building it needs an OCaml toolchain.
- **Aesop** is the vendored Lean proof-search app.

## Not redistributed

`rmathar/Clebsch-Gordan` (`a989781`) is a PARI/GP table of Clebsch-Gordan coefficients, which is the arithmetic behind the SU(2) multiplicities. The repository states no license, so the clone stays in `formal/upstream/clebsch-gordan/` on a machine that has run `fetch.sh` and is gitignored.

## Refresh

`sh formal/fetch.sh` downloads anything that is missing and leaves an existing snapshot alone. Pins and checksums are in `SOURCES.lock`.
