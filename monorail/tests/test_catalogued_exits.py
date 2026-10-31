"""Offline invariants for the independent 54-exit HTTP evidence lane."""
import sys
import unittest
from copy import deepcopy
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError, URLError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import probe_catalogued_exits as probe  # noqa: E402


class CataloguedExitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = probe.read_corpus()

    def test_exact_catalogue_and_explicit_exclusions(self):
        public, excluded = probe.partition_exits(self.data)
        self.assertEqual((len(public), len(excluded)), (51, 3))
        self.assertEqual(
            {r["url"] for r in excluded},
            {
                "https://cdn.jsdelivr.net/npm/highlight.js@11.10.0/lib/highlight.min.js",
                "https://docs.google.com/document/d/1wCmn5J4Tjo0qVV5AOoHUxD1tXComhPf7lU1ntzKtaMs/edit",
                "https://drive.google.com/file/d/1-bCyEuWcN1rtRb1IJF02O8tTe7RbmaEC/view",
            },
        )

    def test_state_label_swap_cannot_expose_private_original(self):
        # Previously the 51/3 count and exclusion reasons still passed when
        # a private original was relabeled live and an unrelated link restricted.
        for repair_id in ("mirror", "modsync"):
            with self.subTest(repair_id=repair_id):
                data = deepcopy(self.data)
                original = next(link for station in data["stations"]
                                for link in station["links"]
                                if link.get("repair") == repair_id)
                original["state"] = "live"
                data["stations"][0]["links"][0]["state"] = "restricted"
                with self.assertRaisesRegex(ValueError, "Excluded original URL"):
                    probe.partition_exits(data)

    def test_repair_ledger_cannot_silently_change_private_url(self):
        data = deepcopy(self.data)
        next(r for r in data["repairs"] if r["id"] == "mirror")["failed"] = (
            "https://docs.google.com/document/d/replaced/edit"
        )
        with self.assertRaisesRegex(ValueError, "Historical repair URL identity"):
            probe.partition_exits(data)

    def test_pinned_tower_paper_is_public_candidate(self):
        public, _ = probe.partition_exits(self.data)
        paper = next(r for r in public if r["station"] == "tower"
                     and "paper pin" in r["label"])
        self.assertIn("/blob/c14e98bd6d701723c887a5ba3a34b8caf902ab55/",
                      paper["url"])

    def test_audit_never_calls_probe_for_restricted_originals(self):
        with patch.object(probe, "probe_exit",
                          side_effect=lambda row: dict(row, outcome="http_ok",
                                                       http_status=200)) as mock:
            receipt = probe.audit(self.data, workers=1)
        self.assertEqual(mock.call_count, 51)
        self.assertEqual(receipt["http_ok"], 51)
        self.assertEqual(receipt["catalogued_exit_count"], 54)
        self.assertEqual(len(receipt["excluded_originals"]), 3)
        self.assertEqual(receipt["historical_census"]["links_followed"], 177)

    def test_http_error_is_preserved(self):
        row = {"station": "test", "label": "sample",
               "url": "https://example.org/missing", "state": "live"}
        error = HTTPError(row["url"], 404, "Not Found", {}, None)
        with patch.object(probe, "safe_urlopen", side_effect=error):
            result = probe.probe_exit(row)
        self.assertEqual((result["http_status"], result["outcome"]),
                         (404, "http_error"))

    def test_transport_error_is_not_http_success(self):
        row = {"station": "test", "label": "sample",
               "url": "https://example.org/unavailable", "state": "live"}
        with patch.object(probe, "safe_urlopen", side_effect=URLError("offline")):
            result = probe.probe_exit(row)
        self.assertIsNone(result["http_status"])
        self.assertEqual(result["outcome"], "network_error")
        self.assertEqual(result["error_type"], "URLError")

    def test_fragment_not_sent_in_http_request(self):
        row = {"station": "tower", "label": "Tower",
               "url": "https://example.org/tower/#/explore", "state": "live"}

        class Response:
            status = 200

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def geturl(self):
                return "https://example.org/tower/"

            def read(self, n):
                self_read = n
                assert self_read == 1
                return b"x"

        with patch.object(probe, "safe_urlopen", return_value=Response()) as opened:
            result = probe.probe_exit(row)
        self.assertEqual(opened.call_args.args[0].full_url,
                         "https://example.org/tower/")
        self.assertEqual(result["outcome"], "http_ok")


    def test_drive_redirect_is_blocked_before_followup_request(self):
        # Reproduce urllib's default 302-follow behavior with a real local
        # HTTP server. The redirect target must never receive a request.
        from http.server import BaseHTTPRequestHandler, HTTPServer
        from threading import Thread

        class Redirect(BaseHTTPRequestHandler):
            target = ""

            def do_GET(self):
                self.send_response(302)
                self.send_header("Location", self.target)
                self.end_headers()

            def log_message(self, *_):
                pass

        server = HTTPServer(("127.0.0.1", 0), Redirect)
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            for original in (
                "https://docs.google.com/document/d/1wCmn5J4Tjo0qVV5AOoHUxD1tXComhPf7lU1ntzKtaMs/edit",
                "https://drive.google.com/file/d/1-bCyEuWcN1rtRb1IJF02O8tTe7RbmaEC/view",
            ):
                with self.subTest(original=original):
                    Redirect.target = original + "?token=not-for-receipt"
                    row = {"station": "test", "label": "public redirect",
                           "url": f"http://127.0.0.1:{server.server_port}/start",
                           "state": "live"}
                    result = probe.probe_exit(row, timeout=3)
                    self.assertEqual(result["http_status"], 302)
                    self.assertEqual(result["outcome"], "restricted_redirect_blocked")
                    self.assertEqual(result["final_url"], original)
                    self.assertNotIn("token=", str(result))
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)

    def test_regular_redirect_remains_reachable(self):
        from http.server import BaseHTTPRequestHandler, HTTPServer
        from threading import Thread

        class Redirect(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == "/start":
                    self.send_response(302)
                    self.send_header("Location", "/ok")
                else:
                    self.send_response(200)
                self.end_headers()
                if self.path == "/ok":
                    self.wfile.write(b"x")

            def log_message(self, *_):
                pass

        server = HTTPServer(("127.0.0.1", 0), Redirect)
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            row = {"station": "test", "label": "public redirect",
                   "url": f"http://127.0.0.1:{server.server_port}/start",
                   "state": "live"}
            result = probe.probe_exit(row, timeout=3)
            self.assertEqual((result["http_status"], result["outcome"]),
                             (200, "http_ok"))
            self.assertTrue(result["final_url"].endswith("/ok"))
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)

    def test_blocked_redirect_counts_as_failure_not_success(self):
        def simulated(row):
            if row["station"] == "home" and row["label"] == "Identity":
                return dict(row, outcome="restricted_redirect_blocked",
                            http_status=302)
            return dict(row, outcome="http_ok", http_status=200)

        with patch.object(probe, "probe_exit", side_effect=simulated):
            receipt = probe.audit(self.data, workers=1)
        self.assertEqual(receipt["http_ok"], 50)
        self.assertEqual(receipt["http_error"], 1)
        self.assertEqual(receipt["restricted_redirect_blocked"], 1)
        self.assertEqual(receipt["historical_census"]["failures"], 4)


if __name__ == "__main__":
    unittest.main()
