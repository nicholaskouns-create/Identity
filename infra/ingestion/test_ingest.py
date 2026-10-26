"""Localhost HTTP integration and failure tests; no external credentials."""
import hashlib
import json
import tempfile
import threading
import unittest
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest.mock import patch

from ingest import IntegrityError, ingest, main, receipt, register_metadata, upload_and_verify


class FakeDatabase:
    def __init__(self):
        self.rows = {}
        self.inserts = 0
        self.lookups = 0
        self.fail = False
    @contextmanager
    def transaction(self):
        yield self
    @contextmanager
    def cursor(self):
        yield self
    def execute(self, query, params):
        if self.fail:
            raise RuntimeError("DB unavailable")
        if "INSERT INTO" in query:
            self.inserts += 1
            name, digest, key, evidence, meta = params
            assert evidence == "historical_source"
            assert json.loads(meta)["size"] >= 1
            if key in self.rows:
                self.result = None
            else:
                self.rows[key] = ("test-document-id", digest)
                self.result = self.rows[key]
        else:
            self.lookups += 1
            self.result = self.rows.get(params[0])
    def fetchone(self):
        return self.result


@contextmanager
def storage_server(*, corrupt=False, unauthorized=False):
    state = {"objects": {}, "posts": 0, "gets": 0,
             "corrupt": corrupt, "unauthorized": unauthorized}
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass
        def authorized(self):
            if state["unauthorized"] or self.headers.get("Authorization") != "Bearer test-secret":
                self.send_response(401); self.end_headers(); return False
            return True
        def do_POST(self):
            if not self.authorized(): return
            state["posts"] += 1
            key = self.path
            if key in state["objects"]:
                self.send_response(409); self.end_headers(); return
            data = self.rfile.read(int(self.headers["Content-Length"]))
            state["objects"][key] = data
            self.send_response(201); self.end_headers()
        def do_GET(self):
            if not self.authorized(): return
            state["gets"] += 1
            data = state["objects"].get(self.path)
            if data is None:
                self.send_response(404); self.end_headers(); return
            if state["corrupt"]:
                data = b"corrupted"
            self.send_response(200); self.end_headers(); self.wfile.write(data)
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield "http://127.0.0.1:%d" % server.server_port, state
    finally:
        server.shutdown(); server.server_close(); thread.join(timeout=2)


class IngestionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.file = Path(self.tmp.name) / "history.txt"
        self.file.write_bytes(b"Mnemosyne archival test")

    def test_sha256_receipt(self):
        r, payload = receipt(self.file)
        self.assertEqual(r["sha256"], hashlib.sha256(payload).hexdigest())
        self.assertEqual(r["size"], len(payload))
        self.assertEqual(r["key"], f"sha256/{r['sha256'][:2]}/{r['sha256']}")

    def test_missing_file(self):
        with self.assertRaises(ValueError): receipt(self.file.with_name("missing.txt"))

    def test_empty_file(self):
        self.file.write_bytes(b"")
        with self.assertRaises(ValueError): receipt(self.file)

    def test_symlink_rejected(self):
        link = Path(self.tmp.name) / "link.txt"
        link.symlink_to(self.file)
        with self.assertRaises(ValueError): receipt(link)

    def test_unsupported_mime(self):
        p = Path(self.tmp.name) / "archive.exe"
        p.write_bytes(b"not an executable")
        with self.assertRaises(ValueError): receipt(p)

    def test_size_limit(self):
        with patch("ingest.MAX_BYTES", 5):
            with self.assertRaises(ValueError): receipt(self.file)

    def test_localhost_storage_roundtrip_then_registration(self):
        db = FakeDatabase()
        with storage_server() as (url, state):
            result = ingest(self.file, token="test-secret", connection=db, base_url=url)
            self.assertEqual(result["storage"], "uploaded_verified")
            self.assertEqual(result["registration"], "registered")
            self.assertEqual((state["posts"], state["gets"], db.inserts), (1, 1, 1))
            self.assertEqual(len(state["objects"]), 1)

    def test_idempotent_duplicate_after_verified_readback(self):
        db = FakeDatabase()
        with storage_server() as (url, state):
            ingest(self.file, token="test-secret", connection=db, base_url=url)
            result = ingest(self.file, token="test-secret", connection=db, base_url=url)
            self.assertEqual(result["storage"], "existing_verified")
            self.assertEqual(result["registration"], "existing_verified")
            self.assertEqual((state["posts"], state["gets"], db.lookups), (2, 2, 1))

    def test_corrupt_readback_prevents_registration(self):
        db = FakeDatabase()
        with storage_server(corrupt=True) as (url, state):
            with self.assertRaises(IntegrityError):
                ingest(self.file, token="test-secret", connection=db, base_url=url)
            self.assertEqual(db.inserts, 0)
            self.assertEqual(len(state["objects"]), 1)  # orphan not silently deleted

    def test_unauthorized_storage_prevents_registration(self):
        db = FakeDatabase()
        with storage_server(unauthorized=True) as (url, state):
            with self.assertRaises(Exception):
                ingest(self.file, token="test-secret", connection=db, base_url=url)
            self.assertEqual(db.inserts, 0)
            self.assertEqual(state["objects"], {})

    def test_conflicting_db_digest_rejected(self):
        db = FakeDatabase()
        r, _ = receipt(self.file)
        db.rows[r["key"]] = ("existing-id", "0" * 64)
        with self.assertRaises(IntegrityError): register_metadata(r, db)

    def test_db_failure_leaves_verified_object_for_reconciliation(self):
        db = FakeDatabase(); db.fail = True
        with storage_server() as (url, state):
            with self.assertRaises(RuntimeError):
                ingest(self.file, token="test-secret", connection=db, base_url=url)
            self.assertEqual(len(state["objects"]), 1)

    def test_changed_payload_rejected_before_http(self):
        r, data = receipt(self.file)
        with storage_server() as (url, state):
            with self.assertRaises(IntegrityError):
                upload_and_verify(r, data + b"tamper", "test-secret", base_url=url)
            self.assertEqual(state["posts"], 0)

    def test_offline_mode_requires_no_credentials(self):
        with patch("builtins.print") as output:
            main([str(self.file)])
        self.assertIn("offline_receipt", output.call_args.args[0])

    def test_execute_requires_both_external_credentials(self):
        with patch.dict("os.environ", {}, clear=True):
            with self.assertRaises(RuntimeError): main([str(self.file), "--execute"])


if __name__ == "__main__":
    unittest.main()
