# E47 temporal graph net

Independent reconstruction of a temporal graph network with the E47 spectral clock. The earlier Mnemosyne implementation zip is not in this repository, so this code is not a copy of it.

The statement being checked is a linear-map fact about three spin-2 factors. It is not a claim about consciousness or personal identity.

## What is proved

`formal/e47/E47Spectral.lean` and `formal/e47/E47Spectral.v` prove the same integers that `spectral.py` checks:

- Coupling three spin-2 angular momenta gives multiplicities `[1, 3, 5, 4, 3, 2, 1]`.
- The carrier dimension is `1+9+25+28+27+22+13 = 125`.
- Casimir nodes are `j(j+1)` for `j = 0..6`: `[0, 2, 6, 12, 20, 30, 42]`.
- `K = (C − 6I)(C − 30I)` vanishes on the `j = 2` and `j = 5` sectors. Their dimensions are `5·5 + 2·11 = 47`.
- The denominator `99144` is fixed by the highest weight so that Casimir `42` has contraction factor `−15/17`. Casimir `12` meets `+15/17`. Casimirs `0`, `2`, and `20` are strictly inside that bound.

Lean uses `decide` and does not import Mathlib. Coq uses `vm_compute` and does not import MathComp. Neither file formalizes the 125-by-125 matrices. The vendored Mathlib and MathComp snapshots do not contain this theorem.

## What Python checks on the matrices

`numerical_carrier` builds orthonormal spin-2 generators, takes the Kronecker sum on `5³ = 125` dimensions, and checks:

- the `su(2)` relation and the eigenspace counts above;
- `P² = P`, `KP = 0`, and `ΓP = P`, with `Γ = I − K²/99144`;
- `||Γⁿ − P||₂ = (15/17)ⁿ` for `n = 1, 2, 10`;
- a real period-47 permutation clock: orthogonal, and order 47.

`rational_spin2_algebra` checks the integer spin-2 relations `[J₊, J₋] = 2J_z` and `J_z² + (J₊J₋ + J₋J₊)/2 = 6I` in exact arithmetic.

The network state is 47-dimensional, the dimension of `ker K`. With the clock on, each step rolls that state by the period-47 permutation before a GRU update. The code subspace `Q` (shape 125×47) is built in the spectral check. The training loop does not multiply the 125-by-125 operators.

## One synthetic run

16 nodes, 8 time steps, 3 random outgoing edges per node, width 47, 8 Adam epochs, seed 47. Loss is on the last observed step. AUC is on a later holdout step that was not used as a message. Negatives are random non-edges, scored with a Mann–Whitney rank AUC.

| run | ROC AUC |
| --- | ---: |
| baseline, no clock | 0.5520833333333334 |
| period-47 clock | 0.5338541666666666 |
| delta | −0.01822916666666674 |

This is one run. It does not show that the clock improves link prediction. It is not a reproduction of the earlier TGBL-wiki or Cora reports.

## Run

```sh
python simulation/e47_tqgnn/run.py
```

Needs NumPy. If `lean` or `coqc` is missing, that proof is marked `skipped` and the Python checks still have to pass. A local Coq prefix can be selected with `COQ_PREFIX` and `MICROMAMBA`. `results.json` records the run in which both proof assistants passed.
