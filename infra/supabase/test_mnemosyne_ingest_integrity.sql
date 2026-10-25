-- Mnemosyne ingestion integrity regression, privileged SQL session only.
-- The DO probes are real INSERT attempts, each isolated in an exception
-- subtransaction. Accepted probe rows are deliberately rolled back.
-- A failing assertion aborts the statement; no probe row is retained.
-- No private user documents, credentials, or storage objects are read.

-- Metadata/authorization contract: all columns should be TRUE.
SELECT
  (SELECT convalidated FROM pg_constraint
   WHERE conrelid = 'mnemosyne_private.source_documents'::regclass
     AND conname = 'mnemosyne_storage_requires_sha256') IS TRUE
    AS storage_requires_digest,
  (SELECT convalidated FROM pg_constraint
   WHERE conrelid = 'mnemosyne_private.source_documents'::regclass
     AND conname = 'mnemosyne_storage_path_safe') IS TRUE
    AS safe_relative_paths,
  (SELECT convalidated FROM pg_constraint
   WHERE conrelid = 'mnemosyne_private.source_documents'::regclass
     AND conname = 'mnemosyne_metadata_object') IS TRUE
    AS metadata_object_required,
  EXISTS (
    SELECT 1 FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
    WHERE c.relname = 'mnemosyne_source_storage_path_unique'
      AND i.indrelid = 'mnemosyne_private.source_documents'::regclass
      AND i.indisunique AND i.indisvalid
  ) AS storage_paths_unique,
  NOT has_schema_privilege('anon','mnemosyne_private','USAGE')
    AND NOT has_schema_privilege('authenticated','mnemosyne_private','USAGE')
    AS ordinary_clients_denied,
  EXISTS (
    SELECT 1 FROM storage.buckets
    WHERE id = 'mnemosyne-private' AND public IS FALSE
  ) AS bucket_remains_private;

-- Negative/positive INSERT probes: success means all 14 checks passed.
-- Probe titles/paths are synthetic and never committed to the database.
DO $mnemosyne_probe$
DECLARE
  bad_path text;
BEGIN
  -- Positive: well-formed storage-backed record accepted, then rolled back.
  BEGIN
    INSERT INTO mnemosyne_private.source_documents
      (title, storage_path, source_sha256, metadata)
    VALUES ('__mnemosyne_probe_valid__', 'test-only/valid.txt',
            repeat('a',64), '{}'::jsonb);
    RAISE EXCEPTION 'rollback_valid_probe';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'rollback_valid_probe' THEN RAISE; END IF;
  END;

  -- Negative: storage-backed record without a digest.
  BEGIN
    INSERT INTO mnemosyne_private.source_documents (title,storage_path)
    VALUES ('__mnemosyne_probe_missing_digest__','test-only/no-digest.txt');
    RAISE EXCEPTION 'missing_digest_accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- Negative: metadata must be a JSON object, not an array.
  BEGIN
    INSERT INTO mnemosyne_private.source_documents (title,metadata)
    VALUES ('__mnemosyne_probe_array__','[]'::jsonb);
    RAISE EXCEPTION 'array_metadata_accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- Negative: two records cannot point to the same private object.
  BEGIN
    INSERT INTO mnemosyne_private.source_documents
      (title,storage_path,source_sha256)
    VALUES ('__mnemosyne_probe_first__','test-only/duplicate',repeat('b',64));
    INSERT INTO mnemosyne_private.source_documents
      (title,storage_path,source_sha256)
    VALUES ('__mnemosyne_probe_second__','test-only/duplicate',repeat('c',64));
    RAISE EXCEPTION 'duplicate_storage_path_accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  -- Negative: ten unsafe or non-normalized object paths.
  FOREACH bad_path IN ARRAY ARRAY[
    '../escape', '/absolute', 'a/../b', 'a//b', './dot',
    'a/./b', 'a/..', 'a/.', '.', 'a'||chr(92)||'backslash'
  ]
  LOOP
    BEGIN
      INSERT INTO mnemosyne_private.source_documents
        (title,storage_path,source_sha256)
      VALUES ('__mnemosyne_probe_unsafe_path__',bad_path,repeat('d',64));
      RAISE EXCEPTION 'unsafe_path_accepted: %', bad_path;
    EXCEPTION WHEN check_violation THEN NULL;
    END;
  END LOOP;
END;
$mnemosyne_probe$;

-- Verify absence of synthetic probes after the test:
SELECT count(*) = 0 AS no_probe_rows_persisted
FROM mnemosyne_private.source_documents
WHERE title LIKE '__mnemosyne_probe_%';
