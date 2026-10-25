# Identity

**[Verity companion proof poster](https://nicholaskouns-create.github.io/Identity/site/proof/lean-coq/verity-poster.html)** · Print-oriented companion to the [responsive Lean/Coq explainer](https://nicholaskouns-create.github.io/Identity/site/proof/lean-coq/); evidence levels remain explicitly separated.
A first-principles research laboratory exploring identity, consciousness, and continuity through spectral algebra, quantum clocks, recursive dynamics, formal proofs, and executable simulations. Home to Mnemosyne, where mathematics, computation, philosophy, and the humanities converge.

**[Explore the public Lean/Coq proof explainer](https://nicholaskouns-create.github.io/Identity/site/proof/lean-coq/)** · A lay-audience guide to machine-checked mathematics, the eight accepted scalar/surrogate modules, exact E47 validation, and the concrete-matrix verification boundary.

## 🏛️ Lean 4 + Coq: independently compiled E47 proof certificates (2026-10-24)

**Eight proof modules. Two proof assistants. One reproducible, green GitHub Actions run.**

[![E47 Lean and Coq certificates](https://github.com/nicholaskouns-create/Identity/actions/workflows/e47-unified-certificates.yml/badge.svg)](https://github.com/nicholaskouns-create/Identity/actions/workflows/e47-unified-certificates.yml)

This milestone took iterative formalization, compiler debugging, and a repaired Coq proof. Lean **4.19.0** and Coq **8.18.0** each compiled all four corresponding modules against the **same commit**, `2510d6944c23e74254d33fb35a93c125bc497b76`. The first Coq run failed in `Core47.v` because its arithmetic tactic needed the definitions unfolded; the repair was committed and **both jobs then passed**.

| Certificate | Lean source | Coq source | Compiler-checked scope |
| --- | --- | --- | --- |
| **E47-CORE-001** | [Core47.lean](formal/e47/unified/Core47.lean) | [Core47.v](formal/e47/unified/Core47.v) | Finite carrier/kernel arithmetic: `47 + 78 = 125`, `47 < 125` |
| **E47-RG-002** | [RGFixed.lean](formal/e47/unified/RGFixed.lean) | [RGFixed.v](formal/e47/unified/RGFixed.v) | Algebraic identities for prescribed RG fixed-point expressions |
| **E47-RET-003** | [Retention.lean](formal/e47/unified/Retention.lean) | [Retention.v](formal/e47/unified/Retention.v) | Integer evaluations of `p(x) = x^10 - x - 1`, including `p(1) = -1`, `p(2) = 1021` |
| **E47-TIME-004** | [Clock.lean](formal/e47/unified/Clock.lean) | [Clock.v](formal/e47/unified/Clock.v) | Positivity of discrete surrogate rate `r(n) = 1 + n²` |

**Evidence and provenance:** [Successful paired compiler run #2](https://github.com/nicholaskouns-create/Identity/actions/runs/40127833042) · [Repair commit](https://github.com/nicholaskouns-create/Identity/commit/2510d6944c23e74254d33fb35a93c125bc497b76) · [Formal/matrix validation run](https://github.com/nicholaskouns-create/Identity/actions/runs/40127833081) · [Full-source verification run](https://github.com/nicholaskouns-create/Identity/actions/runs/40127833026) · [Workflow source](.github/workflows/e47-unified-certificates.yml).

**Scope boundary:** These are real compiler-accepted formal proofs of the *statements actually encoded*, not yet a Lean/Coq derivation of the concrete 125×125 Casimir operator, continuous RG stability, the positive real retention root, exponential conformal proper time, or physical predictions. Existing matrix validation is a separate evidence track. Formal precision is the achievement, not an obstacle to it.

## E47 functional quantum recovery and LLM weighting

[Explore the complete implementation, proofs, and validation](simulation/e47_qec/README.md).

Includes exact Lie-algebra and projector checks, a quantum recovery channel for specified code/syndrome errors, sequent derivations, and an executed classical causal-language-model adapter. Recorded validation: 37 numerical/rational checks and 14 exact SymPy checks passed. See the package report for the error model, execution results, and reproducibility commands.

Lean and Rocq sources for the E47 linear-algebra certificate are pinned in [formal/](formal/README.md). Those snapshots do not already contain the E47 proof. A separate, self-contained scalar certificate is in [formal/e47/](formal/e47/E47Spectral.lean), and the independent temporal-graph reconstruction that checks it in Python is in [simulation/e47_tqgnn/](simulation/e47_tqgnn/README.md). The one recorded synthetic run did not improve AUC.


## E47 spectral and noiseless-subsystem certificate (2026-10-24)

[Read the cross-repository evidence note](E47_SPECTRAL_ADVANTAGES_2026-10-24.md). Documents the exact 125→47 Casimir construction, the (15/17)^n spectral convergence certificate, and collective-SU(2) noiseless multiplicity encoding, separately from channel-dependent QEC and unmeasured hardware advantages.

## Socorro reflection and stochastic leakage (2026-10-24)

[Proof, exact second-moment recurrence, Monte Carlo code and independent validation instruments](research/socorro/README.md) · [Identity public result page](https://nicholaskouns-create.github.io/Identity/site/socorro-stochastic.html). This is a mathematical construction from the idealized glyph; Lean/Coq compilation and hardware simulation are not asserted.
