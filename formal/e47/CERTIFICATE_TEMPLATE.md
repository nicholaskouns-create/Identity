# E47 formal certificate template

Reusable template inspired by [PR #69](https://github.com/nicholaskouns-create/Identity/pull/69). This is a **documentation template**, not a compiled proof or a CI-success claim.

## Certificate identity

- ID: `E47-<family>-<range>`
- Statement: `<precise theorem and hypotheses>`
- Concrete source: `formal/e47/<source>`
- Parent evidence: `<commit SHA and workflow run URL>`
- Head commit: `<SHA>`
- Dependency graph: `<previous bounded certificates>`
- Evidence level: `candidate | Python-checked | Lean-accepted | Coq-accepted | independently reproduced`

## Lean 4 certificate

- File: `formal/e47/<name>.lean`
- Toolchain: `<pinned version, e.g. 4.19.0 or 4.35.0>`
- Proof tactic: `<by decide / native_decide / exact / ...>`
- Require: `#print axioms <theorem>` in compiler logs
- Record: full concrete operator definitions, theorem statement, exit code, elapsed time, peak memory, and any axioms
- A `sorry`, `admit`, added axiom, or unproven dependency cannot count as a closed proof

## Coq/Rocq certificate

- File: `formal/e47/<name>.v`
- Toolchain: `<pinned Coq version>`
- Require: `coqc <file>` and `Print Assumptions <theorem>.`
- Record: statement, compiler exit code, elapsed time, memory, assumptions
- Never treat `Admitted` or a postulated conclusion as acceptance of the target claim

## Numerical or exact-arithmetic witness

- Validator: `<path>`
- Inputs: `<dataset or matrix construction, exact seed if random>`
- Assertions: `<expected rank, dimensions, matrix identities, bounds>`
- Outputs: `<machine-readable JSON and human-readable logs>`
- Distinguish exact integer/rational arithmetic from floating-point tolerances

## CI contract

1. Checkout the exact head SHA.
2. Install **pinned** Lean and Coq versions (separate jobs are fine).
3. Compile only explicitly named certificate files and their dependencies.
4. Run exact or numerical validator independently.
5. Upload logs and results **even on failure**.
6. Record commit SHA, toolchain versions, job URLs, and SHA-256 hashes of artifacts.
7. Fail the workflow on any compilation/test error, timeout, or unexpected axiom.
8. Promote to the canonical registry only after successful jobs and explicit review.

## Example bounded E47 bracket batch

- Family: `Tensor125-third-bracket`
- Batch: columns `60..64`
- Lean: `formal/e47/unified/Tensor125Columns60to64.lean`
- Coq: `formal/e47/unified/Tensor125.v`
- Statement: concrete columns of `[totalUp,totalDown]=2 totalZ` with full 125-term products
- Reference: PR #69 head `58ff2edf49cbd053cf56b89577d430b55b478df4`
- Status: **compiler results for that head not independently confirmed here**
- Next batches: `65..69`, etc., subject to resource limits and exact dependency checks

## Scope boundary

The completed third-bracket columns alone do not establish full Casimir centrality, spectral multiplicities, rank-47 projector, Lorentzian geometry, or quantum clock calibration. Each is a separate proof obligation with its own certificate.
