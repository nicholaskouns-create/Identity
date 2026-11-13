"""Synthetic-only tests; no production passports or private data."""
import json
import unittest

try:
    from monorail import passport as producer
except ImportError:
    producer = None

from monorail.independent_receipt_audit import AuditError, audit, parse_receipts, receipt_digest


def seal(parent="0" * 64, **extra):
    p = {"schema_version": "monorail.passport.v1", "parent_receipt_hash": parent,
         "object_id": "synthetic", "verification_status": "PASS", "evidence_class": "E1",
         "assumptions": ["synthetic"], "timestamp_utc": "2026-11-01T00:00:00Z"}
    p.update(extra)
    p["receipt_hash"] = receipt_digest(p)
    return p


class IndependentAuditTests(unittest.TestCase):
    def test_one_receipt(self):
        self.assertEqual(audit([seal()])["verified_receipts"], 1)

    def test_chain_two(self):
        a = seal()
        b = seal(parent=a["receipt_hash"], object_id="synthetic-2")
        self.assertEqual(audit([a, b])["head_sha256"], b["receipt_hash"])

    def test_tamper_rejected(self):
        p = seal()
        p["object_id"] = "tampered"
        with self.assertRaisesRegex(AuditError, "digest mismatch"):
            audit([p])

    def test_parent_mismatch_rejected(self):
        p = seal(parent="f" * 64)
        with self.assertRaisesRegex(AuditError, "chain link mismatch"):
            audit([p])

    def test_duplicate_receipt_rejected(self):
        p = seal()
        with self.assertRaises(AuditError):
            audit([p, p])

    def test_schema_mismatch_rejected(self):
        with self.assertRaisesRegex(AuditError, "schema version"):
            audit([seal(schema_version="monorail.passport.v2")])

    def test_empty_bundle_rejected(self):
        with self.assertRaises(AuditError):
            parse_receipts(b"[]")

    def test_duplicate_json_keys_rejected(self):
        with self.assertRaisesRegex(AuditError, "duplicate"):
            parse_receipts(b'[{"a":1,"a":2}]')

    def test_float_rejected(self):
        with self.assertRaisesRegex(AuditError, "floating"):
            parse_receipts(b'[{"a":1.0}]')

    def test_nonfinite_rejected(self):
        with self.assertRaisesRegex(AuditError, "floating"):
            parse_receipts(b'[{"a":NaN}]')

    def test_nonportable_string_rejected(self):
        with self.assertRaisesRegex(AuditError, "nonportable"):
            receipt_digest({"field": "\x00"})

    def test_unicode_roundtrip(self):
        p = seal(object_id="Σ→Γ·量子")
        self.assertEqual(audit(parse_receipts(json.dumps([p], ensure_ascii=False).encode()))["status"], "PASS")

    def test_nested_integer_range(self):
        with self.assertRaisesRegex(AuditError, "integer"):
            receipt_digest({"nested": [2**63]})

    def test_too_large_bundle(self):
        with self.assertRaisesRegex(AuditError, "8 MiB"):
            parse_receipts(b" " * (8*1024*1024+1))

    @unittest.skipUnless(producer is not None, "original passport module unavailable locally")
    def test_existing_producer_cross_check(self):
        p = producer.make_passport(object_id="synthetic", theorem_id="TEST",
            source_commit="a" * 40, source_hash="b" * 64,
            parent_receipt_hash="0" * 64, proof_system="Lean",
            compiler_version="synthetic", environment_lock_hash="c" * 64,
            assumptions=["synthetic"], verification_status="PASS", evidence_class="E0",
            artifact_hashes=["d" * 64], timestamp_utc="2026-11-01T00:00:00Z")
        self.assertEqual(receipt_digest(p), p["receipt_hash"])
        self.assertEqual(audit([p])["verified_receipts"], 1)


if __name__ == "__main__":
    unittest.main()
