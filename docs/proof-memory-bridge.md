# Identity Proof Memory Bridge (v0.1, additive)

Purpose: make the existing Mathematical City algebraic database a read-only, provenance-aware proof retrieval engine for the Identity site. This document is an implementation contract, not a claim that ingestion is deployed.

## Canonical storage already exists

- public.mathematical_identities (citizen_code, statement_latex, parent_identity_codes, evidence_class, validation_status, metadata)
- public.machine_certificates (certificate_code, commit_sha, environment, result, valid, evidence_class)
- public.citizen_proof_candidates (proof_code, conjecture_latex, validation_results, approval_state)
- public.theorem_graph_edges (source_code, target_code, relation_type)
- public.citizen_code_bindings (artifact_code, binding_role)

Never replace canonical rows or reinterpret historical evidence classes. Proof metadata should be additive.

## CI → verified manifest → privileged ingest → retrieval

1. CI compiles each exact Lean and Coq theorem, printing assumptions and compiler versions.
2. CI emits a signed or GitHub-OIDC-attributable JSON manifest containing repository, commit SHA, workflow run URL, theorem-qualified name, statement/source SHA-256, compiler, compiler version, dependency citizen codes, assumptions, compilation status, and scope note. Include a separate manifest per assistant; pair only if theorem statements are explicitly cross-checked.
3. A private ingest service verifies the GitHub workflow provenance against GitHub's API, pins immutable commit/source hashes, checks the citizen exists and parent codes are consistent, and stores an append-only evidence record. No self-attested 'pass' field is trusted.
4. A reviewer-approved promotion can update a canonical citizen's proof metadata; never rewrite evidence_class or validation_status automatically.
5. An authenticated read API returns theorem statements, ancestor/dependency graph, exact verified certificates and open obligations. The Identity website renders this as 'Proof DNA' with source and CI links.

## Manifest example (schema sketch, not a verified certificate)

```json
{
  "schema": "identity.proof-memory.v1",
  "citizen_code": "E47-CASIMIR-SPECTRUM",
  "repository": "nicholaskouns-create/Identity",
  "commit_sha": "<40-hex-commit>",
  "lean": {"path": "formal/e47/...lean", "theorem": "...", "source_sha256": "...", "run_url": "...", "status": "verified"},
  "coq": {"path": "formal/e47/...v", "theorem": "...", "source_sha256": "...", "run_url": "...", "status": "verified"},
  "assumptions": [],
  "scope": "Only the exact statements compiled, not unproved spectral claims",
  "parent_identity_codes": ["E47-CARRIER-125"]
}
```

## API contract

- GET /proof-dna?citizen_code=... : canonical identity + parent codes + verified evidence + open obligations.
- GET /proof-dna/ancestors?citizen_code=... : bounded ancestry traversal, cycle detection and missing-parent warnings.
- GET /proof-dna/search?q=... : parameterized statement/title/code search, with access control.
- POST /proof-dna/ingest : server-to-server only, authenticated, idempotent on (repo, commit, theorem, assistant, source hash).

## Security invariants

- Supabase service-role credentials NEVER ship to GitHub Pages/browser code.
- Public site uses only a deliberately authorized read-only API; RLS and access-scope filters must be enforced. Never expose private citizen metadata by default.
- No anonymous insert/update, no public SECURITY DEFINER, no SQL built by concatenating search strings.
- Certificate verification is separate from canonical promotion.
- A compiler pass proves only the elaborated theorem in its declared axiomatic context; audit sorry/admit, axioms, dependency hashes and statement equivalence.
- Keep a failure/correction ledger; never erase prior evidence.

## Next implementation gate

Inspect existing Edge Functions, RLS policies and table constraints; add a dedicated append-only proof_evidence table only if machine_certificates cannot express the required provenance. Build the authenticated ingestion endpoint, test a real CI manifest from PR #26/#27, then wire the Identity site to the read endpoint. No production ingestion or UI deployment is claimed here.
