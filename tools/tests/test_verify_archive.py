"""Offline archive receipt tests, including a Node JSON.stringify golden vector."""
import contextlib
import hashlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from migrate_archive import canonical, convert
from verify_archive import main, verify_archive, verify_file


class VerifyArchiveTests(unittest.TestCase):
    def setUp(self):
        self.archive = convert({"tables": {"public.test": [{"id": 1, "content": "example"}]}})

    def test_migrated_archive(self):
        self.assertEqual(verify_archive(self.archive), 1)

    def test_javascript_canonical_golden_vector(self):
        # SHA-256 computed with Node 22 JSON.stringify + crypto.createHash,
        # independently of the Python canonical implementation.
        row = {
            "id": "unicode-α", "title": "E47 🧪 / test",
            "kind": "numerically_tested",
            "content": 'line 1\nline 2: "quotes" / π\tend',
            "created_at": "2026-10-25T00:00:00Z",
            "sha256": "2c9407a85c65b52779552f85d98c39d33d2fed72ddaf4c0052f8a800ac79b489",
        }
        self.assertEqual(hashlib.sha256(canonical(row).encode("utf-8")).hexdigest(), row["sha256"])
        self.assertEqual(verify_archive({"format": "mnemosyne-archive-v1", "records": [row]}), 1)

    def test_tampered_content_rejected(self):
        self.archive["records"][0]["content"] = "changed"
        with self.assertRaisesRegex(ValueError, "SHA-256 receipt mismatch"):
            verify_archive(self.archive)

    def test_duplicate_ids_rejected(self):
        self.archive["records"].append(dict(self.archive["records"][0]))
        with self.assertRaisesRegex(ValueError, "duplicate ID"):
            verify_archive(self.archive)

    def test_schema_and_type_rejections(self):
        with self.assertRaisesRegex(ValueError, "Unsupported archive"):
            verify_archive({"format": "unknown", "records": []})
        with self.assertRaisesRegex(ValueError, "invalid receipt fields"):
            verify_archive({"format": "mnemosyne-archive-v1", "records": [{"id": 1}]})
        with self.assertRaisesRegex(ValueError, "array or count"):
            verify_archive({"format": "mnemosyne-archive-v1", "records": {}})

    def test_cli_is_read_only_and_does_not_print_content(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "private.json"
            self.archive["records"][0]["content"] = "private-secret-string"
            self.archive["records"][0]["sha256"] = hashlib.sha256(
                canonical(self.archive["records"][0]).encode("utf-8")
            ).hexdigest()
            original = json.dumps(self.archive)
            path.write_text(original, encoding="utf-8")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(main([str(path)]), 0)
            self.assertIn("ARCHIVE_RECEIPTS_PASS: 1", output.getvalue())
            self.assertNotIn("private-secret-string", output.getvalue())
            self.assertEqual(path.read_text(encoding="utf-8"), original)
            self.assertEqual(verify_file(path), 1)

    def test_cli_failure_exit_code(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.json"
            path.write_text("not json", encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(main([str(path)]), 1)


if __name__ == "__main__":
    unittest.main()
