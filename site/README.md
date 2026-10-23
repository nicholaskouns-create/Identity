# Mnemosyne: GitHub-native, local-first core

This is an **operational, dependency-free browser archive** designed for GitHub Pages. It requires no Supabase and no runtime server. Open `site/index.html` on a secure origin (GitHub Pages or localhost) to use IndexedDB and WebCrypto.

## What works in this initial implementation
- Create categorized research records in browser IndexedDB.
- SHA-256 content receipts and verification on rendering/import.
- Search, JSON export, verified JSON import.
- Entire interface works offline after loading the assets, provided they are cached by the browser (no service worker yet).

## Explicit limitations
- Browser data is device-local, not shared or automatically synced across devices.
- SHA-256 checks integrity against accidental modification; it does **not** establish authorship, external timestamp, or tamper-proof provenance (an attacker can recompute a digest).
- No user accounts, multiuser permissions, remote database, server-side workflows, scheduled jobs, or encrypted backups.
- GitHub Pages cannot itself run an API, database, or Edge Function. GitHub Actions and Git objects can supply versioned, automated publication, but are not an equivalent always-on transactional backend.
- **Do not publish private research records on public Pages**. Keep archives private or publish only explicitly selected public records.
- No claims of measured performance superiority over Supabase are made.

## Deployment
Host the `site/` directory via a GitHub Pages publishing workflow or copy its contents into an existing Pages site's publish directory. This branch is intentionally a reviewable PR, not a production cutover.

## Migration boundary
Existing Supabase records are **not yet migrated**. Migration requires exporting and checking the source datasets, preserving identifiers and provenance, verifying record counts and checksums, then testing restoration. Do not delete the existing Supabase project until those checks pass.

## Next stages
1. Read-only, redacted export adapters for existing source tables and certificates.
2. GitHub Actions CI and versioned public snapshot publishing.
3. IndexedDB search indexing and content-addressed attachments.
4. GitHub-authenticated private write workflow, with explicit authorization and least privilege.
5. Cross-device sync with conflict resolution, measured performance tests, and independent backup verification.
