"""Regression checks for the missing Lean/Coq source-browser route.

These checks validate local navigation and file provenance, not proof acceptance
or anonymous GitHub Pages deployment.
"""
from html.parser import HTMLParser
from pathlib import Path
import unittest
from urllib.parse import urlparse, unquote

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / "site/proof/lean-coq/browser.html"
SOURCE_PREFIX = "https://github.com/nicholaskouns-create/Identity/blob/main/"
PAIRS = (
    "formal/e47/unified/Core47",
    "formal/e47/E47WeightAlgebra",
    "formal/e47/E47Spectral",
    "formal/e47/E47Richardson",
)


class BrowserParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.rows = 0
        self.inputs = []
        self.external_scripts = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a":
            self.links.append(attrs.get("href", ""))
        if tag == "tr" and "data-keywords" in attrs:
            self.rows += 1
        if tag == "input":
            self.inputs.append(attrs)
        if tag == "script" and attrs.get("src"):
            self.external_scripts.append(attrs["src"])


class LeanCoqBrowserTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = PAGE.read_text(encoding="utf-8")
        cls.page = BrowserParser()
        cls.page.feed(cls.source)

    def test_route_and_pairs(self):
        self.assertEqual(self.page.rows, len(PAIRS))
        self.assertIn("Lean 4 / Coq source browser", self.source)
        self.assertEqual(self.page.external_scripts, [])

    def test_original_paired_sources_exist(self):
        for base in PAIRS:
            for ext in (".lean", ".v"):
                path = base + ext
                with self.subTest(path=path):
                    self.assertTrue((ROOT / path).is_file(), path)
                    self.assertIn(SOURCE_PREFIX + path, self.page.links)

    def test_search_is_operable_and_accessible(self):
        self.assertTrue(any(x.get("id") == "filter" and x.get("type") == "search" for x in self.page.inputs))
        self.assertIn('input.addEventListener("input"', self.source)
        self.assertIn('aria-live="polite"', self.source)
        self.assertIn("table tr[hidden]{display:none!important}", self.source)

    def test_evidence_boundary_and_original_plate(self):
        self.assertIn("A source link is not a compiler receipt", self.source)
        self.assertIn("This page does not run Lean or Coq", self.source)
        self.assertIn("./", self.page.links)
        self.assertIn("https://github.com/nicholaskouns-create/Identity/actions/workflows/e47-formal-validation.yml", self.page.links)
        self.assertNotIn("http://", self.source)


if __name__ == "__main__":
    unittest.main()
