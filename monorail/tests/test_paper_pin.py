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


if __name__ == "__main__":
    unittest.main()
