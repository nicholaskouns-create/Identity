# Sigillum ten-register certificate

Filled from [`CERTIFICATE_TEMPLATE.md`](../CERTIFICATE_TEMPLATE.md). This is a
documentation certificate: it records what was compiled, where, and with what
result. It is not itself a proof.

## Certificate identity

- ID: `SIGILLUM-wheel-Z40`
- Statement: for every odd `s`, the map `F_s(j) = 3j + s mod 40` is a permutation
  of `Z_40` all of whose orbits have length exactly four; hence `Z_40` partitions
  into exactly ten four-station registers, each closed under `F_s`. Compression
  ratio `Omega_wheel = 10/40 = 1/4`. Refinement: the ten decomposes as `2 + 8`
  under `Z_40 = Z_8 x Z_5`, not as the quotient `40/4`.
- Concrete source: `formal/e47/SigillumWheel.lean`, `formal/e47/SigillumWheel.v`
- Parent evidence: base commit `fb6cfdc3ad00bd7477402133499616caf2ab2c5b` (origin/main)
- Head commit: recorded by CI on the merge commit
- Dependency graph: none. This certificate stands alone; it does not depend on
  the E47 kernel certificates and asserts no bridge to `Omega_c = 47/125`.
- Evidence level: **Lean-accepted** (kernel-checked, axiom-free) and
  **Python-checked**. Coq is **candidate** until the first CI run compiles it;
  see the honest gap below.

## Lean 4 certificate

- File: `formal/e47/SigillumWheel.lean` (sha256 `ab6eff2c0aa3ea91fdcfc2cabf9ac736201bfd555baabe6a6c8a9646874177fe`)
- Toolchain: 4.35.0 (`formal/e47/lean-toolchain`)
- Proof tactic: `by decide` throughout. No `native_decide`, no `sorry`.
- `#print axioms`: fifteen statements in the file; all fifteen report
  *does not depend on any axioms*.
- Gate result, run locally with the repository's own script:

      python3 scripts/axiom_ledger.py formal/e47/SigillumWheel.lean
      15 clean   0 standard-axioms   0 native_decide   0 broken   (15 audited)
      PASS

- Elapsed: 45 s standalone compile; 23 s through the ledger script.
- No Mathlib import, so the file is covered by the fast `core-ledger` job of
  `e47-axiom-ledger.yml`, where no `native_decide` allowance is granted.

## Coq/Rocq certificate

- File: `formal/e47/SigillumWheel.v` (sha256 `75bfff1d29d29018e626222f4a8ef020040a4b39574a287c642f7de014423a32`)
- Toolchain: whatever `apt-get install -y coq` provides on `ubuntu-24.04`,
  matching `coq-tower.yml` and `e47-formal-validation.yml`.
- Proof tactic: `vm_compute; reflexivity` throughout, which is kernel-checked
  conversion rather than a trusted oracle. No `Admitted`, no `Axiom`.
- `Print Assumptions`: nine statements in the file; CI greps the output for
  *Closed under the global context* and fails the run otherwise.
- **Honest gap.** This file was written but **not compiled** in the environment
  that produced it: `apt` had no `coq` package, `channels.nixos.org` and
  `cache.nixos.org` both returned 403 through the egress proxy, and installing a
  WebAssembly Coq from npm was refused by policy. Every claim it makes was
  instead confirmed independently by the Python validator below, so the
  mathematics is checked even where the Coq syntax is not. The corrected path,
  rather than the excuse: the file is wired into
  `e47-formal-validation.yml`, whose runner installs Coq from apt, so the first
  CI run on this branch compiles it and the gap closes without further work.
  Until that run is green, treat the Coq column as *candidate*.
- `nat` is unary in this file rather than `Z` as in `E47Spectral.v`. That is
  deliberate: every intermediate is at most `3*39 + 39 = 156`, so unary
  evaluation is instant, and `seq`, `forallb` and `filter` over `nat` keep the
  orbit bookkeeping readable. The `Z_scope` discipline used elsewhere in this
  directory is required there because those files carry six- and seven-digit
  constants; it is not required here.

## Numerical or exact-arithmetic witness

- Validator: `simulation/validate_sigillum_wheel.py` (sha256 `ee1d5aea5370db0249acc3cce6669df7a79083acf022a8af5db578ab54fca860`)
- Inputs: none. Nothing random, nothing read from disk. Every claim is
  re-derived from the definition of the step map, not re-checked against a
  precomputed table.
- Assertions: 21, mirroring the two proof files theorem-for-theorem, plus three
  that the proof files do not state — that the listed registers *coincide with*
  the computed orbits rather than merely being consistent with them, the factor
  orbit-length profile (`Z_8 -> [4,4]`, `Z_5 -> [1,4]`), and the pairing formula
  `sum of gcd(|O_8|,|O_5|) = 10`.
- Outputs: one line per claim on stdout; exit 0 iff all hold. Result: 21/21.
- Arithmetic is exact integer throughout. No floating point, so no tolerances.

## CI contract

Satisfied by two existing workflows; no new workflow was added.

1. `e47-axiom-ledger.yml` — its `core-ledger` job globs `formal/e47/*.lean`,
   excluding only the two Mathlib files, so the Lean file is compiled and
   axiom-audited automatically with no allowance for `native_decide`.
2. `e47-formal-validation.yml` — extended with three additive steps: the Lean
   kernel compile, the Coq kernel compile with the `Print Assumptions` grep, and
   the independent validator. Its runner already installs pinned Lean 4.35.0,
   Coq and Python, and it already triggers on `formal/e47/**`.

Nothing existing was disabled, reordered or removed.

## Scope

The theorem is about a forty-element cyclic state space and an affine map on it.
It says nothing about the forty-seven Enochian projectors on the plates: those
are basis-dependent and carry no invariant content, and only the `25 + 22`
isotypic split is canonical. The spectral corollary — `rank Pi = 10` for the
orbit-averaging projector, `||T^80 - Pi||_2 = 0` — follows from this theorem by
`Z_4` representation theory on paper and is confirmed numerically to machine
zero, but is not formalised: it needs Mathlib's linear algebra rather than the
kernel. `Omega_wheel = 1/4` is a property of this wheel and is not
`Omega_c = 47/125`.
