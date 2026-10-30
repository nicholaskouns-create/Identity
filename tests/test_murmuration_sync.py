import hashlib
import json
import unittest
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from murmuration_sync import build

class FeedTests(unittest.TestCase):
    def test_sources_and_digest(self):
        def fake(repo):
            return {"id": repo, "status": "ok", "commit_sha": "a" * 40}
        obj = build(fake, "2026-10-30T00:00:00Z")
        digest = obj.pop("sha256")
        canonical = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
        self.assertEqual(digest, hashlib.sha256(canonical).hexdigest())
        self.assertEqual(len(obj["sources"]), 2)

    def test_failures_are_not_fabricated(self):
        def fail(repo):
            raise ValueError("unavailable")
        obj = build(fail, "2026-10-30T00:00:00Z")
        self.assertTrue(all(s["status"] == "unavailable" for s in obj["sources"]))
        self.assertTrue(all("commit_sha" not in s for s in obj["sources"]))

if __name__ == "__main__":
    unittest.main()
