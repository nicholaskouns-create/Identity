"""Regression checks for the Mnemosyne homepage section navigation.

These are static source checks, not a browser or screen-reader audit.
"""
from html.parser import HTMLParser
from pathlib import Path
import unittest


SITE = Path(__file__).resolve().parents[2] / "site" / "index.html"
EXPECTED = {
    "#live": "Live",
    "#sync": "Sync",
    "#record-section": "Record",
    "#archive-section": "Archive",
    "#research-links": "Research",
    "#mnemosyne-forge": "Forge",
}


class SectionNavParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = []
        self.nav_labels = []
        self.in_section_nav = False
        self.nav_links = []
        self.current_href = None

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if "id" in attributes:
            self.ids.append(attributes["id"])
        if tag == "nav" and attributes.get("class") == "site-nav":
            self.nav_labels.append(attributes.get("aria-label"))
            self.in_section_nav = True
        elif tag == "a" and self.in_section_nav:
            self.current_href = attributes.get("href")
            self.nav_links.append([self.current_href, ""])

    def handle_data(self, data):
        if self.in_section_nav and self.current_href is not None:
            self.nav_links[-1][1] += data

    def handle_endtag(self, tag):
        if tag == "a":
            self.current_href = None
        elif tag == "nav":
            self.in_section_nav = False


class SectionNavigationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.html = SITE.read_text(encoding="utf-8")
        cls.parser = SectionNavParser()
        cls.parser.feed(cls.html)

    def test_navigation_is_named(self):
        self.assertEqual(self.parser.nav_labels, ["On this page"])

    def test_all_section_links_have_visible_names_and_targets(self):
        self.assertEqual(dict(self.parser.nav_links), EXPECTED)
        self.assertEqual(len(self.parser.nav_links), len(EXPECTED))
        for href in EXPECTED:
            self.assertEqual(self.parser.ids.count(href[1:]), 1, href)

    def test_keyboard_focus_is_visible(self):
        self.assertIn(".site-nav a:focus-visible", self.html)
        self.assertIn("outline:3px solid", self.html)

    def test_existing_skip_link_remains(self):
        self.assertIn('href="#main-content">Skip to main content</a>', self.html)
        self.assertIn('id="main-content" tabindex="-1"', self.html)


if __name__ == "__main__":
    unittest.main()
