# Data migration and secure synchronization

The site is deliberately **local-first**. No Supabase dependency is present in the browser application.

## Migration
1. Export source rows with approved access into a private JSON file containing `{"tables":{"schema.table":[...]}}`. Never commit the export.
2. Run `python tools/migrate_archive.py /private/source.json /private/mnemosyne.json`.
3. Confirm table counts in the manifest, SHA-256 receipts, and restore in a browser via Import.
4. Preserve source backups until independent restore and completeness checks pass.

**Status:** converter implemented and unit-tested; live production data has NOT been exported or migrated.

## Synchronization
Local import/export is available. Authenticated cross-device synchronization is **not yet implemented**. GitHub Pages is static and cannot safely hold GitHub personal access tokens or private records. A secure sync implementation requires OAuth authorization and a trusted server-side component (e.g., a tightly scoped GitHub App with Actions or an explicitly authorized user-mediated flow). Do not place tokens in localStorage, query strings, Pages JS, or public repositories.

## Publishing
Workflow `.github/workflows/mnemosyne-site.yml` checks code and deploys **only** the `site/` directory after verification. GitHub Pages must be enabled with **GitHub Actions** as the source; account and private-repository Pages eligibility may affect deployment. A public Pages URL is not a private archive. No private export is bundled.
