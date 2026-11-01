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

    def test_historical_repair_classification_and_source_are_pinned(self):
        # Previously read_corpus checked only len(repairs)==4. Exchanging
        # 401/404 labels, or rewriting the original Tower paper URL, passed
        # the door source check and contaminated the historical receipt.
        for variant in ("swapped_status", "paper_source"):
            with self.subTest(variant=variant):
                data = deepcopy(self.data)
                repairs = {r["id"]: r for r in data["repairs"]}
                if variant == "swapped_status":
                    repairs["mirror"]["status"] = "404"
                    repairs["highlight"]["status"] = "401"
                else:
                    repairs["paper"]["failed"] = (
                        "https://raw.githubusercontent.com/nicholaskouns-create/"
                        "E47-Kartekeya/main/incorrect/tower_paper.tex"
                    )
                self.assertEqual(len(data["repairs"]), 4)
                with TemporaryDirectory() as directory:
                    original = probe.CORPUS.read_text(encoding="utf-8")
                    marker = '<script id="data" type="application/json">'
                    prefix, rest = original.split(marker, 1)
                    _, suffix = rest.split("</script>", 1)
                    path = Path(directory) / "index.html"
                    path.write_text(
                        prefix + marker + json.dumps(data, separators=(",", ":"))
                        + "</script>" + suffix, encoding="utf-8"
                    )
                    with patch.object(probe, "probe_door") as request:
                        with self.assertRaisesRegex(
                            ValueError, "Historical repair identity changed"
                        ):
                            probe.read_corpus(path)
                        request.assert_not_called()

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


    def test_only_exact_pinned_door_query_is_retained(self):
        station = next(s for s in self.data["stations"]
                       if s["slug"] == "observatory")
        source = station["href"]
        with patch.object(probe, "safe_door_open",
                          return_value=FakeResponse(source)):
            unchanged = probe.probe_door(station)
        self.assertEqual(unchanged["final_url"], source)

        # A same-path redirect can succeed without disclosing new query data.
        redirected = source + "&access_token=PRIVATE_VALUE"
        with patch.object(probe, "safe_door_open",
                          return_value=FakeResponse(redirected)):
            result = probe.probe_door(station)
        self.assertEqual(result["outcome"], "http_ok")
        self.assertEqual(result["final_url"], source.split("?")[0])
        self.assertNotIn("PRIVATE_VALUE", str(result))

        # Error receipts must not expose unreviewed query values either.
        error = HTTPError(redirected, 404, "Not Found", {}, None)
        with patch.object(probe, "safe_door_open", side_effect=error):
            failed = probe.probe_door(station)
        self.assertEqual((failed["http_status"], failed["outcome"]),
                         (404, "http_error"))
        self.assertEqual(failed["final_url"], source.split("?")[0])
        self.assertNotIn("PRIVATE_VALUE", str(failed))


    def test_blocked_door_redirect_userinfo_never_enters_receipt(self):
        # The public-door lane is separate from the already repaired exit
        # lane. A blocked cross-host 302 previously retained user:password@
        # even though its query was stripped. Exercise the real handler.
        from urllib.request import Request

        station = next(s for s in self.data["stations"]
                       if s["slug"] == "tower")
        source = station["href"]
        target = ("https://auditor:PRIVATE_PASSWORD@unreviewed.example.org/"
                  "other?access_token=PRIVATE_TOKEN")
        handler = probe.SameDoorRedirect(source)
        with self.assertRaises(probe.DoorIdentityRedirectBlocked) as blocked:
            handler.redirect_request(
                Request(source), None, 302, "Found", {}, target
            )
        with patch.object(probe, "safe_door_open",
                          side_effect=blocked.exception):
            receipt = probe.probe_door(station)
        self.assertEqual(
            (receipt["http_status"], receipt["outcome"]),
            (302, "door_identity_redirect_blocked"),
        )
        self.assertEqual(receipt["final_url"],
                         "https://unreviewed.example.org/other")
        self.assertNotIn("PRIVATE_PASSWORD", json.dumps(receipt))
        self.assertNotIn("PRIVATE_TOKEN", json.dumps(receipt))

        # A direct HTTP error response uses the same receipt sanitizer.
        with patch.object(probe, "safe_door_open",
                          side_effect=HTTPError(target, 404, "Not Found", {}, None)):
            error_receipt = probe.probe_door(station)
        self.assertEqual(error_receipt["http_status"], 404)
        self.assertEqual(error_receipt["final_url"],
                         "https://unreviewed.example.org/other")
        self.assertNotIn("PRIVATE_PASSWORD", json.dumps(error_receipt))

    def test_redirected_door_identity_is_blocked_before_followup(self):
        # Real loopback 302: the old urllib opener followed /door to /wrong
        # and reported 200. The corrected probe rejects the destination.
        from http.server import BaseHTTPRequestHandler, HTTPServer
        from threading import Thread

        class Redirects(BaseHTTPRequestHandler):
            paths = []

            def do_GET(self):
                self.paths.append(self.path)
                if self.path == "/door":
                    target = "/wrong-application"
                elif self.path == "/private":
                    target = ("https://docs.google.com/document/d/"
                              "1wCmn5J4Tjo0qVV5AOoHUxD1tXComhPf7lU1ntzKtaMs/edit"
                              "?token=never-log")
                elif self.path == "/source":
                    target = "/other"
                elif self.path == "/same":
                    target = "/same/?access_token=PRIVATE_VALUE"
                elif self.path == "/canonical":
                    target = "/canonical/?canonical=1"
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
            # A same-door credential redirect is blocked *before* a second GET.
            same = probe.probe_door({"slug": "test", "name": "Test",
                                    "href": base + "/same"}, timeout=3)
            self.assertEqual((same["http_status"], same["outcome"]),
                             (302, "door_identity_redirect_blocked"))
            self.assertEqual(same["final_url"], base + "/same/")
            self.assertNotIn("PRIVATE_VALUE", str(same))
            self.assertEqual(Redirects.paths.count("/same"), 1)
            self.assertFalse(any("access_token=" in path
                                 for path in Redirects.paths))
            # Benign trailing-slash/query canonicalization remains navigable.
            canonical = probe.probe_door({"slug": "test", "name": "Test",
                                         "href": base + "/canonical"}, timeout=3)
            self.assertEqual((canonical["http_status"], canonical["outcome"]),
                             (200, "http_ok"))
            self.assertEqual(canonical["final_url"], base + "/canonical/")
            with patch.object(probe, "SOURCE_URL", base + "/source"):
                source = probe.probe_monorail_source(timeout=3)
            self.assertEqual((source["http_status"], source["outcome"]),
                             (302, "door_identity_redirect_blocked"))
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)

    def test_unreviewed_door_credential_queries_blocked_before_followup(self):
        # This is the independent 17-door lane; PR #194 addresses exits.
        # Percent-encoded and mixed-case keys must not evade the guard.
        from urllib.request import Request
        source = "https://example.org/door/"
        handler = probe.SameDoorRedirect(source)
        for query in ("?Access_Token=PRIVATE_VALUE",
                      "?%61ccess_token=PRIVATE_VALUE",
                      "?canonical=1&client_secret=PRIVATE_VALUE",
                      "?X-Amz-Signature=PRIVATE_VALUE"):
            with self.subTest(query=query):
                with self.assertRaises(probe.DoorIdentityRedirectBlocked) as blocked:
                    handler.redirect_request(Request(source), None, 302,
                                             "Found", {}, source + query)
                self.assertEqual(blocked.exception.code, 302)
                self.assertEqual(blocked.exception.geturl(), source)
        allowed = handler.redirect_request(Request(source), None, 302,
                                           "Found", {}, source + "?canonical=1")
        self.assertEqual(allowed.full_url, source + "?canonical=1")

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


    def test_pinned_observatory_view_redirect_cannot_silently_change_view(self):
        # A 302 from ?view=learn to ?view=atlas used to count as HTTP OK.
        # The same path and host are not enough for a query-pinned door.
        from urllib.request import Request

        station = next(s for s in self.data["stations"]
                       if s["slug"] == "observatory")
        source = station["href"]
        changed = source.replace("?view=learn", "?view=atlas")
        self.assertNotEqual(source, changed)
        handler = probe.SameDoorRedirect(source)
        with self.assertRaises(probe.DoorIdentityRedirectBlocked) as blocked:
            handler.redirect_request(
                Request(source), None, 302, "Found", {}, changed
            )
        with patch.object(probe, "safe_door_open",
                          side_effect=blocked.exception):
            receipt = probe.probe_door(station)
        self.assertEqual((receipt["http_status"], receipt["outcome"]),
                         (302, "door_identity_redirect_blocked"))
        self.assertEqual(receipt["final_url"], source.split("?")[0])
        self.assertNotIn("view=atlas", json.dumps(receipt))

        # An unchanged pinned query is allowed, including slash canonicalization.
        same = handler.redirect_request(
            Request(source), None, 302, "Found", {},
            source.replace("/?view=learn", "?view=learn")
        )
        self.assertEqual(same.full_url, source.replace("/?view=learn", "?view=learn"))

        # Unpinned public doors retain their preexisting query redirects.
        unpinned = "https://nicholaskouns-create.github.io/work/"
        canonical = probe.SameDoorRedirect(unpinned).redirect_request(
            Request(unpinned), None, 302, "Found", {},
            unpinned + "?canonical=1"
        )
        self.assertEqual(canonical.full_url, unpinned + "?canonical=1")


if __name__ == "__main__":
    unittest.main()
