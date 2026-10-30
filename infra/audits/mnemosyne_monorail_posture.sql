-- Read-only deployment posture. Execute as a trusted operator; returns one JSON object.
-- No private document rows, object paths, credentials or payloads are returned.
-- This query DOES NOT impersonate the restricted worker or test live ingestion.
WITH bucket AS (
  SELECT id, public, file_size_limit FROM storage.buckets WHERE id = 'mnemosyne-private'
), role_info AS (
  SELECT rolname, rolcanlogin, rolbypassrls, rolsuper FROM pg_roles WHERE rolname = 'mnemosyne_worker'
), private_table AS (
  SELECT c.oid, c.relrowsecurity FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'mnemosyne_private' AND c.relname = 'source_documents' AND c.relkind = 'r'
), policies AS (
  SELECT count(*) FILTER (WHERE policyname = 'mnemosyne_worker_select' AND cmd = 'SELECT'
    AND 'mnemosyne_worker' = ANY(roles)) AS worker_select_policies,
    count(*) FILTER (WHERE policyname = 'mnemosyne_worker_insert' AND cmd = 'INSERT'
    AND 'mnemosyne_worker' = ANY(roles) AND with_check IS NOT NULL) AS worker_insert_policies
  FROM pg_policies WHERE schemaname = 'mnemosyne_private' AND tablename = 'source_documents'
), receipts AS (
  SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'city_formalism' AND c.relname = 'monorail_receipts' AND c.relkind = 'r'
), checkpoints AS (
  SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'city_formalism' AND c.relname = 'monorail_checkpoints' AND c.relkind = 'r'
)
SELECT jsonb_build_object(
  'schema_version', 1,
  'bucket_present', EXISTS (SELECT 1 FROM bucket),
  'bucket_private', COALESCE((SELECT NOT public FROM bucket), false),
  'bucket_size_limit', (SELECT file_size_limit FROM bucket),
  'source_rows', (SELECT count(*) FROM mnemosyne_private.source_documents),
  'private_objects', (SELECT count(*) FROM storage.objects WHERE bucket_id = 'mnemosyne-private'),
  'worker_present', EXISTS (SELECT 1 FROM role_info),
  'worker_no_login', COALESCE((SELECT NOT rolcanlogin FROM role_info), false),
  'worker_no_bypassrls', COALESCE((SELECT NOT rolbypassrls AND NOT rolsuper FROM role_info), false),
  'source_rls_enabled', COALESCE((SELECT relrowsecurity FROM private_table), false),
  'anon_schema_denied', NOT has_schema_privilege('anon', 'mnemosyne_private', 'USAGE'),
  'authenticated_schema_denied', NOT has_schema_privilege('authenticated', 'mnemosyne_private', 'USAGE'),
  'worker_select', has_table_privilege('mnemosyne_worker', 'mnemosyne_private.source_documents', 'SELECT'),
  'worker_insert', has_table_privilege('mnemosyne_worker', 'mnemosyne_private.source_documents', 'INSERT'),
  'worker_update_denied', NOT has_table_privilege('mnemosyne_worker', 'mnemosyne_private.source_documents', 'UPDATE'),
  'worker_delete_denied', NOT has_table_privilege('mnemosyne_worker', 'mnemosyne_private.source_documents', 'DELETE'),
  'worker_select_policy', (SELECT worker_select_policies = 1 FROM policies),
  'worker_insert_policy', (SELECT worker_insert_policies = 1 FROM policies),
  'restricted_runtime_login_present', EXISTS (
    SELECT 1 FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.roleid
    JOIN pg_roles member ON member.oid=m.member
    WHERE r.rolname='mnemosyne_worker' AND member.rolcanlogin AND member.rolname <> 'postgres'
      AND m.set_option AND NOT member.rolsuper AND NOT member.rolbypassrls
  ),
  'monorail_receipts_present', EXISTS (SELECT 1 FROM receipts),
  'monorail_checkpoints_present', EXISTS (SELECT 1 FROM checkpoints),
  'monorail_receipt_trigger_count', (
    SELECT count(*) FROM pg_trigger t JOIN receipts r ON r.oid=t.tgrelid WHERE NOT t.tgisinternal
  )
) AS posture;
