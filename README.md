# Identity
A first-principles research laboratory exploring identity, consciousness, and continuity through spectral algebra, quantum clocks, recursive dynamics, formal proofs, and executable simulations. Home to Mnemosyne, where mathematics, computation, philosophy, and the humanities converge.

## E47 functional quantum recovery and LLM weighting

[Explore the complete implementation, proofs, and validation](simulation/e47_qec/README.md).

Includes exact Lie-algebra and projector checks, a quantum recovery channel for specified code/syndrome errors, sequent derivations, and an executed classical causal-language-model adapter. Recorded validation: 37 numerical/rational checks and 14 exact SymPy checks passed. See the package report for the error model, execution results, and reproducibility commands.

Lean and Rocq sources for the E47 linear-algebra certificate are pinned in [formal/](formal/README.md). Those snapshots do not already contain the E47 proof. A separate, self-contained scalar certificate is in [formal/e47/](formal/e47/E47Spectral.lean), and the independent temporal-graph reconstruction that checks it in Python is in [simulation/e47_tqgnn/](simulation/e47_tqgnn/README.md). The one recorded synthetic run did not improve AUC.


## E47 spectral and noiseless-subsystem certificate (2026-10-24)

[Read the cross-repository evidence note](E47_SPECTRAL_ADVANTAGES_2026-10-24.md). Documents the exact 125→47 Casimir construction, the (15/17)^n spectral convergence certificate, and collective-SU(2) noiseless multiplicity encoding, separately from channel-dependent QEC and unmeasured hardware advantages.
