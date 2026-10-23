# Mnemosyne: GitHub-native, local-first core

This is an operational browser archive designed for GitHub Pages. Records are stored in IndexedDB first. Optional email sign-in copies verified records to the signed-in account. Open `site/index.html` on a secure origin (GitHub Pages or localhost) to use IndexedDB and WebCrypto.

## What works
- Create categorized research records in browser IndexedDB.
- SHA-256 content receipts and verification on rendering/import.
- Search, JSON export, verified JSON import.
- Same-browser live updates across tabs.
- Optional email-code sign-in and owner-scoped cross-device sync.

## Explicit limitations
- Without sign-in, browser data is device-local.
- SHA-256 checks integrity against accidental modification; it does **not** establish authorship, external timestamp, or tamper-proof provenance (an attacker can recompute a digest).
- Sync is not end-to-end encryption. Signed-in rows are readable by that user and by this project's database owner.
- The published page does not include a service key, and unsigned visitors cannot read the account table.
- **Do not publish private research records on public Pages**. The archive UI is public; the records are not, unless you export them or sync them to the account.
- No claims of measured performance superiority are made.

## Deployment
The live site is the `site/` directory on the GitHub Pages branch. Verification runs from `.github/workflows/mnemosyne-site.yml`.

## Migration boundary
Private research tables are not copied into the browser archive by this page. Do not delete existing private data until an explicit export, count check, and restore have passed.