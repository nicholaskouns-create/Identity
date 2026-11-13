"""Offline audit contract tests; no production credentials or database writes."""
import unittest
from evaluate_snapshot import EXPECTED, SCHEMA, evaluate


def sample():
    return {
        "schema": SCHEMA,
        "mnemosyne": {**EXPECTED, "source_documents": 0, "private_objects": 0},
        "monorail": {"receipts_table_exists": False, "canonical_sql_exists": False,
                     "receipt_triggers": 0, "privileged_receipt_triggers": 0,
                     "independent_validator_status": "not_assessed"},
    }


class SnapshotTests(unittest.TestCase):
    def test_baseline_pass_but_not_end_to_end(self):
        result = evaluate(sample())
        self.assertEqual(result["security_baseline"], "PASS")
        self.assertEqual(result["ingestion_end_to_end"], "UNVERIFIED")
        self.assertEqual(result["monorail_receipt_ledger"], "NOT_DEPLOYED")
        self.assertEqual(result["threat20_privileged_trigger_bypass"], "NOT_ASSESSED")

    def test_public_grant_fails(self):
        snapshot = sample(); snapshot["mnemosyne"]["public_table_grants"] = 1
        self.assertEqual(evaluate(snapshot)["security_baseline"], "FAIL")

    def test_worker_login_fails(self):
        snapshot = sample(); snapshot["mnemosyne"]["worker_nologin"] = False
        self.assertEqual(evaluate(snapshot)["checks"]["worker_nologin"], "FAIL")

    def test_missing_field_fails_closed(self):
        snapshot = sample(); del snapshot["mnemosyne"]["source_rls"]
        self.assertEqual(evaluate(snapshot)["security_baseline"], "FAIL")

    def test_boolean_is_not_integer_count(self):
        snapshot = sample(); snapshot["mnemosyne"]["source_documents"] = False
        with self.assertRaises(ValueError): evaluate(snapshot)

    def test_bad_schema_rejected(self):
        snapshot = sample(); snapshot["schema"] = "different"
        with self.assertRaises(ValueError): evaluate(snapshot)

    def test_receipt_table_present_is_not_verified(self):
        snapshot = sample(); snapshot["monorail"]["receipts_table_exists"] = True
        self.assertEqual(evaluate(snapshot)["monorail_receipt_ledger"], "PRESENT_NOT_VALIDATED")
        self.assertEqual(evaluate(snapshot)["independent_receipt_validator"], "NOT_ASSESSED")

    def test_positive_counts_do_not_claim_hosted_success(self):
        snapshot = sample(); snapshot["mnemosyne"]["source_documents"] = 2
        snapshot["mnemosyne"]["private_objects"] = 2
        self.assertEqual(evaluate(snapshot)["hosted_storage_roundtrip"], "UNVERIFIED")

    def test_unexpected_worker_grants_fail(self):
        snapshot = sample(); snapshot["mnemosyne"]["worker_unexpected_grants"] = 1
        self.assertEqual(evaluate(snapshot)["security_baseline"], "FAIL")

    def test_trigger_count_never_certifies_threat20(self):
        snapshot = sample(); snapshot["monorail"]["receipts_table_exists"] = True
        snapshot["monorail"]["receipt_triggers"] = 2
        snapshot["monorail"]["privileged_receipt_triggers"] = 1
        self.assertEqual(evaluate(snapshot)["threat20_privileged_trigger_bypass"], "NOT_ASSESSED")


if __name__ == "__main__":
    unittest.main()
