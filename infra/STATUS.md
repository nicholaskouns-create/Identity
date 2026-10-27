# Mnemosyne infrastructure deployment status · 2026-10-23

## Live and verified
- Existing Supabase project `gpkjvihkyectnenvnbng`, unchanged outside dedicated Mnemosyne resources.
- Private `mnemosyne_private` schema and four RLS-enabled tables; anonymous and ordinary authenticated schema usage denied.
- Dedicated `mnemosyne-private` storage bucket, `public=false`, maximum 50 MiB per object.
- One E47 theorem record and three repository provenance links seeded; verified database counts 1/3 and private bucket count 1.
- Python stdlib private Storage uploader with content-addressed SHA-256 key, MIME allowlist, size bound, and no hardcoded secret.

## Not yet end-to-end verified
- Live ingestion: no authorized service key was retrieved or used; upload script has not been exercised against hosted Storage.
- Historical source extraction, vector search, authenticated application console, and scheduled scientific workers.
- Encrypted external backup and full restore; no independent recovery target or encryption-key custody configured.
- Proof of owner-only access for future API clients; existing schema is currently deny-by-default.
- Pull requests are not merged.

## Security posture
Do not publish privileged credentials. Private buckets are not sufficient without storage object policies and/or restricted server-side credentials. The server-side uploader is intentionally not an anonymous API. Avoid running it on untrusted machines.

## To complete
Provision a restricted execution environment and credential delivery; register metadata transactionally with upload; build local embedding/index pipeline; authenticated owner-only query API; CI checks; encrypted off-site backup and restore drill. Verify with authorized and unauthorized requests before describing as operational.

## 2026-10-24 · Least-privilege registration step

- Applied migration `mnemosyne_service_source_registration_least_privilege` to the existing Supabase project.
- Granted `service_role` schema USAGE and only SELECT/INSERT on `mnemosyne_private.source_documents`. No UPDATE/DELETE on that table and no INSERT on proof records.
- Rechecked live privilege metadata: `anon` and `authenticated` retain no schema USAGE or document access. The dedicated bucket remains private.
- Readback counts: 0 source documents, 0 private objects, 1 proof record, 3 provenance links. No data was uploaded.
- Reproducible SQL and read-only privilege checks: `mnemosyne_service_ingest.sql` and `test_mnemosyne_service_ingest.sql`.
- **Remaining:** No service credential was accessed; the schema is not exposed to PostgREST. An authorized server-side registration worker, real upload/download authorization tests, ingestion transaction, search, scientific workers, encrypted backups, and restore drill are not yet complete.
- **Review boundary:** Changes are proposed on an unmerged branch/PR. The already-applied database migration is additive and did not grant client or public access.


## 2026-10-26 · Verified-byte ingestion worker (draft, code only)

- Inspected existing project, private schema, bucket, migration history, Edge Functions and open Identity PRs before editing. Prior PR #66 was merged, and the 2026-10-25 metadata-integrity migration is present live.
- Extended existing `infra/ingestion/ingest.py` rather than creating a parallel ingestion system: offline receipt by default; explicit trusted `--execute` uploads without overwrite, performs authorized Storage GET and SHA-256/length readback, then registers metadata transactionally through a separate restricted PostgreSQL connection.
- Duplicate objects/metadata are accepted only after digest comparison. Tampered readback, unauthorized HTTP and failed DB registration do not create document rows. No automatic deletion of unregistered objects.
- Local Python 3.13: **15/15** tests passed, including real loopback HTTP roundtrips and negative-path tests; Python bytecode compilation passed. The dedicated no-secret PR workflow has been added; GitHub Actions status must be checked separately.
- Live Supabase rollback-only SQL probe exercised INSERT, the partial-index ON CONFLICT clause, digest lookup and SET LOCAL ROLE service_role. Post-rollback readback: 0 source documents, 0 private bucket objects, bucket public=false, 0 synthetic rows.
- **Not yet hosted end-to-end:** No service credential or restricted PostgreSQL DSN was provisioned or used. No real Supabase Storage upload/download, worker deployment, owner identity verification, search, research API, simulation workers, encrypted backups, or restore drill is claimed.
- This branch is review-only: no migration, Edge Function deployment, public policy, credential, private content, or merge.

## 2026-10-27 · Private metadata search (stacked draft)

- Inspected active Supabase project and all open Identity PRs; builds on existing unmerged ingestion PR #80 rather than duplicating it.
- Added read-only, parameterized metadata search for title, optional description, and exact SHA-256. Query and result bounds, LIKE literal escaping, transaction READ ONLY and 5-second timeout are enforced. No public endpoint, client credentials, Storage content, or schema grants.
- Local Python 3.13.5: 10/10 new search tests PASS; Python compilation PASS. Live Supabase EXPLAIN accepted the query on the actual private schema; security/count readback: 0 source documents, 0 private objects, bucket public=false, anon/authenticated schema USAGE=false, service_role SELECT=true and UPDATE=false.
- GitHub Actions for the new branch must be checked independently. No hosted search was executed because a restricted operator DSN was not provisioned.
- This branch is stacked on draft PR #80, is review-only and unmerged. Private document search over real uploaded content, authorization tests, research API, simulations, encrypted backups and restore drill remain pending.
