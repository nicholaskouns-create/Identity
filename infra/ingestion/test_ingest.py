import hashlib
import tempfile
import unittest
from pathlib import Path
from ingest import receipt

class IngestionTests(unittest.TestCase):
    def test_sha256_receipt(self):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder)/"history.txt"
            p.write_bytes(b"Mnemosyne archival test")
            meta, payload = receipt(p)
            self.assertEqual(meta["sha256"], hashlib.sha256(payload).hexdigest())
            self.assertEqual(meta["size"], len(payload))
            self.assertTrue(meta["key"].startswith("sha256/"))
    def test_missing_file(self):
        with self.assertRaises(ValueError):
            receipt("/nonexistent/mnemosyne.txt")

if __name__ == "__main__":
    unittest.main()
