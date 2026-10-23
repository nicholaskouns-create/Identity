# Data migration and synchronization

The site is local-first. Optional sync is a separate browser module and does not replace an export.

## Migration
1. Export source rows with approved access into a private JSON file containing `{"tables":{"schema.table":[...]}}`. Never commit the export.
2. Run `python tools/migrate_archive.py /private/source.json /private/mnemosyne.json`.
3. Confirm table counts in the manifest, SHA-256 receipts, and restore in a browser via Import.
4. Preserve source backups until independent restore and completeness checks pass.

**Status:** converter implemented and unit-tested; live private tables have NOT been exported into the public archive table.

## Synchronization
Signed-in browsers upsert verified records to `public.mnemosyne_records` and pull rows whose receipts still match. The canonical receipt is `JSON.stringify([id,title,kind,content,created_at])`. `updated_at` is outside the receipt and is used only for last-write-wins. A record with no local `updated_at` is treated as a new local edit and wins over an older remote copy. Rows that fail the receipt check are not imported.

The browser stores only that user's session in localStorage. Do not place a service-role key, personal access token, or private-schema credential in Pages JS or the repository.

## Publishing
Workflow `.github/workflows/mnemosyne-site.yml` checks the site. While Pages uses a branch source, that workflow verifies and does not replace the live branch. A public Pages URL is not a private archive.