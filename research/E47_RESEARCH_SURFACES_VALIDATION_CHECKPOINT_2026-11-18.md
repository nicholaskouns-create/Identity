# E47 research surfaces — curated checkpoint (2026-11-18)

This is a **navigation and evidence-status index**, not a replacement for any existing repository or certificate. Existing artifacts remain independent.

## Repositories

- [E47-Kartekeya](https://github.com/nicholaskouns-create/E47-Kartekeya) — E47 core, interfaces, experiments, certificates and computational work.
- [Identity](https://github.com/nicholaskouns-create/Identity) — research narratives, formal-proof interfaces, evidence notes and public presentation.
- [nicholaskouns-create.github.io](https://github.com/nicholaskouns-create/nicholaskouns-create.github.io) — GitHub Pages site material and published mathematical entries.
- [E47-Electroweak-Identities](https://github.com/nicholaskouns-create/E47-Electroweak-Identities) — electroweak research track.
- [E47-Foundry-Lifetime-Intersection](https://github.com/nicholaskouns-create/E47-Foundry-Lifetime-Intersection) — separate Foundry research track.

## Public pages and interfaces

- [Skyrmion RT3 interactive flight lab](https://nicholaskouns-create.github.io/E47-Kartekeya/interfaces/skyrmion-rt3/)
- [Electron Secret Garden / QGNN](https://nicholaskouns-create.github.io/electron-secret-garden/?share-check=1)
- [Lean and Coq browser runner](https://nicholaskouns-create.github.io/Identity/site/proof/lean-coq/browser.html)
- [Eidolon Flight Lab](https://eidolon-flight-lab.nicholaskouns.chatgpt.site/)

The links above are wayfinding references, not claims that every live deployment was re-executed in this checkpoint.

## Python validation checkpoint

The 2026-11-18 session generated two Python validation scripts and two JSON result files. These are **local conversation artifacts**, not included in this GitHub commit:

- `e47_validation.py`
- `e47_validation_results.json`
- `e47_gate_checks.py`
- `e47_gate_results.json`

**Computed/symbolic pass observations recorded in the JSON:**

- Carrier dimension 125; Casimir multiplicities `[1,9,25,28,27,22,13]`; projected rank 47.
- Orthogonal projector: `||P²-P||₂ = 4.738e-15`; `||KP||₂ = 8.809e-13`.
- 125-state Clebsch–Gordan basis: `||UᵀU-I||_F = 2.013e-15`.
- Encoded Hamiltonian intertwining: residual `4.108e-15`.
- Racah matrix generated from exact Wigner-6j symbols: symmetric, involutory, trace 1.
- Optimized 220-step theoretical contraction residual: `1.0998014528e-12` (formula evaluation, not a separately executed 220-step matrix iteration).

**Discrepancies preserved rather than repaired silently:**

- The separately hard-coded Racah matrix has involution error `0.8385465556`.
- Native exchange-CNOT gate fidelity to the specified target: `0.125`.
- Bridge-gate target fidelity: `0.390625`; bridge remains unitary.
- Current `L∝K` Lindblad configuration conserves E47 population; it does not pump population into E47.
- AWG schedule totals `1888 ns`, not the previously declared `1760 ns`.
- Deutsch compiler general arbitrary-unitary synthesis not demonstrated by the recorded fixed-input check.

## Status and provenance

This is a finite checkpoint of observed calculations, not a blanket claim that all project modules, live webpages, or cross-repository integrations have passed end-to-end testing. Formal proofs, numerical computations, simulations, assumptions, and pending tests retain distinct evidence levels. The existing repositories and site routes are left unchanged.
