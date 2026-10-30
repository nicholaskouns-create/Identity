"""No credentials, database connection or private content required."""
import importlib.util
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).parent
SCRIPT = HERE / 'mnemosyne_monorail_posture.py'
spec = importlib.util.spec_from_file_location('posture', SCRIPT)
posture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(posture)


def fixture():
    return dict(schema_version=1, bucket_present=True, bucket_private=True,
                bucket_size_limit=52428800, source_rows=0, private_objects=0,
                worker_present=True, worker_no_login=True, worker_no_bypassrls=True,
                source_rls_enabled=True, anon_schema_denied=True,
                authenticated_schema_denied=True, worker_select=True,
                worker_insert=True, worker_update_denied=True,
                worker_delete_denied=True, worker_select_policy=True,
                worker_insert_policy=True, restricted_runtime_login_present=False,
                monorail_receipts_present=False, monorail_checkpoints_present=False,
                monorail_receipt_trigger_count=0)


class PostureTests(unittest.TestCase):
    def test_expected_live_shape_blocked_not_pass(self):
        r = posture.evaluate(fixture())
        self.assertEqual(r['status'], 'BLOCKED')
        self.assertIn('threat20_trigger_bypass_not_testable_without_receipt_table', r['unverified_milestones'])

    def test_public_bucket_is_failure(self):
        d = fixture(); d['bucket_private'] = False
        self.assertEqual(posture.evaluate(d)['security_regressions'], ['bucket_private'])

    def test_bypassrls_is_failure(self):
        d = fixture(); d['worker_no_bypassrls'] = False
        self.assertEqual(posture.evaluate(d)['status'], 'FAIL')

    def test_missing_policy_is_failure(self):
        d = fixture(); d['worker_insert_policy'] = False
        self.assertIn('worker_insert_policy', posture.evaluate(d)['security_regressions'])

    def test_anon_schema_grant_is_failure(self):
        d = fixture(); d['anon_schema_denied'] = False
        self.assertEqual(posture.evaluate(d)['status'], 'FAIL')

    def test_existing_receipts_do_not_clear_threat20(self):
        d = fixture(); d['monorail_receipts_present'] = True
        r = posture.evaluate(d)
        self.assertIn('threat20_privileged_trigger_bypass_not_independently_verified', r['unverified_milestones'])

    def test_missing_field_rejected(self):
        d = fixture(); del d['worker_insert']
        with self.assertRaises(ValueError): posture.evaluate(d)

    def test_string_true_rejected(self):
        d = fixture(); d['bucket_private'] = 'true'
        with self.assertRaises(ValueError): posture.evaluate(d)

    def test_negative_count_rejected(self):
        d = fixture(); d['private_objects'] = -1
        with self.assertRaises(ValueError): posture.evaluate(d)

    def test_cli_exit_code_blocked(self):
        with tempfile.TemporaryDirectory() as temp:
            p = pathlib.Path(temp) / 'snapshot.json'
            p.write_text(json.dumps({'posture': fixture()}), encoding='utf-8')
            r = subprocess.run([sys.executable, str(SCRIPT), str(p)], capture_output=True, text=True)
            self.assertEqual(r.returncode, 2, r.stderr)
            self.assertEqual(json.loads(r.stdout)['status'], 'BLOCKED')

    def test_cli_invalid_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            p = pathlib.Path(temp) / 'snapshot.json'; p.write_text('{}', encoding='utf-8')
            r = subprocess.run([sys.executable, str(SCRIPT), str(p)], capture_output=True, text=True)
            self.assertEqual(r.returncode, 1)
            self.assertEqual(json.loads(r.stdout)['status'], 'INVALID')

    def test_sql_contract_is_read_only(self):
        sql = (HERE / 'mnemosyne_monorail_posture.sql').read_text(encoding='utf-8')
        self.assertIn('pg_auth_members', sql)
        self.assertIn('pg_policies', sql)
        self.assertIn('monorail_receipts', sql)
        self.assertIn('mnemosyne-private', sql)
        import re
        scrub = re.sub(r'--[^\n]*', '', sql)
        self.assertNotRegex(scrub.upper(), r'\b(INSERT|UPDATE|DELETE|ALTER|CREATE|DROP|TRUNCATE|GRANT|REVOKE|COPY)\s+(INTO|TABLE|SCHEMA|ROLE|POLICY|ON|FROM|DATABASE)\b')


if __name__ == '__main__': unittest.main()
