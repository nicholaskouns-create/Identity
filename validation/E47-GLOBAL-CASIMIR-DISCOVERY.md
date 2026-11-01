# E47 global Casimir: independent integer root discovery

**Scope:** additive, standard-library-only, exact computation. No production mutation, no imported Lean/Coq theorem, no credential, no signed certificate.

Run:

```sh
python3 -I validation/e47_global_casimir_root_discovery.py
```

The script independently builds the concrete 125-state spin-2 triple-tensor raising, lowering and diagonal generators, then forms `C=DU+Z(Z+I)` with genuine 125-term integer matrix products. It derives all 13 weight blocks from the diagonal of `Z`, checks both directions of cross-weight invariance, and obtains the exact characteristic polynomial of each block using Faddeev-LeVerrier arithmetic. For each polynomial it searches **integer roots without supplying the seven expected eigenvalues**, within an integer row-sum bound, and demands full degree factorization. It then constructs the global annihilating polynomial from discovered roots and checks its action on every block.

It separately computes exact rational ranks of `K=(C-6I)(C-30I)` on each block, sums them, and checks the resulting global rank and nullity. Expected spectrum/multiplicity values occur **only in a final comparison**, not in root discovery. The script rejects a modified Casimir.

**Observed local execution (2026-11-01):** roots `0,2,6,12,20,30,42`; multiplicities `1,9,25,28,27,22,13`; rank `78`, nullity `47`; all 13 blocks and mutant check passed. Local script SHA-256 `79cea9a21767c09f7c5d0c12331251bfad21fb305518ab0c061f5587c13005f7`; local output SHA-256 `5bf4e85b8c486288d8ada838098c9d0f0f1fbc985213da182efb3cf2d36a896e`. Hosted CI status must be read independently.

**Assurance boundary:** these are exact computations, not yet paired Lean 4/Coq theorems for the global concrete matrix. The local rank-nullity computation is independent of the earlier `Tensor125` weight-count arithmetic. The output does not authenticate compiler runs, sign receipts, deploy a Monorail ledger, clear Threat 20, or reconcile City citizens. Keep the independent existing spectral-block certificates and their failed runs intact.

**Next formal obligation:** transfer the 13 concrete invariant-block identities, exact block annihilators, and block-cover disjointness into Lean and Coq, then derive the full `M(C)=0`, eigenspace multiplicities and `dim ker K=47`. Continue to the projector and Richardson operator-norm result only after that bridge.
