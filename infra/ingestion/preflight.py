"""Fail-closed PostgreSQL capability preflight for private Mnemosyne ingestion.

Run inside a trusted server-side worker before *any* private Storage upload.
The check is read-only and never returns secrets or private rows.
"""

CHECK_SQL = """
SELECT
  (current_user = session_user) AS direct_login,
  r.rolcanlogin, r.rolsuper, r.rolbypassrls,
  r.rolcreatedb, r.rolcreaterole, r.rolreplication,
  pg_has_role(current_user, 'mnemosyne_worker', 'MEMBER') AS worker_member,
  row_security_active('mnemosyne_private.source_documents'::regclass) AS rls_active,
  has_schema_privilege(current_user, 'mnemosyne_private', 'USAGE') AS schema_usage,
  has_table_privilege(current_user, 'mnemosyne_private.source_documents', 'SELECT') AS source_select,
  has_table_privilege(current_user, 'mnemosyne_private.source_documents', 'INSERT') AS source_insert,
  has_table_privilege(current_user, 'mnemosyne_private.source_documents', 'UPDATE') AS source_update,
  has_table_privilege(current_user, 'mnemosyne_private.source_documents', 'DELETE') AS source_delete,
  has_table_privilege(current_user, 'mnemosyne_private.proof_records', 'SELECT') AS proof_select,
  has_table_privilege(current_user, 'mnemosyne_private.experiment_runs', 'SELECT') AS experiment_select,
  has_table_privilege(current_user, 'mnemosyne_private.provenance_links', 'SELECT') AS provenance_select
FROM pg_roles AS r
WHERE r.rolname = current_user
"""

COLUMNS = (
    'direct_login', 'can_login', 'superuser', 'bypass_rls',
    'create_db', 'create_role', 'replication', 'worker_member',
    'rls_active', 'schema_usage', 'source_select', 'source_insert',
    'source_update', 'source_delete', 'proof_select',
    'experiment_select', 'provenance_select',
)
REQUIRED_TRUE = frozenset({
    'direct_login', 'can_login', 'worker_member', 'rls_active',
    'schema_usage', 'source_select', 'source_insert',
})


def verify_worker_connection(connection):
    """Reject unexpected/overprivileged credentials before uploading bytes.

    This checks the effective login and privilege boundary, not the remote
    Storage service key. It deliberately does not print role names or DSNs.
    """
    with connection.transaction():
        with connection.cursor() as cursor:
            cursor.execute('SET TRANSACTION READ ONLY')
            cursor.execute(CHECK_SQL)
            row = cursor.fetchone()
    if row is None or len(row) != len(COLUMNS):
        raise RuntimeError('Mnemosyne database capability preflight failed')
    facts = dict(zip(COLUMNS, row))
    if any(facts[key] is not True for key in REQUIRED_TRUE) or any(
        facts[key] is not False for key in COLUMNS if key not in REQUIRED_TRUE
    ):
        raise RuntimeError('Mnemosyne database capability preflight failed')
    return True
