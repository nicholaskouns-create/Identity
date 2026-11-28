# Evidence ledger
2026-11-27: local NumPy execution of concrete spin matrices and permutation averaging passed both ranks (47,5), gap 11664, maximum 186624, contraction 15/17 and projector preservation. Random-state absolute residual at 220: 9.204583380675367e-12 and 1.1654011451805419e-11 (unnormalized inputs). 256-dimensional dilation Frobenius unitarity residuals 3.5474383861085e-14 and 3.5036010436122616e-14. This is matrix simulation, not hardware.
[Reproduction](https://github.com/nicholaskouns-create/E47-Kartekeya/blob/main/research/e47/recursive_identity/validate.py).

## Compiler receipts (2026-11-28)

Lean 4.35.0 (commit eb6cafb7290e8bd5f2937522d8d804f58f02bafc):
- `formal/UniversalInvariant.lean` — compiled, no sorry, no axiom warnings
- `formal/NestedInvariant47to5.lean` — compiled, no sorry, no axiom warnings
- `../formal/LERI_Exact.lean` — compiled, no sorry, no axiom warnings

The three files contain only algebraic factorization lemmas and arithmetic identities on the listed sector data (dimension split 47 + 78 = 125, canonical dim 5, spectral midpoint, exact 15/17 endpoint factors, Ω_c = 47/125). They do not construct the 125×125 operators; that construction is checked by the NumPy validators.

Coq counterparts (`UniversalInvariant.v`, `NestedInvariant47to5.v`, `LERI_Exact.v`) are equivalent arithmetic/factorization statements using `reflexivity` and `lia`. They are ready for Coq 8.18.0 stdlib; local coqc was not available in the execution environment used for this receipt.

Full topological factorization theorem remains analytic (continuous maps into Hausdorff spaces). Compiler execution of the algebraic cores is now recorded.
