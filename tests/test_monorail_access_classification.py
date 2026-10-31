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

    def test_restricted_original_url_remains_clickable_in_rendered_station(self):
        """Exercise the actual station() renderer with Node, not only JSON labels."""
        import subprocess

        esc_js = next(line for line in HTML.splitlines() if line.startswith("function esc(s)"))
        station_js = "function station(slug){" + HTML.split("function station(slug){", 1)[1].split(
            "\nfunction repair(id){", 1
        )[0]
        program = (
            "const DATA = " + json.dumps(DATA) + ";\n"
            + esc_js + "\n" + station_js + "\n"
            + "console.log(JSON.stringify({matrix:station('matrix'),time:station('time'),tower:station('tower')}));"
        )
        result = subprocess.run(
            ["node", "-e", program], check=True, capture_output=True, text=True
        )
        rendered = json.loads(result.stdout)
        repairs = {r["id"]: r for r in DATA["repairs"]}
        for slug, repair_id in (("matrix", "mirror"), ("time", "modsync")):
            self.assertIn('href="' + repairs[repair_id]["failed"] + '"', rendered[slug])
            self.assertIn('href="#/repair/' + repair_id + '"', rendered[slug])
            self.assertIn("Original restricted source", rendered[slug])
            self.assertIn("Owner-only source · public alternatives", rendered[slug])
        self.assertIn("Merged source fix", rendered["tower"])
        self.assertIn('href="#/repair/highlight"', rendered["tower"])

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
        for repair_id, expected_state in (("highlight", "repaired"), ("paper", "repaired")):
            link = next(l for l in stations["tower"]["links"] if l.get("repair") == repair_id)
            self.assertEqual(link["state"], expected_state)
        self.assertIn('l.state === "restricted"', HTML)
        self.assertIn('(l.state === "repaired" || l.state === "restricted" || l.state === "pending")', HTML)

    def test_401_not_described_as_replaced(self):
        self.assertIn("restricted source, not replaced", HTML)
        self.assertIn("Whether this restriction was intentional is unknown", HTML)
        self.assertIn("not a replacement for or validation of the restricted file", HTML)
        self.assertNotIn("replaced locally</p>", HTML)

    def test_preview_and_home_copy_preserve_401_boundary(self):
        """Metadata and the landing view must not imply private 401s were repaired."""
        meta = re.search(r'<meta name="description" content="([^"]+)">', HTML)
        og = re.search(r'<meta property="og:description" content="([^"]+)">', HTML)
        twitter = re.search(r'<meta name="twitter:description" content="([^"]+)">', HTML)
        self.assertIsNotNone(meta)
        self.assertIsNotNone(og)
        self.assertIsNotNone(twitter)
        self.assertEqual(og.group(1), twitter.group(1))
        self.assertIn("two 404s and two restricted 401s", meta.group(1))
        self.assertIn("Restricted originals remain distinct", og.group(1))
        self.assertIn("the Tower highlighter and immutable paper were browser-verified on 31 October 2026", HTML)
        self.assertIn("Public alternatives do not replace private sources", HTML)
        self.assertNotIn("four broken links replaced locally", HTML)
        self.assertNotIn("Only what failed is replaced", HTML)

    def test_merged_highlighter_station_discloses_historical_404_and_source(self):
        """Historical 404 persists even after dated browser confirmation."""
        import subprocess

        esc_js = next(line for line in HTML.splitlines() if line.startswith("function esc(s)"))
        station_js = "function station(slug){" + HTML.split("function station(slug){", 1)[1].split(
            "\nfunction repair(id){", 1
        )[0]
        program = (
            "const DATA = " + json.dumps(DATA) + ";\n"
            + esc_js + "\n" + station_js + "\n"
            + "console.log(station('tower'));"
        )
        rendered = subprocess.run(
            ["node", "-e", program], check=True, capture_output=True, text=True
        ).stdout
        highlighter = next(r for r in DATA["repairs"] if r["id"] == "highlight")
        self.assertIn("Historical 404: " + highlighter["failed"], rendered)
        self.assertIn('href="' + highlighter["redirects"][0]["href"] + '"', rendered)
        self.assertIn("Merged source fix · browser-verified 31 Oct 2026", rendered)
        self.assertIn("Merged source fix", rendered)
        self.assertIn('href="#/repair/highlight"', rendered)
        self.assertNotIn('href="' + highlighter["failed"] + '"', rendered)

    def test_highlighter_merge_evidence_is_source_scoped(self):
        """Merged source and dated browser evidence have distinct scopes."""
        repairs = {r["id"]: r for r in DATA["repairs"]}
        tower = next(s for s in DATA["stations"] if s["slug"] == "tower")
        highlighter = repairs["highlight"]
        self.assertEqual(highlighter["status"], "404")  # historical failure preserved
        self.assertEqual(highlighter["sourceEvidence"]["pull_request"],
                         "https://github.com/nicholaskouns-create/tower/pull/4")
        self.assertEqual(highlighter["sourceEvidence"]["merge_commit"],
                         "1e1306c984cb5b290371d815ca9853e6c2b3eb5e")
        self.assertEqual(highlighter["sourceEvidence"]["ci_result"], "success")
        self.assertIn("deployment commit remains unverified", highlighter["sourceEvidence"]["scope"])
        self.assertEqual(next(l for l in tower["links"] if l.get("repair") == "highlight")["state"],
                         "repaired")
        self.assertIn("Live Chromium evidence · 31 Oct 2026", HTML)
        self.assertNotIn("one highlighter repair is pending merge", HTML)

    def test_original_404_repair_path_remains(self):
        self.assertIn('r.status === "401"', HTML)
        self.assertIn('historical broken link', HTML)
        self.assertIn("Repair details", HTML)


if __name__ == "__main__":
    unittest.main()
