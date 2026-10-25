# e47_core: one exact-arithmetic source for the E47 constants

Pure Python 3 standard library (`fractions`, `itertools`, `hashlib`, `json`). No numpy, no installs.

| File | Purpose |
| --- | --- |
| `e47_core.py` | Defines the constants from the same definitions and **names** as `formal/e47/E47WeightAlgebra.{lean,v}` (`triples`, `w`, `mult`, `casimir`, `lam`, `gap`, `pr`), then `verify()` returns a dict of named booleans. |
| `make_certificate.py` | Writes `e47_core_certificate.json` (deterministic, no timestamp). `--check` fails if the file on disk is stale. |
| `e47_core_certificate.json` | Schema, every constant, every check result, and the constants SHA-256. |
| `test_e47_core.py` | `python -m unittest -v test_e47_core` |
| `e47_core_check.py` | Self-contained, read-only drift check. The same file is copied into the other repos. |

```
python e47_core.py                       # prints PASS/FAIL per check
python make_certificate.py               # regenerate the certificate
python -m unittest -v test_e47_core      # tests
python e47_core_check.py [repo_root]     # drift scan; exit 0 = no drift, 1 = drift
```

## What is computed (nothing is typed in, then compared to known facts)

* `triples`: the 125 triples (a, b, c) with a, b, c in -2..2. `w(m)` = number with a+b+c = m, giving 19, 18, 15, 10, 6, 3, 1 for m = 0..6.
* `mult(j) = w(j) - w(j+1)` = 1, 3, 5, 4, 3, 2, 1. `casimir(j) = j(j+1)` = 0, 2, 6, 12, 20, 30, 42.
* Casimir eigenspace dimensions `mult(j)(2j+1)` = 1, 9, 25, 28, 27, 22, 13 (sum 125).
* `lam(c) = (c-6)(c-30)`. Kernel spins = those j with `lam(casimir(j)) = 0` = {2, 5}. `kernel_rank` = 25 + 22 = 47. `Omega_c = 47/125 = 0.376`.
* K^2 eigenvalues off the kernel are derived as `lam(c)^2` over the off-kernel nodes: {11664, 12544, 19600, 32400, 186624} (c = 12, 2, 20, 0, 42). This equals the set quoted in the repo docs; no discrepancy.
* `DENOMINATOR = (min + max) / 2 = 99144`, `epsilon = 1/99144 = 2/(11664 + 186624)`, `rho = (max - min)/(max + min) = 15/17`. `gap(c) = |99144 - lam(c)^2|`.
* `pr(x) = x(x-2)(x-12)(x-20)(x-31)(x-42)`; `pr(6) = pr(30) = 1814400 = 10!/2`, coefficients [1, -107, 4088, -66940, 430848, -624960, 0]; `P = pr(C)/1814400` has trace 47.
* Tower link: F_5 = 5, L_5 = 11, F_3 = 2, j = (F_5-1)/2 = 2, J = (L_5-1)/2 = 5, D = F_5^2 + F_3 L_5 = 47 = kernel_rank, and j, J are exactly the kernel spins.

Scope: like the Lean/Coq files, this treats "C acts as j(j+1) on a spin-j summand" and "#spin-j summands = w(j) - w(j+1)" as standard sl2 input. It does not build the 125x125 matrices.

## Constants hash

`constants_sha256` is the SHA-256 of the UTF-8 bytes of

```python
json.dumps(constants, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
```

where `constants` is the `"constants"` object of the certificate (fractions are strings `"p/q"`). Recompute with any JSON library:

```python
import json, hashlib
c = json.load(open("e47_core_certificate.json"))["constants"]
print(hashlib.sha256(json.dumps(c, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()).hexdigest())
```

Current value: `a393ec7c3d53933795d5f4a41b93ca35f43beec8d88de8429f21c27017bbf624`.

`e47_core_check.py` embeds the exact canonical string, recomputes its hash and compares it with the pinned literal, so a repo copy cannot silently change. Changing a constant means regenerating the certificate, re-pinning the hash in every copy, and updating the Lean/Coq files.

## Where each constant is proved

Lean names are in namespace `WeightAlgebra` unless marked `Spectral`; Coq lemmas have the same names in `E47WeightAlgebra.v` / `E47Spectral.v`.

| Constant | Lean / Coq theorem | File |
| --- | --- | --- |
| 125 basis triples | `basis_size` | E47WeightAlgebra |
| Weight counts 19, 18, 15, 10, 6, 3, 1 | `weight_counts`, `weight_symmetric`, `weight_total`, `weight_window` | E47WeightAlgebra |
| Multiplicities 1, 3, 5, 4, 3, 2, 1 | `multiplicities`, `multiplicities_reproduce_weights`; also `spin2_triple_multiplicities` | E47WeightAlgebra; E47Spectral |
| Eigenspace dims sum to 125 (1, 9, 25, 28, 27, 22, 13) | `dimension_identity`; also `carrier_dimension` | E47WeightAlgebra; E47Spectral |
| Casimir spectrum 0, 2, 6, 12, 20, 30, 42 | `casimir_values`, `nodes_are_casimir_values`; also `casimir_nodes` | E47WeightAlgebra; E47Spectral |
| Kernel spins {2, 5} (all natural j) | `lam_zero_iff`, `lam_zero_on_range`, `kernel_blocks_are_spin2_spin5` | E47WeightAlgebra |
| kernel_rank = 47 | `kernel_rank_from_weights`, `kernel_dim_from_blocks`; also `kernel_rank` | E47WeightAlgebra; E47Spectral |
| Omega_c = 47/125 | 47 from the rows above, 125 from `basis_size` (the quotient is arithmetic, not a separate theorem) | |
| lam(6) = lam(30) = 0, gap = 99144 on the kernel | `gamma_is_one_on_kernel`; also `kernel_polynomial_vanishes`, `kernel_gamma_is_one` | E47WeightAlgebra; E47Spectral |
| 99144 (denominator) | `denominator_from_top_spin` (36*12)^2*17 = 99144*32; also `denominator_from_highest_weight`, `top_weight_gives_spin6` | E47WeightAlgebra; E47Spectral |
| rho = 15/17 (contraction, equality at Casimir 12 and 42) | `gamma_contracts_off_kernel`, `gamma_contraction_extremes`; also `complement_contracts` | E47WeightAlgebra; E47Spectral |
| K^2 eigenvalues {11664, 12544, 19600, 32400, 186624} | not stated as a theorem; each follows from `lam` on the Casimir nodes (`casimir_values`) and is checked here by exact arithmetic | |
| pr(6) = pr(30) = 1814400, zero at the other nodes | `pr_on_nodes`, `pr_normalizer` | E47WeightAlgebra |
| pr coefficients | `pr_expanded`, `pr_degree_six_monic` | E47WeightAlgebra |
| Tower: J(J+1) = 5 j(j+1) for odd n | `tower_spin_identity`, `lucas_fibonacci_odd`, `invariants` | TowerIdentity.v |
| Tower: D = F_5^2 + F_3 L_5 = 47 equals kernel_rank, j = 2 and J = 5 are the kernel spins | **not yet formalized**; checked here by `tower_kernel_link` (instance n = 5 only) | |
| P = pr(C)/1814400 is a rank-47 projector on the 125x125 matrix | **not formalized**; only the scalar identities above; `projector_trace_47` checks the block-dimension sum | |
