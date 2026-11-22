# E47 kernel certificate — the 125-dimensional theorem as dimensions

Coq 8.18, standard library only. Every one of the 16 `Print Assumptions` at the end of
[`E47KernelCertificate.v`](E47KernelCertificate.v) reports *Closed under the global context*:
no `Axiom`, no `Admitted`; every computation runs under `vm_compute` and is checked by the kernel.

It imports, unchanged (SHA-256 identical to the copies in `formal/e47/`), the three modules it
builds on — [`E47MatrixProjector.v`](../E47MatrixProjector.v), [`E47OddsContraction.v`](../E47OddsContraction.v),
[`E47OddsLink.v`](../E47OddsLink.v) — and the generated witness file
[`E47KernelCertificateData.v`](E47KernelCertificateData.v).

## What is proved

The carrier is the integer sl2 model of `E47MatrixProjector.v`: three spin-2 factors on `Z^125`,
`C = Jz² + Jz + Jm·Jp`, nodes `0, 2, 6, 12, 20, 30, 42`, `K = (C−6)(C−30)`, the weight
`W = W1⊗W1⊗W1`, `W1 = diag(1, 4, 24, 144, 576)`, `Dd = 12!`.

| Theorem | Statement |
| --- | --- |
| `eigenspace_contains_basis` · `eigenspace_basis_injective` · `eigenspace_spanned` | each eigenspace of `C` has an explicit basis in reduced form: it lies in the eigenspace, it is injective, and it spans every eigenvector |
| `eigenspace_dimensions` | the seven dimensions are `1, 9, 25, 28, 27, 22, 13` |
| `kernel_dimension_47` | `ker K` is exactly the image of the explicit injective `BK : Z^47 → Z^125` |
| `omega_c` | `47/125 = 0.376` |
| `spectral_decomposition` · `resolution_on_vectors` | `Dd·x = Σᵢ Eᵢx` with `C(Eᵢx) = nodeᵢ·Eᵢx`, for every vector |
| `eigenvalues_complete` | if `q·Cx = p·x`, `x ≠ 0`, then `p/q` is one of the seven nodes |
| `mass_additivity` | `Dd²⟨x,x⟩_W = Σᵢ massᵢ(x)` |
| `contraction_identity` · `contraction_bound` · `contraction_sharp` · `operator_norm_rate` | with `Γ = I − K²/D`, `D = 99144`: `‖(Γⁿ − P)x‖_W ≤ (15/17)ⁿ‖x‖_W` for **every** `n` and `x`, with equality at an explicit `x*`; `17·87480 = 15·99144` |
| `K_on_eigen` · `K2_on_eigen` · `K2_spectrum` | `K²` acts on the seven eigenspaces by `32400, 12544, 0, 11664, 19600, 0, 186624` |
| `optimal_step` | the MC88 optimal-step inequalities, from that derived spectrum |
| `EK_projects_onto_kernel` | `EK` maps into `ker K` and is `Dd·id` on it |

## Gaps this closes

The repository's [`formal/README.md`](../../README.md) records four facts as *taken as input*. Each is now a theorem here.

- **G1** rank = trace for idempotents, and multiplicities as eigenspace dimensions (`E47MatrixProjector.v`, `E47OddsLink.v`) → explicit bases; no rank or trace argument is used.
- **G2** the five `K²` eigenvalues supplied as spectral input (`optimal/MC88OptimalStep.v`) → `K2_spectrum`.
- **G3** mass additivity, checked only in Python (`E47OddsLink.v`) → `mass_additivity`.
- **G4** the rate `(15/17)ⁿ` → `operator_norm_rate`, for all `n`, sharp.

**Method.** Every eigenspace, and `ker K`, is given an explicit basis `B` with `B[piv,:] = β·I` on a pivot
set. Injectivity is then the pivot identity; spanning is the single matrix identity `β·E = B·E[piv,:]`
together with the generic lemma `E_on_eigen` (an eigenvector of level *i* is sent by `Eⱼ` to
`δᵢⱼ·Dd·x`), proved once for all vectors.

**Scope.** Statements are over integer vectors, i.e. over `Q^125` after clearing denominators, in the
`W`-inner product. Their transfer to real vectors, and to the Hermitian 2-norm through the isometry
`W^½` (entries involve √6), is standard linear algebra and is not formalized here.

## Verify

```sh
make check      # ~2.5 min, ~0.9 GB: compiles the three upstream modules unchanged, then this one
make regen      # rebuilds the witnesses from scratch; requires byte-identical output
```

Expected tail of `make check`: sixteen lines `Closed under the global context`, then
`OK: all 16 Print Assumptions report 'Closed under the global context'`.

| File | Role | SHA-256 (first 16) |
| --- | --- | --- |
| `gen/gen_certificate.py` | exact per-level reduced bases (Python `fractions`) | — |
| `gen/certificate.json` | the witnesses | `3a49fa670d9694bd` |
| `gen/emit_coq_data.py` | JSON → Coq, deterministic | — |
| `E47KernelCertificateData.v` | untrusted data; every use is re-checked by `vm_compute` | see `MANIFEST.sha256` |

A corrupted witness is rejected: changing `beta4`, or one entry of `BK`, makes the file fail to compile.
The container recipe is [`Dockerfile`](Dockerfile); CI is
[`.github/workflows/e47-kernel-certificate.yml`](../../../.github/workflows/e47-kernel-certificate.yml).
