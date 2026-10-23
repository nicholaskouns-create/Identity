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
