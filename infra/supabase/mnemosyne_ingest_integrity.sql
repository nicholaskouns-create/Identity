-- Mnemosyne private ingestion metadata integrity, 2026-10-25.
-- Apply once through a named Supabase migration. No content or credentials.
-- Does not grant access, expose schemas, create policies, or touch storage objects.
-- Existing source_sha256 constraint already requires lowercase 64-hex when present.
--
-- A storage-backed document must carry its digest. Paths remain caller-chosen,
-- but must be relative, normalized, and unique to prevent ambiguous registration.
-- This validates metadata shape, NOT the hash of the stored bytes. The future
-- authorized ingestion worker must compute SHA-256 over the uploaded bytes.

DO $mnemosyne_preflight$
BEGIN
  IF EXISTS (
    SELECT 1 FROM mnemosyne_private.source_documents
    WHERE (storage_path IS NOT NULL AND source_sha256 IS NULL)
       OR jsonb_typeof(metadata) IS DISTINCT FROM 'object'
       OR (
         storage_path IS NOT NULL AND NOT (
           length(storage_path) BETWEEN 1 AND 512
           AND btrim(storage_path) = storage_path
           AND storage_path NOT IN ('.', '..')
           AND storage_path NOT LIKE '/%'
           AND storage_path NOT LIKE '%//%'
           AND storage_path NOT LIKE '../%'
           AND storage_path NOT LIKE '%/../%'
           AND storage_path NOT LIKE '%/..'
           AND storage_path NOT LIKE './%'
           AND storage_path NOT LIKE '%/./%'
           AND storage_path NOT LIKE '%/.'
           AND position(chr(92) in storage_path) = 0
           AND storage_path !~ '[[:cntrl:]]'
         )
       )
  ) THEN
    RAISE EXCEPTION 'Existing Mnemosyne metadata requires manual review; no changes applied';
  END IF;

  IF EXISTS (
    SELECT 1 FROM mnemosyne_private.source_documents
    WHERE storage_path IS NOT NULL
    GROUP BY storage_path HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Duplicate existing Mnemosyne storage paths; no changes applied';
  END IF;
END;
$mnemosyne_preflight$;

ALTER TABLE mnemosyne_private.source_documents
  ADD CONSTRAINT mnemosyne_storage_requires_sha256
    CHECK (storage_path IS NULL OR source_sha256 IS NOT NULL),
  ADD CONSTRAINT mnemosyne_storage_path_safe
    CHECK (
      storage_path IS NULL OR (
        length(storage_path) BETWEEN 1 AND 512
        AND btrim(storage_path) = storage_path
        AND storage_path NOT IN ('.', '..')
        AND storage_path NOT LIKE '/%'
        AND storage_path NOT LIKE '%//%'
        AND storage_path NOT LIKE '../%'
        AND storage_path NOT LIKE '%/../%'
        AND storage_path NOT LIKE '%/..'
        AND storage_path NOT LIKE './%'
        AND storage_path NOT LIKE '%/./%'
        AND storage_path NOT LIKE '%/.'
        AND position(chr(92) in storage_path) = 0
        AND storage_path !~ '[[:cntrl:]]'
      )
    ),
  ADD CONSTRAINT mnemosyne_metadata_object
    CHECK (jsonb_typeof(metadata) = 'object');

CREATE UNIQUE INDEX mnemosyne_source_storage_path_unique
  ON mnemosyne_private.source_documents (storage_path)
  WHERE storage_path IS NOT NULL;
