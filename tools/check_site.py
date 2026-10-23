"""Validate the published artifact does not accidentally include private data."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
SITE=ROOT/"site"
ALLOWED={"index.html","mnemosyne.js","README.md"}
actual={p.name for p in SITE.iterdir() if p.is_file()}
assert actual<=ALLOWED, f"Unexpected publish files: {actual-ALLOWED}"
html=(SITE/"index.html").read_text(encoding="utf-8")
js=(SITE/"mnemosyne.js").read_text(encoding="utf-8")
assert '<script type="module" src="./mnemosyne.js"></script>' in html
assert "indexedDB.open" in js and "crypto.subtle.digest('SHA-256'" in js
assert "supabase.co" not in html+js
assert not re.search(r"sb_secret_|service_role|BEGIN PRIVATE KEY",html+js)
print("SITE_STATIC_CHECK_PASS")
