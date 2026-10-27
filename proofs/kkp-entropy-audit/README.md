# KKP–MED entropy / Ginzburg–Landau: reproducible proof audit

This folder provides a narrow, reproducible mathematical audit of the manuscript, **not** a proof of a universal coherence threshold or gravitoelectromagnetic superconductivity.

## Source and verification

| Claim | Result |
|---|---|
| Spectral ratio 47/125 = 0.376 | Exact identity |
| Binary entropy maximum | At p=1/2; does not independently select 0.376 |
| Homogeneous GL stationary minimum | Depends on alpha and beta |
| Universal 0.376 from GL | Not derivable from GL stability alone |
| Gravitomagnetic coupling, Tc, Bg, LK-99 | Not established by the supplied equations or data |

The files `KKPEntropy.lean` and `KKPEntropy.v` formalize exact integer equalities and distinct parameter examples. They do **not** formalize the full physical manuscript or a general GL minimization theorem. No `sorry` or `Admitted` is used.

## Reproduce

```sh
python3 proofs/kkp-entropy-audit/validate.py
lean proofs/kkp-entropy-audit/KKPEntropy.lean
coqc proofs/kkp-entropy-audit/KKPEntropy.v
```

GitHub Actions workflow: [kkp-entropy-audit.yml](../../.github/workflows/kkp-entropy-audit.yml). Review the **three separate jobs** in [Actions](https://github.com/nicholaskouns-create/Identity/actions/workflows/kkp-entropy-audit.yml) for actual compiler evidence. A committed workflow is not proof that its jobs passed.

## Status

Python script independently executed in the assistant's working environment on 2026-10-27 (PASS for exact ratio, parameter-dependent GL examples, binary entropy comparison). Lean and Coq CI run outcomes have **not been independently retrieved or verified** in this review. The manuscript's DOI `10.1000/jatp.2025.10.3.123` has not been authenticated; do not present it as a verified publication identifier.

The author’s E47 spectral dimension ratio is mathematically separate from the proposed physical interpretation.
