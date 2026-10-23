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
