"""Offline invariants for the independent 54-exit HTTP evidence lane."""
import json
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


    def test_spa_fragment_does_not_erase_pinned_eidolon_query_in_receipt(self):
        # Reproduce the existing source identity. urllib never sends #flight,
        # but the catalogued ?module=eidolon query is a reviewed part of the
        # exit URL and must survive in the public HTTP receipt.
        public, _ = probe.partition_exits(self.data)
        row = next(r for r in public
                   if r["station"] == "instruments"
                   and r["label"] == "Eidolon flight")
        source = row["url"]
        self.assertEqual(source,
                         "https://nicholaskouns-create.github.io/"
                         "E47-Kartekeya/interfaces/kouns-core/?module=eidolon#flight")
        http_url = source.split("#", 1)[0]

        class Response:
            status = 200

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def geturl(self):
                return http_url

            def read(self, n):
                self_read = n
                assert self_read == 1
                return b"x"

        with patch.object(probe, "safe_urlopen", return_value=Response()) as opened:
            receipt = probe.probe_exit(row)
        self.assertEqual(opened.call_args.args[0].full_url, http_url)
        self.assertEqual((receipt["http_status"], receipt["outcome"]),
                         (200, "http_ok"))
        self.assertEqual(receipt["final_url"], http_url)
        # Unreviewed additions are still redacted.
        self.assertEqual(
            probe.receipt_url(http_url + "&access_token=PRIVATE_VALUE", source),
            http_url.split("?")[0],
        )

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

    def test_same_exit_query_redirect_remains_reachable(self):
        from http.server import BaseHTTPRequestHandler, HTTPServer
        from threading import Thread

        class Redirect(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == "/start":
                    self.send_response(302)
                    self.send_header("Location", "/start?canonical=1")
                else:
                    self.send_response(200)
                self.end_headers()
                if self.path == "/start?canonical=1":
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
            self.assertEqual(result["final_url"], row["url"])
            self.assertNotIn("canonical=1", str(result))
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)

    def test_wrong_exit_redirect_is_blocked_before_followup(self):
        # An unrelated HTTP 200 used to satisfy the original exit probe
        # after a 302, despite changing the requested link's identity.
        from http.server import BaseHTTPRequestHandler, HTTPServer
        from threading import Thread

        class Redirect(BaseHTTPRequestHandler):
            paths = []

            def do_GET(self):
                self.paths.append(self.path)
                self.send_response(302 if self.path == "/start" else 200)
                if self.path == "/start":
                    self.send_header("Location", "/unrelated?token=not-for-receipt")
                self.end_headers()

            def log_message(self, *_):
                pass

        server = HTTPServer(("127.0.0.1", 0), Redirect)
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            original = f"http://127.0.0.1:{server.server_port}/start"
            row = {"station": "test", "label": "public exit",
                   "url": original, "state": "live"}
            result = probe.probe_exit(row, timeout=3)
            self.assertEqual(result["http_status"], 302)
            self.assertEqual(result["outcome"], "exit_identity_redirect_blocked")
            self.assertEqual(result["final_url"],
                             f"http://127.0.0.1:{server.server_port}/unrelated")
            self.assertEqual(Redirect.paths, ["/start"])
            self.assertNotIn("token=", str(result))
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)

    def test_same_exit_trailing_slash_redirect_still_allowed(self):
        from http.server import BaseHTTPRequestHandler, HTTPServer
        from threading import Thread

        class Redirect(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == "/start":
                    self.send_response(302)
                    self.send_header("Location", "/start/?canonical=1")
                else:
                    self.send_response(200)
                self.end_headers()
                if self.path.startswith("/start/"):
                    self.wfile.write(b"same exit")

            def log_message(self, *_):
                pass

        server = HTTPServer(("127.0.0.1", 0), Redirect)
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            original = f"http://127.0.0.1:{server.server_port}/start"
            row = {"station": "test", "label": "public exit",
                   "url": original, "state": "live"}
            result = probe.probe_exit(row, timeout=3)
            self.assertEqual((result["http_status"], result["outcome"]),
                             (200, "http_ok"))
            self.assertEqual(result["final_url"], original + "/")
            self.assertNotIn("canonical=1", str(result))
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)

    def test_unreviewed_redirect_query_not_persisted_in_receipt(self):
        # The HTTP request may use the redirect query, but the public
        # evidence artifact must not retain its potentially private value.
        from http.server import BaseHTTPRequestHandler, HTTPServer
        from threading import Thread

        class Redirect(BaseHTTPRequestHandler):
            paths = []

            def do_GET(self):
                self.paths.append(self.path)
                if self.path == "/start":
                    self.send_response(302)
                    self.send_header("Location", "/start?access_token=PRIVATE_VALUE")
                else:
                    self.send_response(200)
                self.end_headers()
                if self.path != "/start":
                    self.wfile.write(b"ok")

            def log_message(self, *_):
                pass

        server = HTTPServer(("127.0.0.1", 0), Redirect)
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            original = f"http://127.0.0.1:{server.server_port}/start"
            row = {"station": "test", "label": "public exit",
                   "url": original, "state": "live"}
            result = probe.probe_exit(row, timeout=3)
            self.assertEqual((result["http_status"], result["outcome"]),
                             (200, "http_ok"))
            self.assertEqual(result["final_url"], original)
            self.assertEqual(Redirect.paths,
                             ["/start", "/start?access_token=PRIVATE_VALUE"])
            self.assertNotIn("PRIVATE_VALUE", json.dumps(result))
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)

    def test_reviewed_spectra_query_preserved_but_unknown_query_redacted(self):
        source, target = next(iter(probe.REVIEWED_EXTERNAL_REDIRECTS.items()))
        self.assertEqual(probe.receipt_url(target.split("#")[0], source),
                         target.split("#")[0])
        self.assertEqual(
            probe.receipt_url("https://example.org/start?secret=PRIVATE_VALUE",
                              "https://example.org/start"),
            "https://example.org/start",
        )
        self.assertEqual(
            probe.receipt_url("https://example.org/start?view=learn",
                              "https://example.org/start?view=learn"),
            "https://example.org/start?view=learn",
        )

    def test_pinned_exit_query_survives_trailing_slash_canonicalization(self):
        # R48 regression: the redirect guard already permits the same pinned
        # view with a trailing slash normalized, but receipt_url previously
        # stripped that query from final_url despite reporting HTTP 200.
        from urllib.request import Request

        cases = (
            ("https://nicholaskouns-create.github.io/"
             "E47-Kartekeya/interfaces/observatory/?view=atlas",
             "https://nicholaskouns-create.github.io/"
             "E47-Kartekeya/interfaces/observatory?view=atlas"),
            ("https://nicholaskouns-create.github.io/"
             "E47-Kartekeya/interfaces/kouns-core/?module=eidolon#flight",
             "https://nicholaskouns-create.github.io/"
             "E47-Kartekeya/interfaces/kouns-core?module=eidolon"),
        )
        for source, target in cases:
            with self.subTest(source=source):
                http_source = source.split("#", 1)[0]
                handler = probe.SameExitRedirect(http_source)
                allowed = handler.redirect_request(
                    Request(http_source), None, 302, "Found", {}, target
                )
                self.assertEqual(allowed.full_url, target)
                self.assertEqual(probe.receipt_url(target, source), target)

                # A changed query is still unreviewed and must not survive
                # into the durable public navigation evidence.
                altered = target + "&access_token=PRIVATE_VALUE"
                self.assertEqual(
                    probe.receipt_url(altered, source), target.split("?")[0]
                )
                self.assertNotIn(
                    "PRIVATE_VALUE", probe.receipt_url(altered, source)
                )

    def test_only_exact_deployed_spectra_redirect_is_reviewed(self):
        from urllib.request import Request

        source, target = next(iter(probe.REVIEWED_EXTERNAL_REDIRECTS.items()))
        redirect = probe.SameExitRedirect(source)
        req = Request(source)
        approved = redirect.redirect_request(req, None, 302, "Found", {}, target)
        self.assertEqual(approved.full_url, target)

        for altered in (target + "&unexpected=1",
                        "https://unrelated.example.org/",
                        "https://dune-orchid-berry-mountain.grok.me/other"):
            with self.subTest(altered=altered):
                with self.assertRaises(probe.ExitIdentityRedirectBlocked):
                    redirect.redirect_request(req, None, 302, "Found", {},
                                              altered)

    def test_blocked_redirect_userinfo_is_redacted_from_public_receipt(self):
        # The original query-only redaction still leaked user:password@host
        # from a blocked 302 target into the archived final_url.
        from urllib.request import Request

        source = "https://example.org/start"
        cases = (
            ("https://user:PRIVATE_PASSWORD@unrelated.example.org/else"
             "?access_token=PRIVATE_TOKEN",
             "https://unrelated.example.org/else",
             "exit_identity_redirect_blocked"),
            ("https://user:PRIVATE_PASSWORD@docs.google.com/document/d/private/edit"
             "?access_token=PRIVATE_TOKEN",
             "https://docs.google.com/document/d/private/edit",
             "restricted_redirect_blocked"),
        )
        for target, expected, outcome in cases:
            with self.subTest(outcome=outcome):
                redirect = probe.SameExitRedirect(source)
                with self.assertRaises((
                    probe.ExitIdentityRedirectBlocked,
                    probe.RestrictedDriveRedirect,
                )) as raised:
                    redirect.redirect_request(
                        Request(source), None, 302, "Found", {}, target
                    )
                row = {"station": "test", "label": "public redirect",
                       "url": source, "state": "live"}
                with patch.object(probe, "safe_urlopen",
                                  side_effect=raised.exception):
                    receipt = probe.probe_exit(row)
                self.assertEqual(receipt["http_status"], 302)
                self.assertEqual(receipt["outcome"], outcome)
                self.assertEqual(receipt["final_url"], expected)
                self.assertNotIn("PRIVATE_", json.dumps(receipt))
                self.assertNotIn("user:", json.dumps(receipt))

    def test_wrong_exit_redirect_counts_as_failure(self):
        def simulated(row):
            if row["station"] == "home" and row["label"] == "Identity":
                return dict(row, outcome="exit_identity_redirect_blocked",
                            http_status=302)
            return dict(row, outcome="http_ok", http_status=200)

        with patch.object(probe, "probe_exit", side_effect=simulated):
            receipt = probe.audit(self.data, workers=1)
        self.assertEqual(receipt["http_ok"], 50)
        self.assertEqual(receipt["http_error"], 1)
        self.assertEqual(receipt["exit_identity_redirect_blocked"], 1)
        self.assertEqual(receipt["historical_census"]["failures"], 4)

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


    def test_public_exit_swap_rejected_before_any_network_probe(self):
        # Reproduces the R34 defect: two live 200-returning URLs could be
        # exchanged while 54/51/3 counts and private exclusions stayed fixed.
        data = deepcopy(self.data)
        first, second = data["stations"][0]["links"][:2]
        first["href"], second["href"] = second["href"], first["href"]
        with patch.object(probe, "probe_exit") as request:
            with self.assertRaisesRegex(ValueError, "Catalogued exit identity changed"):
                probe.audit(data, workers=1)
            request.assert_not_called()

    def test_public_exit_query_and_spa_fragment_are_identity(self):
        for station_slug, label, url in (
            ("work", "Tower", "https://nicholaskouns-create.github.io/tower/"),
            ("lucas", "Observatory atlas",
             "https://nicholaskouns-create.github.io/E47-Kartekeya/interfaces/observatory/"),
        ):
            with self.subTest(station=station_slug, label=label):
                data = deepcopy(self.data)
                station = next(s for s in data["stations"]
                               if s["slug"] == station_slug)
                next(l for l in station["links"] if l["label"] == label)["href"] = url
                with self.assertRaisesRegex(ValueError, "Catalogued exit identity changed"):
                    probe.partition_exits(data)

    def test_reviewable_fixture_covers_all_54_original_exits(self):
        fixture = json.loads(probe.EXPECTED_EXIT_IDENTITIES_PATH.read_text(
            encoding="utf-8"))
        rows = fixture["exits"]
        self.assertEqual(len(rows), 54)
        self.assertEqual(len({(r["station"], r["label"]) for r in rows}), 54)
        self.assertEqual(sum(r["state"] == "restricted" for r in rows), 2)
        self.assertEqual(sum(r["repair"] == "highlight" for r in rows), 1)
        probe.verify_catalogued_exit_identities(self.data)


    def test_pinned_exit_query_redirect_cannot_switch_view(self):
        # Before R47, a same-host/same-path 302 could silently replace a
        # source-pinned view or instrument and be reported as HTTP 200.
        # Exercise the actual urllib redirect handler without a network call.
        from urllib.request import Request

        public, _ = probe.partition_exits(self.data)
        for station, label, old_query, new_query in (
            ("lucas", "Observatory atlas", "?view=atlas", "?view=learn"),
            ("instruments", "Eidolon flight",
             "?module=eidolon", "?module=other"),
        ):
            with self.subTest(station=station, label=label):
                row = next(r for r in public if r["station"] == station
                           and r["label"] == label)
                source = row["url"].split("#", 1)[0]
                changed = source.replace(old_query, new_query)
                self.assertNotEqual(changed, source)
                handler = probe.SameExitRedirect(source)
                with self.assertRaises(
                    probe.ExitIdentityRedirectBlocked
                ) as blocked:
                    handler.redirect_request(
                        Request(source), None, 302, "Found", {}, changed
                    )
                with patch.object(probe, "safe_urlopen",
                                  side_effect=blocked.exception):
                    receipt = probe.probe_exit(row)
                self.assertEqual(
                    (receipt["http_status"], receipt["outcome"]),
                    (302, "exit_identity_redirect_blocked"),
                )
                self.assertEqual(receipt["final_url"], source.split("?")[0])
                self.assertNotIn(new_query, json.dumps(receipt))

                # The original pinned query remains valid across the
                # preexisting trailing-slash canonicalization.
                canonical = source.replace("/" + old_query, old_query)
                same = handler.redirect_request(
                    Request(source), None, 302, "Found", {}, canonical
                )
                self.assertEqual(same.full_url, canonical)

        # An unpinned public exit still permits canonical query redirects.
        unpinned = "https://nicholaskouns-create.github.io/Identity/"
        same = probe.SameExitRedirect(unpinned).redirect_request(
            Request(unpinned), None, 302, "Found", {},
            unpinned + "?canonical=1"
        )
        self.assertEqual(same.full_url, unpinned + "?canonical=1")


    def test_json_certificate_exit_rejects_html_fallback(self):
        # Real HTTP responses: a static .json certificate must not be
        # counted as a working JSON exit when Pages returns an HTML fallback.
        # A valid JSON MIME and an unrelated HTML application remain OK.
        from http.server import BaseHTTPRequestHandler, HTTPServer
        from threading import Thread

        class JsonExitServer(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == "/certificate.json":
                    mime, payload = "text/html; charset=utf-8", b"<html>fallback</html>"
                elif self.path == "/valid.json":
                    mime, payload = "application/json; charset=utf-8", b'{"ok":true}'
                else:
                    mime, payload = "text/html; charset=utf-8", b"<html>app</html>"
                self.send_response(200)
                self.send_header("Content-Type", mime)
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)

            def log_message(self, *_):
                pass

        server = HTTPServer(("127.0.0.1", 0), JsonExitServer)
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = f"http://127.0.0.1:{server.server_port}"
        try:
            for suffix, expected, error_type in (
                ("/certificate.json", "http_error", "unexpected_json_content_type"),
                ("/valid.json", "http_ok", None),
                ("/app/", "http_ok", None),
            ):
                with self.subTest(suffix=suffix):
                    row = {"station": "time", "label": "Clock certificate",
                           "url": base + suffix, "state": "live"}
                    receipt = probe.probe_exit(row, timeout=3)
                    self.assertEqual(receipt["http_status"], 200)
                    self.assertEqual(receipt["outcome"], expected)
                    self.assertEqual(receipt.get("error_type"), error_type)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)


if __name__ == "__main__":
    unittest.main()
