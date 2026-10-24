# Complete Casimir spectral-kernel census (128/128)

**Canonical source for the Mathematical City.** The exact verifier, full JSON census, and first-principles proof belong here; other repositories and websites should link rather than duplicate.

## Theorem
For H=V₂⊗V₂⊗V₂, dim H=125 and C=J_tot², the seven eigenvalues are Λ={0,2,6,12,20,30,42} with multiplicities {1,9,25,28,27,22,13}. For each subset S⊆Λ define K_S=∏_{λ∈S}(C−λI), empty product I, and P_S=Σ_{λ∈S}∏_{μ∈Λ\{λ}}(C−μI)/(λ−μ). Then ker K_S=⊕_{λ∈S}ker(C−λI); P_S²=P_S=P_S†, K_SP_S=0, tr P_S=Σ_{λ∈S}dim ker(C−λI). Since every eigenvalue occurs, all 2⁷=128 selections are distinct, including the zero and full kernels.

**Canonical E47** S={6,30} rank 47; largest two-sector selection S={12,20} rank 55.

## Evidence
- [Run the exact Python verifier](./validate_128_kernels.py): `python foundry/validate_128_kernels.py > certificate-rebuilt.json`
- [Machine-readable census of 128 cases](./128_kernel_certificate.json)
- [Full proof in Markdown](./128-kernels-proof.md)
- SHA-256 of canonical JSON payload (before inserting digest): `bf0c37928083dd1cb056eb9e55f948eecd7d4334ee8fc6fc9274265d6b639afc`

Reproduced locally: 125 basis-vector annihilator checks, weight multiplicities, rational Lagrange spectral checks, 128/128 selected kernel checks. No independent Lean/Coq compilation, no hardware execution, no separately verified dense-matrix ranks for each of 128 selectors. Existing Notion capacity source: https://app.notion.com/p/3ba46094fd30810f86b9ff01382c4b4f .

## Publication rule
Identity holds the canonical version. The unified website and Notion Mathematical City link to this release; do not fork 128 files or rewrite unrelated project READMEs.
