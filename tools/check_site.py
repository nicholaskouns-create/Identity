"""Validate the published artifact does not accidentally include private data."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
SITE=ROOT/"site"
ALLOWED={"index.html","mnemosyne.js","sync.js","sync-merge.js","forge-engine.js","forge-ui.js","ablation.html","ablation.js","ablation-math.mjs","ablation.test.mjs","og.png","README.md","MIGRATION.md","e47-spectral-advantages.html","socorro-stochastic.html"}
TEXT_SUFFIXES={".html",".js",".md",".mjs"}
actual={p.name for p in SITE.iterdir() if p.is_file()}
assert actual<=ALLOWED, f"Unexpected publish files: {actual-ALLOWED}"
html=(SITE/"index.html").read_text(encoding="utf-8")
assert 'href="./e47-spectral-advantages.html"' in html, "Homepage must link to the published E47 certificate"
assert 'href="socorro-stochastic.html"' in html, "Homepage must link to the published Socorro stochastic research page"
research_section = html.split('<section id="research-links"', 1)[1].split("</section>", 1)[0]
assert 'href="socorro-stochastic.html"' in research_section, "Socorro link must remain inside the main research navigation"
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
# Guard the independently published ablation explorer's keyboard navigation.
# The result panel is initially hidden, but the main landmark must remain
# available while archived data loads or when loading fails.
ablation_html = (SITE/"ablation.html").read_text(encoding="utf-8")
ablation_landmarks = AccessibilityLandmarks()
ablation_landmarks.feed(ablation_html)
assert len(ablation_landmarks.main_ids) == 1, "Ablation explorer needs one main landmark"
assert ablation_landmarks.main_ids == ["ablation-main"], "Ablation main landmark ID changed"
assert ablation_landmarks.main_tabindexes == ["-1"], "Ablation skip target must be focusable"
assert ablation_landmarks.skip_targets == ["#ablation-main"], "Ablation skip link target mismatch"
assert ablation_landmarks.headings.count("h1") == 1, "Ablation explorer needs exactly one h1"
assert ablation_landmarks.headings.index("h1") < ablation_landmarks.headings.index("h2"), "Ablation heading order regressed"
assert ".skip-link:focus" in ablation_html, "Ablation skip link must appear on focus"
assert '<div id="data-panel" hidden>' in ablation_html, "Ablation results must stay hidden until loaded"
assert '<div id="bars" role="group" aria-labelledby="overview"></div>' in ablation_html, "Chart group must expose its captions and values"

# Check the dynamic chart and paired-table semantics at the source level.
# This does not replace a screen-reader or browser interaction audit.
ablation_js = (SITE/"ablation.js").read_text(encoding="utf-8")
assert 'id="left-auc-header"' in ablation_html and 'id="right-auc-header"' in ablation_html, "Paired column headers need stable IDs"
assert "track.setAttribute('role', 'img')" in ablation_js, "Chart bars must expose an accessible graphic role"
assert "track.setAttribute('aria-label'," in ablation_js, "Chart bars must have numeric accessible names"
assert "$('left-auc-header').textContent" in ablation_js, "Left column heading must follow selection"
assert "$('right-auc-header').textContent" in ablation_js, "Right column heading must follow selection"
assert ablation_js.count("el(index === 0 ? 'th' : 'td', value)") == 2, "Aggregate and paired tables need row header cells"
assert ablation_js.count("cell.scope = 'row'") == 2, "Row header cells must declare their scope"

print("SITE_STATIC_CHECK_PASS")
