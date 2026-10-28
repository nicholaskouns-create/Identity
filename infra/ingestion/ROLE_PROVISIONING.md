# Restricted Mnemosyne worker capability

This additive migration is for the existing private `mnemosyne_private.source_documents` table and the current `infra/ingestion/ingest.py` and `search.py` scripts. It does not introduce a second ingestion system.

## Boundary

- `mnemosyne_worker` is **NOLOGIN**, **NOINHERIT**, **NOBYPASSRLS**. It has no credential, no members and cannot be used to connect.
- It receives schema USAGE and table SELECT/INSERT only on `mnemosyne_private.source_documents`. No UPDATE, DELETE, table ownership, or rights on proof records, experiments or provenance links.
- Its two RLS policies permit reads and constrain inserts to `historical_source` with a 64-digit lowercase SHA-256 and matching `sha256/xx/digest` storage key.
- No grants to `anon`, `authenticated`, `PUBLIC`, or other web roles. No bucket policy or Edge Function is changed.

## Evidence and remaining work

A rollback-only SQL rehearsal on the live project successfully created the role and policies, temporarily granted the role to the SQL executor, selected from the private source table and inserted a synthetic content-addressed metadata row. The transaction was rolled back. This is **database-level rehearsal only**, not a hosted private Storage round trip.

To finish credential provisioning, an authorized operator must create a separate restricted LOGIN principal and store its generated password/DSN in a server-side secret store, then grant that principal membership in `mnemosyne_worker`. Do not paste a credential into this repository, public GitHub Actions, browser HTML, a chat transcript, or a Supabase Edge Function source file. The current connector does not offer secret-store configuration or a private runner provisioning operation. A dedicated trusted runner must be configured and tested before executing the ingestion worker.

Once the runtime exists: execute `ingest.py FILE --execute` with authorized private Storage access, verify the stored byte digest and registration, then query the same digest through `search.py`. Record the resulting test receipt without exposing the private object or its credentials.

## Local checks

`python -m unittest discover -s infra/ingestion -p 'test_*.py' -v` runs the existing ingestion/search tests and this migration's secret-free static checks. The live database migration must be independently audited after application.
