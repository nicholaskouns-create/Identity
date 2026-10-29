# Mnemosyne verified private ingestion

This is an additive, server-side worker in the existing Identity repository. It is **not** a public API, browser client, or deployment of credentials.

## Offline test and receipt

Run `python -m unittest discover -s infra/ingestion -p 'test_*.py' -v` at the repository root. The tests start a real loopback HTTP Storage fixture and exercise upload, authenticated download, SHA-256 verification, idempotency, unauthorized requests, tampering, registration failures, and safe input rejection. No Supabase secrets or network connection are used.

Run `python infra/ingestion/ingest.py /path/to/file.pdf` for an offline SHA-256 receipt. The default does **not** upload or register any content.

## Trusted operator execution (not yet end-to-end deployed)

In a trusted environment with a restricted PostgreSQL login, install psycopg 3 and provide `MNEMOSYNE_DB_DSN` and `MNEMOSYNE_SERVICE_KEY` from an external secret store. Then run `python infra/ingestion/ingest.py /path/to/file.pdf --execute`.

The service key is for private Storage HTTP; the DSN is a separate PostgreSQL credential. A Supabase service-role API key is **not** a PostgreSQL DSN. The DB login must have only schema USAGE and SELECT/INSERT on `mnemosyne_private.source_documents`. Do not log or commit either credential.

The worker uploads to `mnemosyne-private/sha256/<prefix>/<digest>` with `x-upsert: false`, downloads the stored object with authorization, verifies its exact byte count and SHA-256, and only then inserts source metadata in a transaction. Duplicate objects and records are accepted only after digest verification. It does not DELETE or overwrite any object.

If registration fails after successful upload, an unregistered object can remain. Reconcile these orphans explicitly after reviewing provenance; no automatic destructive cleanup is performed.

## Evidence boundary

Localhost integration tests and rollback-only live SQL checks verify code behavior and the deployed table's SQL contract. They do not establish real hosted Storage upload/download, restricted-login connectivity, operator authorization, encrypted backups, or restore. A production rollout requires separately provisioned least-privilege credentials and an authorized, non-sensitive test object with a successful hosted readback and registration.

The `mnemosyne_private` schema remains inaccessible to anonymous and ordinary authenticated clients. No public endpoint or RLS policy is created.

## Private metadata search (2026-10-27)

Run `MNEMOSYNE_DB_DSN=... python infra/ingestion/search.py "search term" --limit 20` in a trusted operator environment with a restricted PostgreSQL SELECT login. Search covers registered title, optional metadata description, and exact SHA-256 digest. Results contain only id, title, digest, evidence class and timestamp. Search is bounded to 1–100 rows, uses parameterized SQL, escapes LIKE metacharacters, sets the transaction READ ONLY and a 5-second statement timeout. No public endpoint, browser connection, storage path, document body, or privileged credential is introduced.

The existing private ingestion test workflow discovers `test_search.py` alongside ingestion tests. Run `python -m unittest discover -s infra/ingestion -p 'test_*.py' -v` for secret-free tests. This is metadata-only search, not document extraction, full-text indexing, or a deployed owner-authorized research API.

## Fail-closed connection preflight (2026-10-29)

Before any private Storage POST, `ingest.py --execute` now runs `preflight.verify_worker_connection()` in a read-only PostgreSQL transaction. The effective login must be a direct LOGIN member of `mnemosyne_worker`, with active row-level security, schema USAGE and source-document SELECT/INSERT. Superuser, BYPASSRLS, CREATE DATABASE/ROLE, replication, UPDATE/DELETE and SELECT on other Mnemosyne evidence tables are rejected. An unexpected or incomplete SQL result fails closed. No DSN, password or private rows are printed by the preflight.

**Provisioning contract, not a provisioned credential:** the owner-authorized secret store must supply a dedicated restricted PostgreSQL LOGIN whose effective grants match this preflight, plus the separately managed private Storage service token. A PostgreSQL role membership alone is not a database password or a trusted execution environment. The worker deliberately refuses a privileged administrator DSN, even if that administrator could access the table. Configure membership inheritance so the login has the intended effective grants while RLS remains active.

Unit tests cover every required and forbidden privilege, malformed responses, and the guarantee that a rejected login cannot reach the Storage upload call. The new checks do not establish hosted login connectivity or byte-level private Storage readback. The existing database and private bucket are unchanged by this PR.
