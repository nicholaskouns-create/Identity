"""Offline regression tests for the bounded Monorail public-door probe."""
from __future__ import annotations

import sys
import unittest
import json
from copy import deepcopy
from tempfile import TemporaryDirectory
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError, URLError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import probe_public_doors as probe


class FakeResponse:
    status = 200

    def __init__(self, url):
        self.url = url

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def geturl(self):
        return self.url

    def read(self, size):
        assert size == 1
        return b"x"



class FakeSourceResponse:
    status = 200

    def __init__(self, payload):
        self.payload = payload

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def read(self):
        return self.payload


class PublicDoorProbeTests(unittest.TestCase):
    def setUp(self):
        self.data = probe.read_corpus()

    def test_source_census_preserved(self):
        self.assertEqual(len(self.data["stations"]), 17)
        self.assertEqual(sum(len(s["links"]) for s in self.data["stations"]), 54)
        self.assertEqual([(r["id"], r["status"]) for r in self.data["repairs"]],
                         [("highlight", "404"), ("paper", "404"),
                          ("mirror", "401"), ("modsync", "401")])

    def test_station_url_swap_rejected_before_network(self):
        # Before R33, exchanging two 200-returning station URLs preserved
        # the 17-count and public host check, silently changing identities.
        data = deepcopy(self.data)
        stations = {s["slug"]: s for s in data["stations"]}
        stations["matrix"]["href"], stations["neutrino"]["href"] = (
            stations["neutrino"]["href"], stations["matrix"]["href"]
        )
        self.assertEqual(len(stations), 17)
        self.assertTrue(all(s["href"].startswith(
            "https://nicholaskouns-create.github.io/"
        ) for s in data["stations"]))
        with TemporaryDirectory() as directory:
            original = probe.CORPUS.read_text(encoding="utf-8")
            marker = '<script id="data" type="application/json">'
            prefix, rest = original.split(marker, 1)
            _, suffix = rest.split("</script>", 1)
            mutated = (prefix + marker + json.dumps(data, separators=(",", ":"))
                       + "</script>" + suffix)
            path = Path(directory) / "index.html"
            path.write_text(mutated, encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Door URL identity changed"):
                probe.read_corpus(path)

    def test_station_query_and_fragment_identity_pinned(self):
        # The Observatory query and Tower SPA fragment are part of their
        # source identity; losing either must not pass a 17-door census.
        for slug, replacement in (
            ("observatory", "https://nicholaskouns-create.github.io/E47-Kartekeya/interfaces/observatory/"),
            ("tower", "https://nicholaskouns-create.github.io/tower/"),
        ):
            with self.subTest(slug=slug):
                data = deepcopy(self.data)
                next(s for s in data["stations"] if s["slug"] == slug)["href"] = replacement
                with TemporaryDirectory() as directory:
                    original = probe.CORPUS.read_text(encoding="utf-8")
                    marker = '<script id="data" type="application/json">'
                    prefix, rest = original.split(marker, 1)
                    _, suffix = rest.split("</script>", 1)
                    path = Path(directory) / "index.html"
                    path.write_text(prefix + marker + json.dumps(data, separators=(",", ":"))
                                    + "</script>" + suffix, encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, "Door URL identity changed"):
                        probe.read_corpus(path)

    def test_restricted_originals_are_not_door_requests(self):
        doors = {s["href"] for s in self.data["stations"]}
        restricted = {l["href"] for s in self.data["stations"]
                      for l in s["links"] if l.get("state") == "restricted"}
        self.assertEqual(len(restricted), 2)
        self.assertFalse(doors & restricted)

    def test_success_is_http_evidence_not_browser_certification(self):
        station = self.data["stations"][0]
        with patch.object(probe, "safe_door_open", side_effect=lambda req, timeout: FakeResponse(req.full_url)):
            result = probe.probe_door(station)
        self.assertEqual(result["http_status"], 200)
        self.assertEqual(result["outcome"], "http_ok")

    def test_http_404_remains_distinct_from_network_error(self):
        station = self.data["stations"][0]
        with patch.object(probe, "safe_door_open", side_effect=HTTPError(station["href"], 404, "Not Found", {}, None)):
            result = probe.probe_door(station)
        self.assertEqual(result["http_status"], 404)
        self.assertEqual(result["outcome"], "http_error")

    def test_transport_error_is_unverified_not_404(self):
        station = self.data["stations"][0]
        with patch.object(probe, "safe_door_open", side_effect=URLError("DNS unavailable")):
            result = probe.probe_door(station)
        self.assertIsNone(result["http_status"])
        self.assertEqual(result["outcome"], "network_error")

    def test_public_monorail_bytes_match_checkout(self):
        payload = probe.CORPUS.read_bytes()
        with patch.object(probe, "safe_door_open", return_value=FakeSourceResponse(payload)):
            result = probe.probe_monorail_source()
        self.assertEqual(result["http_status"], 200)
        self.assertTrue(result["matches_source"])
        self.assertEqual(result["outcome"], "http_ok")

    def test_public_monorail_source_mismatch_is_not_success(self):
        with patch.object(probe, "safe_door_open", return_value=FakeSourceResponse(b"stale deployment")):
            result = probe.probe_monorail_source()
        self.assertEqual(result["http_status"], 200)
        self.assertFalse(result["matches_source"])
        self.assertEqual(result["outcome"], "source_mismatch")

    def test_full_audit_preserves_historical_failures(self):
        with patch.object(probe, "probe_monorail_source", return_value={"outcome": "http_ok", "matches_source": True}), \
             patch.object(probe, "probe_door", side_effect=lambda s: {
            "slug": s["slug"], "title": s["name"], "url": s["href"],
            "http_status": 200, "final_url": s["href"], "outcome": "http_ok"}):
            result = probe.audit(self.data)
        self.assertTrue(result["monorail_entry"]["matches_source"])
        self.assertEqual(result["http_ok"], 17)
        self.assertEqual(result["source_exit_count"], 54)
        self.assertEqual(result["historical_census"]["links_followed"], 177)
        self.assertEqual(result["historical_census"]["failures"], 4)
        self.assertEqual(len(result["restricted_originals_not_requested"]), 2)
        self.assertIn("not a browser render", result["claim_boundary"])

    def test_pr_source_mismatch_is_recorded_but_does_not_mask_http_failures(self):
        result = {"monorail_entry": {"outcome": "source_mismatch"},
                  "http_error": 0, "network_error": 0}
        self.assertEqual(probe.exit_status(result), 1)
        self.assertEqual(probe.exit_status(result, allow_undeployed_source=True), 0)
        result["http_error"] = 1
        self.assertEqual(probe.exit_status(result, allow_undeployed_source=True), 1)
        result["http_error"] = 0
        result["network_error"] = 1
        self.assertEqual(probe.exit_status(result, allow_undeployed_source=True), 2)
        result["network_error"] = 0
        result["monorail_entry"]["outcome"] = "http_error"
        self.assertEqual(probe.exit_status(result, allow_undeployed_source=True), 1)


    def test_redirected_door_identity_is_blocked_before_followup(self):
        # Real loopback 302: the old urllib opener followed /door to /wrong
        # and reported 200. The corrected probe rejects the destination.
        from http.server import BaseHTTPRequestHandler, HTTPServer
        from threading import Thread

        class Redirects(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == "/door":
                    target = "/wrong-application"
                elif self.path == "/private":
                    target = ("https://docs.google.com/document/d/"
                              "1wCmn5J4Tjo0qVV5AOoHUxD1tXComhPf7lU1ntzKtaMs/edit"
                              "?token=never-log")
                elif self.path == "/source":
                    target = "/other"
                elif self.path == "/same":
                    target = "/same/?view=learn"
                else:
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"ok")
                    return
                self.send_response(302)
                self.send_header("Location", target)
                self.end_headers()

            def log_message(self, *_):
                pass

        server = HTTPServer(("127.0.0.1", 0), Redirects)
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = f"http://127.0.0.1:{server.server_port}"
        try:
            for path in ("/door", "/private"):
                with self.subTest(path=path):
                    station = {"slug": "test", "name": "Test",
                               "href": base + path}
                    result = probe.probe_door(station, timeout=3)
                    self.assertEqual(result["http_status"], 302)
                    self.assertEqual(result["outcome"],
                                     "door_identity_redirect_blocked")
                    self.assertNotIn("token=", str(result))
            # A same-door trailing-slash/query redirect remains navigable.
            same = probe.probe_door({"slug": "test", "name": "Test",
                                    "href": base + "/same"}, timeout=3)
            self.assertEqual((same["http_status"], same["outcome"]),
                             (200, "http_ok"))
            with patch.object(probe, "SOURCE_URL", base + "/source"):
                source = probe.probe_monorail_source(timeout=3)
            self.assertEqual((source["http_status"], source["outcome"]),
                             (302, "door_identity_redirect_blocked"))
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)

    def test_blocked_door_counts_as_failure_even_with_16_http_200(self):
        def simulated(station):
            blocked = station["slug"] == "tower"
            return {"slug": station["slug"], "title": station["name"],
                    "url": station["href"], "http_status": 302 if blocked else 200,
                    "final_url": station["href"],
                    "outcome": ("door_identity_redirect_blocked" if blocked
                                else "http_ok")}
        with patch.object(probe, "probe_door", side_effect=simulated), \
             patch.object(probe, "probe_monorail_source",
                          return_value={"outcome": "http_ok"}):
            receipt = probe.audit(self.data, workers=1)
        self.assertEqual((receipt["http_ok"], receipt["http_error"]), (16, 1))
        self.assertEqual(receipt["door_identity_redirect_blocked"], 1)
        self.assertEqual(probe.exit_status(receipt), 1)
        self.assertEqual(receipt["historical_census"]["failures"], 4)


if __name__ == "__main__":
    unittest.main()
