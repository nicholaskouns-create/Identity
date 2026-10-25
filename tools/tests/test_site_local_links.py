"""Offline regression checks for links between published Mnemosyne site files.

Checks only relative HTML href/src targets and HTML fragment anchors.
External URLs, runtime-generated links, and browser behavior are out of scope.
Run: python -m unittest tools.tests.test_site_local_links -v
"""

from html.parser import HTMLParser
from pathlib import Path
import unittest
from urllib.parse import unquote, urlsplit


SITE = Path(__file__).resolve().parents[2] / "site"


class References(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.links = []
        self.anchors = set()

    def handle_starttag(self, tag, attrs):
        for name, value in attrs:
            if value is None:
                continue
            if name == "id" or (tag == "a" and name == "name"):
                self.anchors.add(value)
            if name in ("href", "src"):
                self.links.append((name, value))


class SiteLocalLinksTest(unittest.TestCase):
    def test_relative_links_and_fragments(self):
        pages = sorted(SITE.glob("*.html"))
        self.assertTrue(pages, "No HTML pages found in site/")
        site_root = SITE.resolve()
        parsed_pages = {}

        def read_page(path):
            if path not in parsed_pages:
                parser = References()
                parser.feed(path.read_text(encoding="utf-8"))
                parsed_pages[path] = parser
            return parsed_pages[path]

        for source in pages:
            for attribute, raw in read_page(source).links:
                url = urlsplit(raw)
                # Absolute, protocol-relative, mailto, and data URLs are not
                # local site assets and cannot be checked without network access.
                if url.scheme or url.netloc or raw.startswith("//"):
                    continue
                if url.path.startswith("/"):
                    continue  # Root-relative links may leave this Pages subsite.
                with self.subTest(page=source.name, attribute=attribute, url=raw):
                    target = (source.parent / unquote(url.path)).resolve() if url.path else source.resolve()
                    self.assertTrue(
                        target.is_relative_to(site_root),
                        f"Relative link escapes site/: {source.name} -> {raw}",
                    )
                    if target.is_dir():
                        target /= "index.html"
                    self.assertTrue(
                        target.is_file(),
                        f"Missing local target: {source.name} -> {raw}",
                    )
                    if url.fragment and target.suffix.lower() in (".html", ".htm"):
                        fragment = unquote(url.fragment)
                        self.assertIn(
                            fragment,
                            read_page(target).anchors,
                            f"Missing HTML fragment: {source.name} -> {raw}",
                        )


if __name__ == "__main__":
    unittest.main()
