"""Offline regression tests for the bounded Monorail public-door probe."""
from __future__ import annotations

import sys
import unittest
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


class PublicDoorProbeTests(unittest.TestCase):
    def setUp(self):
        self.data = probe.read_corpus()

    def test_source_census_preserved(self):
        self.assertEqual(len(self.data["stations"]), 17)
        self.assertEqual(sum(len(s["links"]) for s in self.data["stations"]), 54)
        self.assertEqual([(r["id"], r["status"]) for r in self.data["repairs"]],
                         [("highlight", "404"), ("paper", "404"),
                          ("mirror", "401"), ("modsync", "401")])

    def test_restricted_originals_are_not_door_requests(self):
        doors = {s["href"] for s in self.data["stations"]}
        restricted = {l["href"] for s in self.data["stations"]
                      for l in s["links"] if l.get("state") == "restricted"}
        self.assertEqual(len(restricted), 2)
        self.assertFalse(doors & restricted)

    def test_success_is_http_evidence_not_browser_certification(self):
        station = self.data["stations"][0]
        with patch.object(probe, "urlopen", side_effect=lambda req, timeout: FakeResponse(req.full_url)):
            result = probe.probe_door(station)
        self.assertEqual(result["http_status"], 200)
        self.assertEqual(result["outcome"], "http_ok")

    def test_http_404_remains_distinct_from_network_error(self):
        station = self.data["stations"][0]
        with patch.object(probe, "urlopen", side_effect=HTTPError(station["href"], 404, "Not Found", {}, None)):
            result = probe.probe_door(station)
        self.assertEqual(result["http_status"], 404)
        self.assertEqual(result["outcome"], "http_error")

    def test_transport_error_is_unverified_not_404(self):
        station = self.data["stations"][0]
        with patch.object(probe, "urlopen", side_effect=URLError("DNS unavailable")):
            result = probe.probe_door(station)
        self.assertIsNone(result["http_status"])
        self.assertEqual(result["outcome"], "network_error")

    def test_full_audit_preserves_historical_failures(self):
        with patch.object(probe, "probe_door", side_effect=lambda s: {
            "slug": s["slug"], "title": s["name"], "url": s["href"],
            "http_status": 200, "final_url": s["href"], "outcome": "http_ok"}):
            result = probe.audit(self.data)
        self.assertEqual(result["http_ok"], 17)
        self.assertEqual(result["source_exit_count"], 54)
        self.assertEqual(result["historical_census"]["links_followed"], 177)
        self.assertEqual(result["historical_census"]["failures"], 4)
        self.assertEqual(len(result["restricted_originals_not_requested"]), 2)
        self.assertIn("not a browser render", result["claim_boundary"])


if __name__ == "__main__":
    unittest.main()
