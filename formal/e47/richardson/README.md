# Richardson contraction

Numerical witness for `E47Richardson.lean`, `E47Richardson.v`, and `E47Spectral.lean`.

The filter is diagonal in the Casimir eigenbasis of `V_2^{⊗3}`. `K = (C-6I)(C-30I)` is zero on total spin 2 and 5 (47 dimensions). The optimal step `ε* = 1/99144` multiplies every other mode by a factor at most `15/17`.

- `richardson_sim.py` is the run.
- `richardson.ts` is the same recurrence, checked against the Python output.
- `RESULTS.txt` is the run from 29 October 2026.

The initial vector is declared: coordinate `i` is `(17*i + 3) mod 97`, then centered and normalized. Q4.28 rounds each coordinate to a multiple of `2^{-28}` after every step. This is not the unpublished vector behind the plate's printed residual column. The rate law does not depend on that choice.

```
python3 richardson_sim.py
```
