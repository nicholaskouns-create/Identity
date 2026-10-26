# E47 Mathlib Onsite Project

Lean project wired to mathlib for local use inside the Identity repository.

## Onsite setup

From this directory:

```bash
# Ensure elan is installed and PATH includes ~/.elan/bin
elan toolchain install leanprover/lean4:v4.35.0

# Pull prebuilt mathlib artifacts (multi-GB download, cached locally)
lake exe cache get

# Build
lake build
```

`lake exe cache get` downloads the compiled databases. They are not committed to git.

## Files

- `lean-toolchain` — pins Lean 4.35.0
- `lakefile.toml` — requires mathlib from leanprover-community
- `E47Mathlib.lean` — sample imports (Nat, Matrix.rank, group actions)

After the cache is present, any file under this project can `import Mathlib.*`.

## Notes

Full mathlib source and olean caches exceed GitHub size limits and are not vendored.
The dependency declaration is the permanent wiring; the databases live in the local lake cache after the first `lake exe cache get`.
