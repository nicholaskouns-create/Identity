"""Regression checks for the Monorail paper pin and historical link census.

Runs with the Python standard library:
    python3 -m unittest discover -s monorail/tests -v
"""
import json
import re
import unittest
from pathlib import Path

HTML = (Path(__file__).resolve().parents[1] / "index.html").read_text(encoding="utf-8")
match = re.search(r'<script id="data" type="application/json">(.*?)</script>', HTML, re.S)
if not match:
    raise RuntimeError("Monorail embedded JSON data missing")
DATA = json.loads(match.group(1))
COMMIT = "c14e98bd6d701723c887a5ba3a34b8caf902ab55"
PAPER = (
    "https://github.com/nicholaskouns-create/E47-Kartekeya/blob/"
    + COMMIT
    + "/research/e47/papers/fib_lucas_tower/tower_paper.tex"
)


class PaperPinTests(unittest.TestCase):
    def test_seventeen_independent_doors_preserved(self):
        self.assertEqual(len(DATA["stations"]), 17)
        self.assertEqual(len({s["slug"] for s in DATA["stations"]}), 17)
        self.assertTrue(all(s["href"].startswith("https://") for s in DATA["stations"]))

    def test_original_paper_is_linked_at_verified_commit(self):
        tower = next(s for s in DATA["stations"] if s["slug"] == "tower")
        link = next(l for l in tower["links"] if l["label"].startswith("Tower paper"))
        self.assertEqual(link["href"], PAPER)
        paper = next(r for r in DATA["repairs"] if r["id"] == "paper")
        self.assertEqual(paper["redirects"][0]["href"], PAPER)

    def test_merged_tower_pin_provenance_is_current(self):
        tower = next(s for s in DATA["stations"] if s["slug"] == "tower")
        paper = next(r for r in DATA["repairs"] if r["id"] == "paper")
        self.assertIn("Tower PR #5 merged an immutable pin", tower["gist"])
        self.assertIn("Merged Tower PR #5 now pins", paper["why"])
        self.assertIn(COMMIT, paper["why"])
        self.assertIn("research/fib-lucas-tower-paper", paper["why"])
        self.assertNotIn("already checks that branch as a fallback", paper["why"])
        self.assertNotIn("which Tower already checks as a fallback", tower["gist"])

    def test_historical_failures_and_validator_preserved(self):
        self.assertEqual(len(DATA["repairs"]), 4)
        paper = next(r for r in DATA["repairs"] if r["id"] == "paper")
        self.assertEqual(paper["status"], "404")
        self.assertIn("/main/", paper["failed"])
        self.assertIn("research/fib-lucas-tower-paper", paper["why"])
        self.assertTrue(any("e47_fib_lucas_tower_validate.py" in r["href"]
                            for r in paper["redirects"]))


    def test_tower_station_directly_links_pinned_manuscript(self):
        """The rendered Tower exit must open the verified source, not only a repair card."""
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
        self.assertIn('href="' + PAPER + '"', rendered)
        self.assertIn("Original manuscript · immutable source", rendered)
        self.assertIn('href="#/repair/paper"', rendered)
        self.assertIn("Historical 404 and pin provenance", rendered)
        self.assertIn("Source pinned", rendered)


    def test_restricted_repair_cards_link_original_for_authorized_access(self):
        """A 401 repair card must retain an openable original and separate public context."""
        import subprocess

        esc_js = next(line for line in HTML.splitlines() if line.startswith("function esc(s)"))
        repair_js = "function repair(id){" + HTML.split("function repair(id){", 1)[1].split(
            "\nfunction richardson(){", 1
        )[0]
        program = (
            "const DATA = " + json.dumps(DATA) + ";\n"
            + esc_js + "\n" + repair_js + "\n"
            + "for (const id of ['mirror', 'modsync']) "
              "console.log(JSON.stringify({id, html: repair(id)}));"
        )
        output = subprocess.run(
            ["node", "-e", program], check=True, capture_output=True, text=True
        ).stdout
        rendered = [json.loads(line) for line in output.splitlines()]
        self.assertEqual({row["id"] for row in rendered}, {"mirror", "modsync"})
        for row in rendered:
            original = next(r for r in DATA["repairs"] if r["id"] == row["id"])
            html = row["html"]
            self.assertEqual(original["status"], "401")
            self.assertIn('href="' + original["failed"] + '"', html)
            self.assertIn(
                "Open original restricted Drive source (sign-in or access request may be required)",
                html,
            )
            self.assertIn('href="' + original["redirects"][0]["href"] + '"', html)
            self.assertIn("restricted source, not replaced", html)
            self.assertNotIn("Replaced locally", html)

    def test_dated_live_tower_evidence_without_erasing_historical_failures(self):
        """Current browser evidence is linked, while 404/401 originals stay intact."""
        run = "https://github.com/nicholaskouns-create/tower/actions/runs/41222214187"
        for repair_id in ("highlight", "paper"):
            repair = next(r for r in DATA["repairs"] if r["id"] == repair_id)
            self.assertEqual(repair["status"], "404")
            self.assertEqual(repair["sourceEvidence"]["browser_ci"], run)
            self.assertIn("2026-10-31", repair["sourceEvidence"]["scope"])
            self.assertEqual(repair["sourceEvidence"]["deployed_commit"], "3f277ddf3a84f9f10e804196b6d2668c94e805b")
            self.assertEqual(repair["sourceEvidence"]["deployment_ci"], run)
            self.assertNotIn("deployment commit remains unverified", repair["sourceEvidence"]["scope"])
        for repair_id in ("mirror", "modsync"):
            repair = next(r for r in DATA["repairs"] if r["id"] == repair_id)
            self.assertEqual(repair["status"], "401")
            self.assertNotIn("browser_ci", repair.get("sourceEvidence", {}))
        self.assertIn("Live Chromium evidence · 31 Oct 2026", HTML)
        self.assertIn("Public Pages build.json was read back at deployed tower@3f277ddf3a84f9f10e804196b6d2668c94e805b", HTML)
        self.assertNotIn("public deployment unverified", HTML)
        self.assertEqual(sum(len(s["links"]) for s in DATA["stations"]), 54)


if __name__ == "__main__":
    unittest.main()
