-- Mnemosyne private metadata worker capability role.
-- This is NOT a login or credential. Create a separate, privately managed
-- LOGIN role and grant it this capability only after secret-store provisioning.
-- Existing public/anonymous roles and existing evidence tables are untouched.
-- Apply once using a reviewed migration. No destructive operations.
CREATE ROLE mnemosyne_worker
  NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;

GRANT USAGE ON SCHEMA mnemosyne_private TO mnemosyne_worker;
GRANT SELECT, INSERT ON TABLE mnemosyne_private.source_documents TO mnemosyne_worker;

-- RLS is already enabled. A table grant alone is not enough.
-- These policies apply ONLY to the non-login worker role.
CREATE POLICY mnemosyne_worker_select
  ON mnemosyne_private.source_documents
  FOR SELECT TO mnemosyne_worker USING (true);

CREATE POLICY mnemosyne_worker_insert
  ON mnemosyne_private.source_documents
  FOR INSERT TO mnemosyne_worker
  WITH CHECK (
    evidence_class = 'historical_source'
    AND source_sha256 ~ '^[0-9a-f]{64}$'
    AND storage_path = ('sha256/' || left(source_sha256, 2) || '/' || source_sha256)
  );
