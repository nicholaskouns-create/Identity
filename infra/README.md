# Mnemosyne · Private Supabase infrastructure

**Live foundation deployed 2026-10-23** into existing Supabase project `gpkjvihkyectnenvnbng` (us-west-2). No credentials are committed.

## Live resources

- Private schema: `mnemosyne_private`
- Tables: `source_documents`, `proof_records`, `experiment_runs`, `provenance_links`
- All four tables have RLS enabled with no ordinary-client policies.
- `anon` and `authenticated` have no schema USAGE privilege (verified).
- Existing private buckets `city-apps` and `research-engine-artifacts` were observed but **not** modified.
- Existing City public-schema research tables remain untouched.

## Security model

The schema is inaccessible via standard Supabase browser roles. It is **not** a browser-ready API: a future backend must use narrowly scoped server-side credentials or an explicit authenticated access pathway, following a separate security review. Never place privileged Supabase credentials in Git, frontend JavaScript, logs, or documentation.

Before enabling any client API, define an authorization model, grant only necessary operations, write RLS policies, test allow/deny for different principals, and audit security advisors. A private GitHub repository does not confer private access to hosted web apps.

## Validation

Supabase migration `mnemosyne_private_research_foundation` returned success. Readback confirmed both `anon_usage=false` and `authenticated_usage=false`. Security advisor reports RLS-without-policy informational findings for the four tables; **this is intentional deny-by-default**, not a permission gap. Other advisor findings across the existing project have not been remediated as part of this change.

## Next integration stages

1. Assign explicit owner and operator roles and test isolation.
2. Select/create a dedicated private storage bucket, with policies and tests.
3. Implement a restricted ingestion worker to hash, index, and catalog source documents.
4. Add a protected research API and authenticated console.
5. Connect E47/Time/Mnemosyne validation workers; record immutable input/output hashes.
6. Add encrypted backups and verify a full restore.

All imports require explicit provenance and access review. No historical files or secrets were ingested by this migration.

## 2026-10-25 · Storage-backed source integrity (live)

- Applied additive migration `mnemosyne_ingest_integrity_20261025` to the existing project. Source SQL: [mnemosyne_ingest_integrity.sql](supabase/mnemosyne_ingest_integrity.sql).
- Storage-backed source rows now require a lowercase 64-character SHA-256 digest (existing digest format constraint), a safe relative storage path (new check), and a unique non-null storage path (new partial unique index). Metadata must be a JSON object. Reference-only rows with no storage path remain possible.
- Verified against the live database: six schema/access/storage assertions true; 14 rollback-only insert probes passed (one valid, missing digest, non-object metadata, duplicate storage path, ten unsafe paths); no probe rows persisted.
- Ordinary clients still have no access to the private schema. The bucket remains private. No credentials or documents were uploaded.
- **Evidence boundary:** these are metadata consistency and database authorization checks, not a cryptographic verification of stored object bytes. A future authorized ingestion worker must compute SHA-256 from actual bytes, register only after successful private upload, and verify download integrity. No public endpoint or worker was deployed by this change.
- **Remaining:** explicit owner authorization, authenticated ingestion/upload/download tests, search, research API, E47/quantum workers, encrypted off-site backup, and a real restore drill.
