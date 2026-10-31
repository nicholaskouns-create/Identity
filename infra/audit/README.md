# Mnemosyne + Monorail: read-only deployment audit

This is a **non-destructive, metadata-only** companion to the existing private
Mnemosyne ingestion worker and the independent Monorail proof-passport system.
It does not change schemas, RLS, grants, objects, documents, receipt chains,
or the authority of either instrument.

## Live readback

Run `mnemosyne_monorail_snapshot.sql` in an authorized Supabase SQL session
for project `gpkjvihkyectnenvnbng`. It consists of one SELECT and returns a
single JSON `snapshot` value. Save the JSON object (not SQL session logs) to
a **private local file**, then run:

```sh
python infra/audit/evaluate_snapshot.py /path/to/private-snapshot.json
python -m unittest discover -s infra/audit -p 'test_*.py' -v
```

Do not publish snapshots containing later sensitive operational counts or
metadata. The evaluator emits only fixed check statuses, not source content.

## Interpretation boundaries

- `security_baseline=PASS` checks the current worker role, grants, private
  bucket flag, RLS flags and SHA-addressed metadata paths. It does **not**
  certify Storage policy completeness, authenticated ingestion, or a hosted
  service.
- Zero invalid paths on an empty bucket/table is vacuous. A real hosted
  upload, authorized readback, SHA-256 comparison and transactional
  registration remain separate evidence.
- The Monorail receipt table and canonicalizer are presence checks only.
  Hash-only receipts are not signatures or independent attestation.
- KX-E47-KERNEL reconciliation, an independent receipt validator, and
  Threat 20 privileged-trigger bypass require separate source and runtime
  audits. An absent receipt table makes a trigger-bypass test inapplicable,
  **not passed**.
- Encrypted backups and restore verification require independent evidence.
  No backup or restore is performed by this audit.

## Verified preflight, 2026-10-31

The SELECT was executed against the actual Supabase project and returned:
worker NOLOGIN/NOBYPASSRLS, private bucket, source/storage RLS enabled,
no anon/authenticated schema USAGE, zero public client table grants,
two expected worker table grants and zero unexpected worker table grants.
Source documents and private objects both counted zero; both path-anomaly
counts were zero. The Monorail receipts table and canonical SQL function
were absent. No live ingestion, independent validation, Threat 20 clearance
or restore is inferred.

The Python evaluator's 10 offline tests passed locally. GitHub Actions is
configured to rerun them on the pull request; its hosted result must be read
before promotion.
