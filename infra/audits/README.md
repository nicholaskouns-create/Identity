# Independent Mnemosyne + Monorail read-only posture audit

This is a **separate observer**, not a canonical authority, schema migration, receipt issuer, or validator. It does not replace the private ingestion worker, Monorail route runner, proof receipts, or City Commons. It adds no credentials, public endpoints, RLS grants, objects, or records.

## Run

1. In a trusted operator session, execute `mnemosyne_monorail_posture.sql` against existing project `gpkjvihkyectnenvnbng`. Save the single `posture` JSON value to a **private local file** (do not commit the output).
2. Run `python infra/audits/mnemosyne_monorail_posture.py /private/path/posture.json`.
3. Exit codes: `0` all represented checks pass; `1` malformed snapshot or security regression; `2` security checks pass but operational milestones remain blocked.
4. Run offline tests: `python -m unittest discover -s infra/audits -p 'test_mnemosyne_monorail_posture.py' -v`.

The SQL returns only catalog booleans and aggregate counts, not private rows, document paths, names, credentials, object bytes, or signed claims. It requires an authorized operator and **does not impersonate a restricted login**. Even when the restricted worker's catalog grants pass, this is not evidence of successful live login, upload/readback, ingestion, search, backup or restore.

## Independent evidence boundaries

- A SHA-256 receipt proves byte-level consistency only. It does not prove authorship, provenance attestation, compiler acceptance, independent validation, or resistance to a privileged rewrite.
- Missing `city_formalism.monorail_receipts` and `monorail_checkpoints` are reported as blocked, not silently replaced with the existing `identity_evidence_receipts` table.
- Threat 20 privileged-trigger bypass remains **unverified** even if a receipt table is eventually created. The existence of a trigger is not a privilege or bypass test. No privileged trigger is created here.
- KX-E47-KERNEL E0/E1 evidence-class reconciliation and the unresolved citizen IDs are separate Monorail workstream obligations; this audit does not promote evidence classes.
- Do not commit operator snapshots, private object metadata, source content, credentials or authorization tokens. CI uses synthetic fixtures only.

Relevant existing work: Identity PRs #77 (Monorail route runner), #80/#85/#89/#91 (Mnemosyne worker/search/RLS/preflight), and #107 (navigation repair). This PR is intentionally independent of those feature branches.
