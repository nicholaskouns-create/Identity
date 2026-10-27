"""Offline tests for private search. No credentials or production content."""
import datetime as dt
import unittest
from contextlib import contextmanager
from unittest.mock import patch

from search import SEARCH_SQL, main, search_documents


class FakeConnection:
    def __init__(self, rows=()):
        self.rows = list(rows)
        self.calls = []
        self.transactions = 0
    @contextmanager
    def transaction(self):
        self.transactions += 1
        yield self
    @contextmanager
    def cursor(self):
        yield self
    def execute(self, sql, params=None):
        self.calls.append((sql, params))
    def fetchall(self):
        return self.rows


class SearchTests(unittest.TestCase):
    def test_parameterized_search_and_private_projection(self):
        stamp = dt.datetime(2026, 10, 27, tzinfo=dt.timezone.utc)
        db = FakeConnection([('uuid-1', 'Research memo', 'a'*64, 'historical_source', stamp)])
        result = search_documents(db, 'memo')
        self.assertEqual(result, [{'id': 'uuid-1', 'title': 'Research memo',
            'source_sha256': 'a'*64, 'evidence_class': 'historical_source',
            'recorded_at': '2026-10-27T00:00:00+00:00'}])
        self.assertEqual(db.calls[0][0], 'SET TRANSACTION READ ONLY')
        self.assertIn('statement_timeout', db.calls[1][0])
        self.assertEqual(db.calls[2][0], SEARCH_SQL)
        self.assertEqual(db.calls[2][1], ('%memo%', '%memo%', None, 20))
        self.assertNotIn('storage_path', SEARCH_SQL)
        self.assertNotIn('metadata,', SEARCH_SQL)
        self.assertEqual(db.transactions, 1)

    def test_like_wildcards_are_literal(self):
        db = FakeConnection()
        search_documents(db, r'50%!_')
        self.assertEqual(db.calls[2][1], ('%50!%!!!_%', '%50!%!!!_%', None, 20))

    def test_injection_stays_in_parameter(self):
        db = FakeConnection()
        payload = "x' OR true --"
        search_documents(db, payload)
        self.assertNotIn(payload, SEARCH_SQL)
        self.assertEqual(db.calls[2][1][0], '%' + payload + '%')

    def test_sha256_case_normalization(self):
        db = FakeConnection()
        search_documents(db, 'AB'*32)
        self.assertEqual(db.calls[2][1][2], 'ab'*32)

    def test_unicode_and_trim(self):
        db = FakeConnection()
        search_documents(db, '  νεῦρον  ', limit=1)
        self.assertEqual(db.calls[2][1], ('%νεῦρον%', '%νεῦρον%', None, 1))

    def test_empty_results(self):
        self.assertEqual(search_documents(FakeConnection(), 'missing'), [])

    def test_invalid_queries_do_not_touch_database(self):
        for q in ['', '  ', 'a'*161, 'bad\nquery', 'bad\x00query', None, 7]:
            with self.subTest(q=q):
                db = FakeConnection()
                with self.assertRaises(ValueError):
                    search_documents(db, q)
                self.assertEqual(db.calls, [])

    def test_invalid_limits_do_not_touch_database(self):
        for limit in [0, 101, -1, 1.5, True, '10']:
            with self.subTest(limit=limit):
                db = FakeConnection()
                with self.assertRaises(ValueError):
                    search_documents(db, 'ok', limit=limit)
                self.assertEqual(db.calls, [])

    def test_missing_dsn_fails_closed(self):
        with patch.dict('os.environ', {}, clear=True):
            with self.assertRaisesRegex(RuntimeError, 'MNEMOSYNE_DB_DSN'):
                main(['query'])

    def test_sql_is_read_only_and_bounded(self):
        self.assertIn('FROM mnemosyne_private.source_documents', SEARCH_SQL)
        self.assertIn('LIMIT %s', SEARCH_SQL)
        self.assertNotIn('INSERT', SEARCH_SQL.upper())
        self.assertNotIn('DELETE', SEARCH_SQL.upper())
        self.assertNotIn('UPDATE', SEARCH_SQL.upper())


if __name__ == '__main__':
    unittest.main()
