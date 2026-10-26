# E47 Rank-Nullity Accordance Record
**E47-CORE-002 · 2026-10-25**

## Derived values (not inputs)

| Method | Carrier | Rank | Ker | Identity source |
|--------|---------|------|-----|-----------------|
| Lean 4.35.0 (`RankNullity47.lean`) | 125 | 78 | 47 | general `rank_nullity` by induction, then read-out |
| Coq 8.18 (`RankNullity47.v`) | 125 | 78 | 47 | general `rank_nullity` by induction, then `vm_compute` |
| Exact rational elimination (dense conjugate) | 125 | 78 | 47 | Gaussian elimination on unimodular similar matrix |
| Spectrum count | 125 | — | 47 | sum of multiplicities of annihilated spins j=2,5 |

## Accordance

All four methods agree on:
- carrier dimension = 125
- rank K = 78
- dim ker K = 47
- annihilated spins = {2, 5} (Casimir eigenvalues 6 and 30)

The Lean and Coq proofs establish the general rank-nullity identity for arbitrary graded carriers and arbitrary annihilating predicates (no numerals in the statement). The E47 values are specialized read-outs. The matrix elimination recovers the same rank independently of the block decomposition, after dense conjugation so the algorithm cannot short-circuit on a diagonal.

## Sources
- `formal/e47/unified/RankNullity47.lean`
- `formal/e47/unified/RankNullity47.v`
- `validation/e47_rank_nullity_exact.py`
- Independent execution of the Python certificate (exit 0)

47 and 78 are outputs of the coupling 2⊗2⊗2 and p(x)=(x-6)(x-30).
