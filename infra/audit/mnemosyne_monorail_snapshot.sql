-- Mnemosyne / Monorail read-only deployment snapshot, contract v1.
-- Execute only in a trusted SQL session; this SELECT makes no changes.
-- Metadata and counts only: no document bodies, credentials or object bytes.
-- A passing configuration baseline is NOT a hosted ingestion, restore,
-- independent-validator, KX reconciliation or Threat 20 clearance.
select jsonb_build_object(
'schema','mnemosyne_monorail_audit.v1',
'mnemosyne',jsonb_build_object(
'worker_nologin',coalesce((select not rolcanlogin from pg_roles where rolname='mnemosyne_worker'),false),
'worker_no_bypassrls',coalesce((select not rolbypassrls from pg_roles where rolname='mnemosyne_worker'),false),
'private_bucket',coalesce((select not public from storage.buckets where id='mnemosyne-private'),false),
'source_rls',coalesce((select relrowsecurity from pg_class where oid=to_regclass('mnemosyne_private.source_documents')),false),
'storage_rls',coalesce((select relrowsecurity from pg_class where oid=to_regclass('storage.objects')),false),
'anon_schema_usage',has_schema_privilege('anon','mnemosyne_private','USAGE'),
'authenticated_schema_usage',has_schema_privilege('authenticated','mnemosyne_private','USAGE'),
'public_table_grants',(select count(*) from information_schema.role_table_grants where table_schema='mnemosyne_private' and grantee in ('anon','authenticated','PUBLIC')),
'worker_expected_grants',(select count(*) from information_schema.role_table_grants where table_schema='mnemosyne_private' and grantee='mnemosyne_worker' and table_name='source_documents' and privilege_type in ('SELECT','INSERT')),
'worker_unexpected_grants',(select count(*) from information_schema.role_table_grants where table_schema='mnemosyne_private' and grantee='mnemosyne_worker' and (table_name<>'source_documents' or privilege_type not in ('SELECT','INSERT'))),
'source_documents',(select count(*) from mnemosyne_private.source_documents),
'private_objects',(select count(*) from storage.objects where bucket_id='mnemosyne-private'),
'invalid_content_paths',(select count(*) from mnemosyne_private.source_documents where storage_path is not null and (source_sha256 !~ '^[0-9a-f]{64}$' or storage_path <> 'sha256/'||left(source_sha256,2)||'/'||source_sha256)),
'invalid_object_paths',(select count(*) from storage.objects where bucket_id='mnemosyne-private' and (name !~ '^sha256/[0-9a-f]{2}/[0-9a-f]{64}$' or split_part(name,'/',2)<>left(split_part(name,'/',3),2)))
),
'monorail',jsonb_build_object(
'receipts_table_exists',to_regclass('city_formalism.monorail_receipts') is not null,
'canonical_sql_exists',exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='city_formalism' and p.proname='monorail_canonical_json'),
'receipt_triggers',(select count(*) from pg_trigger t where t.tgrelid=to_regclass('city_formalism.monorail_receipts') and not t.tgisinternal),
'privileged_receipt_triggers',(select count(*) from pg_trigger t join pg_proc p on p.oid=t.tgfoid where t.tgrelid=to_regclass('city_formalism.monorail_receipts') and not t.tgisinternal and p.prosecdef),
'independent_validator_status','not_assessed'
)) as snapshot;
