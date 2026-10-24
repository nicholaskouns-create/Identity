"""Validate the published artifact does not accidentally include private data."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
SITE=ROOT/"site"
ALLOWED={"index.html","mnemosyne.js","sync.js","sync-merge.js","forge-engine.js","forge-ui.js","ablation.html","ablation.js","ablation-math.mjs","ablation.test.mjs","og.png","README.md","MIGRATION.md"}
TEXT_SUFFIXES={".html",".js",".md",".mjs"}
actual={p.name for p in SITE.iterdir() if p.is_file()}
assert actual<=ALLOWED, f"Unexpected publish files: {actual-ALLOWED}"
html=(SITE/"index.html").read_text(encoding="utf-8")
published="\n".join((SITE/name).read_text(encoding="utf-8") for name in sorted(actual) if Path(name).suffix in TEXT_SUFFIXES)
assert '<script type="module" src="./mnemosyne.js"></script>' in html
assert '<script type="module" src="./sync.js"></script>' in html
assert '<script type="module" src="./forge-ui.js"></script>' in html
assert "https://nicholaskouns-create.github.io/Identity/site/og.png" in html
assert "from './forge-engine.js'" in (SITE/"forge-ui.js").read_text(encoding="utf-8")
assert "from './sync-merge.js'" in (SITE/"sync.js").read_text(encoding="utf-8")
assert "indexedDB.open" in published and "crypto.subtle.digest('SHA-256'" in published
assert "BroadcastChannel" in (SITE/"mnemosyne.js").read_text(encoding="utf-8")
assert "https://gpkjvihkyectnenvnbng.supabase.co" in (SITE/"sync.js").read_text(encoding="utf-8")
assert "sb_publishable_" in (SITE/"sync.js").read_text(encoding="utf-8")
assert "Optional email sync" in html
assert "mnemosyne_private" not in published
assert not re.search(r"sb_secret_|service_role|BEGIN PRIVATE KEY", published)
# Guard the keyboard-navigation landmarks added to the archive homepage.
# This is a source-level regression check, not a browser accessibility audit.
from html.parser import HTMLParser

class AccessibilityLandmarks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.headings = []
        self.main_ids = []
        self.skip_targets = []
        self.main_tabindexes = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if attrs.get("id"):
            self.ids.add(attrs["id"])
        if tag in ("h1", "h2"):
            self.headings.append(tag)
        if tag == "main":
            self.main_ids.append(attrs.get("id"))
            self.main_tabindexes.append(attrs.get("tabindex"))
        if tag == "a" and "skip-link" in attrs.get("class", "").split():
            self.skip_targets.append(attrs.get("href"))

landmarks = AccessibilityLandmarks()
landmarks.feed(html)
assert len(landmarks.main_ids) == 1, "Homepage needs exactly one main landmark"
assert landmarks.headings.count("h1") == 1, "Homepage needs exactly one h1"
assert "h2" in landmarks.headings and landmarks.headings.index("h1") < landmarks.headings.index("h2"), "Heading order regressed"
assert landmarks.skip_targets == ["#" + landmarks.main_ids[0]], "Skip link must target the main landmark"
assert landmarks.main_ids[0] in landmarks.ids, "Skip target must exist"
assert landmarks.main_tabindexes == ["-1"], "Main target must support programmatic focus"
assert ".skip-link:focus" in html, "Skip link must become visible on keyboard focus"
print("SITE_STATIC_CHECK_PASS")
