"""Offline regression tests for immutable Socorro reproduction links."""
from html.parser import HTMLParser
from pathlib import Path
import unittest

SITE = Path(__file__).resolve().parents[2] / "site" / "socorro-stochastic.html"
REVISION = "edb517cb65fe64fae479fe113d4ec5a4b95b2a19"
ROOT = "https://github.com/nicholaskouns-create/Identity/blob/"
FILES = ("README.md", "validate.py", "validate_torch.py")


class Anchors(HTMLParser):
    def __init__(self):
        super().__init__()
        self.hrefs = []
        self.ids = set()

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag == "a" and "href" in attributes:
            self.hrefs.append(attributes["href"])
        if "id" in attributes:
            self.ids.add(attributes["id"])


class SocorroProvenanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.html = SITE.read_text(encoding="utf-8")
        cls.parsed = Anchors()
        cls.parsed.feed(cls.html)

    def test_all_three_reproduction_files_are_pinned(self):
        expected = {
            f"{ROOT}{REVISION}/research/socorro/{name}" for name in FILES
        }
        pinned = {
            url for url in self.parsed.hrefs
            if url.startswith(f"{ROOT}{REVISION}/research/socorro/")
        }
        self.assertEqual(pinned, expected)

    def test_snapshot_is_identified_as_immutable(self):
        self.assertIn("reproduction-snapshot", self.parsed.ids)
        self.assertIn(REVISION, self.html)
        self.assertIn("Source availability is distinct from executing", self.html)

    def test_current_source_and_evidence_boundary_remain(self):
        self.assertIn(
            "https://github.com/nicholaskouns-create/Identity/tree/main/research/socorro",
            self.parsed.hrefs,
        )
        self.assertIn("Lean, Coq and Verilog compiler execution remain unverified.", self.html)


if __name__ == "__main__":
    unittest.main()
