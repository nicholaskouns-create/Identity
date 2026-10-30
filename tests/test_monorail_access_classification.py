"""Regression guard for the Monorail's historical 401 authorization boundaries.

These checks test source navigation and provenance, not live anonymous access.
The original 29 October 2026 census remains historical evidence.
"""
import json
import re
import unittest
from pathlib import Path

HTML = (Path(__file__).resolve().parents[1] / "monorail" / "index.html").read_text(encoding="utf-8")
MATCH = re.search(r'<script id="data" type="application/json">([\s\S]*?)</script>', HTML)
if not MATCH:
    raise RuntimeError("Monorail JSON corpus is missing")
DATA = json.loads(MATCH.group(1))


class MonorailRestrictedAccessTest(unittest.TestCase):
    def test_historical_census_preserved(self):
        self.assertEqual(len(DATA["stations"]), 17)
        self.assertEqual(len(DATA["repairs"]), 4)
        self.assertEqual(
            {r["id"]: r["status"] for r in DATA["repairs"]},
            {"highlight": "404", "paper": "404", "mirror": "401", "modsync": "401"},
        )
        self.assertIn("177 links followed", HTML)

    def test_original_private_urls_preserved(self):
        repairs = {r["id"]: r for r in DATA["repairs"]}
        self.assertEqual(
            repairs["mirror"]["failed"],
            "https://docs.google.com/document/d/1wCmn5J4Tjo0qVV5AOoHUxD1tXComhPf7lU1ntzKtaMs/edit",
        )
        self.assertEqual(
            repairs["modsync"]["failed"],
            "https://drive.google.com/file/d/1-bCyEuWcN1rtRb1IJF02O8tTe7RbmaEC/view",
        )
        for r in (repairs["mirror"], repairs["modsync"]):
            self.assertNotIn(r["failed"], [d["href"] for d in r["redirects"]])

    def test_401_stations_route_to_access_details(self):
        stations = {s["slug"]: s for s in DATA["stations"]}
        for slug, repair_id in (("matrix", "mirror"), ("time", "modsync")):
            links = [l for l in stations[slug]["links"] if l.get("repair") == repair_id]
            self.assertEqual(len(links), 1)
            self.assertEqual(links[0]["state"], "restricted")
        self.assertIn('r.status === "401"', HTML)
        self.assertIn("Owner-only source · public alternatives", HTML)
        self.assertIn("Restricted</span>", HTML)

    def test_machine_readable_401_and_404_classes_remain_distinct(self):
        stations = {s["slug"]: s for s in DATA["stations"]}
        repairs = {r["id"]: r for r in DATA["repairs"]}
        self.assertEqual(
            {r["id"] for r in DATA["repairs"] if r["status"] == "401"},
            {"mirror", "modsync"},
        )
        for slug, repair_id in (("matrix", "mirror"), ("time", "modsync")):
            link = next(l for l in stations[slug]["links"] if l.get("repair") == repair_id)
            self.assertEqual(link["state"], "restricted")
            self.assertEqual(link["href"], repairs[repair_id]["failed"])
        for repair_id in ("highlight", "paper"):
            link = next(l for l in stations["tower"]["links"] if l.get("repair") == repair_id)
            self.assertEqual(link["state"], "repaired")
        self.assertIn('l.state === "restricted"', HTML)
        self.assertIn('(l.state === "repaired" || l.state === "restricted")', HTML)

    def test_401_not_described_as_replaced(self):
        self.assertIn("restricted source, not replaced", HTML)
        self.assertIn("Whether this restriction was intentional is unknown", HTML)
        self.assertIn("not a replacement for or validation of the restricted file", HTML)
        self.assertNotIn("replaced locally</p>", HTML)

    def test_original_404_repair_path_remains(self):
        self.assertIn('r.status === "401"', HTML)
        self.assertIn('historical broken link', HTML)
        self.assertIn("Repair details", HTML)


if __name__ == "__main__":
    unittest.main()
