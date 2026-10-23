"""Validate the published artifact does not accidentally include private data."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
SITE=ROOT/"site"
ALLOWED={"index.html","mnemosyne.js","forge-engine.js","forge-ui.js","README.md","MIGRATION.md"}
actual={p.name for p in SITE.iterdir() if p.is_file()}
assert actual<=ALLOWED, f"Unexpected publish files: {actual-ALLOWED}"
html=(SITE/"index.html").read_text(encoding="utf-8")
published="\n".join((SITE/name).read_text(encoding="utf-8") for name in sorted(actual))
assert '<script type="module" src="./mnemosyne.js"></script>' in html
assert '<script type="module" src="./forge-ui.js"></script>' in html
assert "from './forge-engine.js'" in (SITE/"forge-ui.js").read_text(encoding="utf-8")
assert "indexedDB.open" in published and "crypto.subtle.digest('SHA-256'" in published
assert "supabase.co" not in published
assert not re.search(r"sb_secret_|service_role|BEGIN PRIVATE KEY", published)
print("SITE_STATIC_CHECK_PASS")
