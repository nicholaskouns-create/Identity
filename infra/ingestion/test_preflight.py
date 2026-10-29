"""Credential-free tests of the fail-closed private worker capability preflight."""
import unittest
import os
import sys
from types import SimpleNamespace
from contextlib import contextmanager, nullcontext
from unittest.mock import patch

from preflight import CHECK_SQL, COLUMNS, REQUIRED_TRUE, verify_worker_connection


class FakeConnection:
    def __init__(self, row):
        self.row = row
        self.calls = []
        self.transactions = 0

    @contextmanager
    def transaction(self):
        self.transactions += 1
        yield self

    @contextmanager
    def cursor(self):
        yield self

    def execute(self, sql):
        self.calls.append(sql)

    def fetchone(self):
        return self.row


def good_row():
    return tuple(key in REQUIRED_TRUE for key in COLUMNS)


class PreflightTests(unittest.TestCase):
    def test_accepted_least_privilege_role(self):
        db = FakeConnection(good_row())
        self.assertTrue(verify_worker_connection(db))
        self.assertEqual(db.transactions, 1)
        self.assertEqual(db.calls, ['SET TRANSACTION READ ONLY', CHECK_SQL])

    def test_rejects_any_missing_required_capability(self):
        for key in REQUIRED_TRUE:
            with self.subTest(key=key):
                row = list(good_row()); row[COLUMNS.index(key)] = False
                with self.assertRaisesRegex(RuntimeError, 'preflight failed'):
                    verify_worker_connection(FakeConnection(row))

    def test_rejects_any_excess_privilege(self):
        for key in COLUMNS:
            if key in REQUIRED_TRUE:
                continue
            with self.subTest(key=key):
                row = list(good_row()); row[COLUMNS.index(key)] = True
                with self.assertRaisesRegex(RuntimeError, 'preflight failed'):
                    verify_worker_connection(FakeConnection(row))

    def test_rejects_unknown_and_malformed_results(self):
        for row in (None, (), (True,), good_row()[:-1],
                    tuple(None if k == 'rls_active' else k in REQUIRED_TRUE for k in COLUMNS)):
            with self.subTest(row=row):
                with self.assertRaisesRegex(RuntimeError, 'preflight failed'):
                    verify_worker_connection(FakeConnection(row))

    def test_bad_capability_blocks_ingestion_before_storage(self):
        # This exercises the actual ingest CLI wiring in the repository CI.
        from ingest import main
        db = FakeConnection(good_row())
        fake_driver = SimpleNamespace(connect=lambda dsn: nullcontext(db))
        with patch.dict(sys.modules, {'psycopg': fake_driver}), patch.dict(
            os.environ, {'MNEMOSYNE_SERVICE_KEY': 'fixture', 'MNEMOSYNE_DB_DSN': 'fixture'}
        ), patch('ingest.verify_worker_connection', side_effect=RuntimeError('preflight failed')) as guard, patch(
            'ingest.ingest'
        ) as upload:
            with self.assertRaisesRegex(RuntimeError, 'preflight failed'):
                main(['synthetic.txt', '--execute'])
            guard.assert_called_once_with(db)
            upload.assert_not_called()

    def test_query_uses_postgresql_privilege_checks(self):
        self.assertIn('row_security_active(', CHECK_SQL)
        self.assertIn('pg_has_role(', CHECK_SQL)
        self.assertIn('mnemosyne_worker', CHECK_SQL)
        self.assertNotIn('password', CHECK_SQL.lower())
        self.assertNotIn('INSERT INTO', CHECK_SQL.upper())
        self.assertNotIn('DELETE FROM', CHECK_SQL.upper())


if __name__ == '__main__':
    unittest.main()
