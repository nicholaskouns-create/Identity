-- Read-only, repeatable authorization and storage checks.
-- Execute with a privileged database connection; never from a browser.
-- Each result must be TRUE. No data rows or credentials are returned.
SELECT
  NOT has_schema_privilege('anon', 'mnemosyne_private', 'USAGE')
    AND NOT has_schema_privilege('authenticated', 'mnemosyne_private', 'USAGE')
    AS client_schema_denied,
  NOT has_table_privilege('anon', 'mnemosyne_private.source_documents', 'SELECT')
    AND NOT has_table_privilege('authenticated', 'mnemosyne_private.source_documents', 'SELECT')
    AS client_document_reads_denied,
  has_schema_privilege('service_role', 'mnemosyne_private', 'USAGE')
    AND has_table_privilege('service_role', 'mnemosyne_private.source_documents', 'SELECT')
    AND has_table_privilege('service_role', 'mnemosyne_private.source_documents', 'INSERT')
    AS service_registration_granted,
  NOT has_table_privilege('service_role', 'mnemosyne_private.source_documents', 'UPDATE')
    AND NOT has_table_privilege('service_role', 'mnemosyne_private.source_documents', 'DELETE')
    AND NOT has_table_privilege('service_role', 'mnemosyne_private.proof_records', 'INSERT')
    AS service_grant_scoped,
  EXISTS (SELECT 1 FROM storage.buckets WHERE id='mnemosyne-private' AND public IS FALSE)
    AS private_bucket_retained,
  (SELECT count(*) FROM mnemosyne_private.source_documents) = 0
    AS no_documents_ingested_yet;
