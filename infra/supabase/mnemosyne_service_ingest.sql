-- Applied to Supabase project gpkjvihkyectnenvnbng on 2026-10-24.
-- Migration: mnemosyne_service_source_registration_least_privilege
-- Additive server-side metadata registration only. No public API exposure.
-- This does not provision credentials or make the private schema an exposed API.
GRANT USAGE ON SCHEMA mnemosyne_private TO service_role;
GRANT SELECT, INSERT ON TABLE mnemosyne_private.source_documents TO service_role;

DO $mnemosyne_access_check$
BEGIN
  IF has_schema_privilege('anon', 'mnemosyne_private', 'USAGE')
     OR has_schema_privilege('authenticated', 'mnemosyne_private', 'USAGE')
     OR has_table_privilege('anon', 'mnemosyne_private.source_documents', 'SELECT')
     OR has_table_privilege('authenticated', 'mnemosyne_private.source_documents', 'SELECT')
  THEN
    RAISE EXCEPTION 'Mnemosyne client isolation failed';
  END IF;

  IF NOT has_schema_privilege('service_role', 'mnemosyne_private', 'USAGE')
     OR NOT has_table_privilege('service_role', 'mnemosyne_private.source_documents', 'SELECT')
     OR NOT has_table_privilege('service_role', 'mnemosyne_private.source_documents', 'INSERT')
  THEN
    RAISE EXCEPTION 'Mnemosyne service registration privileges missing';
  END IF;

  IF has_table_privilege('service_role', 'mnemosyne_private.source_documents', 'UPDATE')
     OR has_table_privilege('service_role', 'mnemosyne_private.source_documents', 'DELETE')
     OR has_table_privilege('service_role', 'mnemosyne_private.proof_records', 'INSERT')
  THEN
    RAISE EXCEPTION 'Mnemosyne grant exceeds source registration scope';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM storage.buckets
    WHERE id = 'mnemosyne-private' AND public IS FALSE
  ) THEN
    RAISE EXCEPTION 'Mnemosyne private bucket missing or public';
  END IF;
END;
$mnemosyne_access_check$;
