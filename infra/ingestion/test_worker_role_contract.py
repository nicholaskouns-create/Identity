"""Secret-free static regression tests for the reviewed worker-role migration."""
from pathlib import Path
import re
import unittest

SQL = Path(__file__).with_name("mnemosyne_worker_role.sql").read_text(encoding="utf-8")
NORMAL = " ".join(SQL.split())


class WorkerRoleContractTests(unittest.TestCase):
    def test_no_login_and_no_rls_bypass(self):
        self.assertRegex(NORMAL, r"CREATE ROLE mnemosyne_worker\s+NOLOGIN")
        self.assertIn("NOINHERIT", NORMAL)
        self.assertIn("NOBYPASSRLS", NORMAL)
        self.assertNotRegex(SQL, r"(?im)^\s*ALTER ROLE\b")

    def test_only_private_source_table_grants(self):
        self.assertRegex(NORMAL, r"GRANT USAGE ON SCHEMA mnemosyne_private TO mnemosyne_worker")
        self.assertRegex(NORMAL, r"GRANT SELECT, INSERT ON TABLE mnemosyne_private.source_documents TO mnemosyne_worker")
        self.assertNotRegex(SQL, r"(?im)^\s*GRANT\b[^;]*\bTO\s+(?:PUBLIC|anon|authenticated)\b")
        self.assertNotRegex(SQL, r"(?im)^\s*GRANT\b[^;]*\b(?:UPDATE|DELETE|TRUNCATE|ALL)\b")

    def test_policies_are_role_scoped(self):
        self.assertEqual(len(re.findall(r"(?im)^\s*CREATE POLICY\b", SQL)), 2)
        self.assertIn("FOR SELECT TO mnemosyne_worker USING (true)", NORMAL)
        self.assertIn("FOR INSERT TO mnemosyne_worker", NORMAL)
        self.assertIn("WITH CHECK", NORMAL)

    def test_insert_enforces_content_address(self):
        self.assertIn("evidence_class = 'historical_source'", NORMAL)
        self.assertIn("source_sha256 ~ '^[0-9a-f]{64}$'", NORMAL)
        self.assertIn("storage_path = ('sha256/' || left(source_sha256, 2) || '/' || source_sha256)", NORMAL)

    def test_no_secret_or_unrelated_mutation(self):
        self.assertEqual(len(re.findall(r"(?im)^\s*CREATE ROLE\b", SQL)), 1)
        self.assertNotRegex(SQL, r"(?im)^\s*(?:DROP|DELETE|UPDATE|TRUNCATE|ALTER TABLE)\b")
        self.assertNotRegex(SQL, r"(?im)^\s*(?:CREATE USER|CREATE EXTENSION)\b")


if __name__ == "__main__":
    unittest.main()
