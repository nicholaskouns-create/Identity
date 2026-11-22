#!/usr/bin/env python3
"""Place the Grid doorway on every published City surface and the Grid lead
card on the hub pages, then write grid/data/surfaces.json (the survey).

Idempotent: blocks are delimited by KKP-GRID-DOOR-1 / KKP-GRID-LEAD-1 markers
and replaced in place on re-runs. Only files each repository actually
publishes are touched.

  python3 tools/grid/install_door.py --root /path/to/checkouts [--dry-run]
"""
import argparse
import json
import re
from pathlib import Path

GRID = "https://nicholaskouns-create.github.io/Identity/grid/"
SITE = "https://nicholaskouns-create.github.io"

# repo directory, Pages base path, published subdirectory, extra excludes
REPOS = [
    ("identity", "/Identity/", "", {"grid/index.html", "tools/grid/share_card.html"}),
    ("nicholaskouns-create.github.io", "/", "", set()),
    ("e47-kartekeya", "/E47-Kartekeya/", "website", set()),
    ("tower", "/tower/", "", set()),
    ("time", "/Time/", "", set()),
    ("bi-a7-semimetal-proofs", "/bi-a7-semimetal-proofs/", "app", set()),
    ("auth-kernel", "/auth-kernel/", "", set()),
    ("e47-electroweak-identities", "/E47-Electroweak-Identities/", "", set()),
    ("kiliani", "/Kiliani/", "docs", set()),
]
TEMPLATES = [("e47-kartekeya", "scripts/templates/city-portal.html")]

DOOR = (
    '<!-- KKP-GRID-DOOR-1 · doorway to Grid, the live U.S. power-grid monitor (Identity/tools/grid/install_door.py) -->\n'
    f'<a id="kkp-grid-door" href="{GRID}" title="Grid · live U.S. power-grid monitor with a certified spectral auditor" '
    'aria-label="Open Grid, the live U.S. power-grid monitor" '
    'style="position:fixed;left:12px;bottom:12px;z-index:2147483000;display:inline-flex;align-items:center;gap:7px;'
    'padding:7px 11px;border-radius:999px;background:rgba(9,11,13,.86);border:1px solid rgba(110,223,212,.38);'
    'color:#6edfd4;font:600 10px/1 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;letter-spacing:.16em;'
    'text-decoration:none;-webkit-backdrop-filter:blur(8px);backdrop-filter:blur(8px);box-shadow:0 6px 24px rgba(0,0,0,.35)">GRID</a>\n'
    f'<script src="{GRID}door.js" defer></script>\n'
    '<!-- /KKP-GRID-DOOR-1 -->\n'
)

LEAD_CSS = (
    '.kkp-grid-lead{grid-column:1/-1;display:grid;grid-template-columns:minmax(0,1.05fr) minmax(0,1fr);gap:26px;align-items:center;'
    'margin:28px 0;padding:18px;border:1px solid rgba(110,223,212,.32);border-radius:10px;'
    'background:linear-gradient(180deg,rgba(17,24,28,.94),rgba(9,11,13,.94));color:#edf2ef;text-decoration:none;'
    'box-shadow:0 18px 50px rgba(0,0,0,.35);transition:border-color .2s,transform .2s;text-align:left}'
    '.kkp-grid-lead:hover,.kkp-grid-lead:focus-visible{border-color:rgba(110,223,212,.85);transform:translateY(-2px)}'
    '.kkp-grid-lead img{width:100%;height:auto;display:block;border-radius:6px;border:1px solid rgba(110,223,212,.2)}'
    '.kkp-grid-lead-k{display:block;font:500 11px/1.2 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.18em;text-transform:uppercase;color:#6edfd4;margin-bottom:10px}'
    '.kkp-grid-lead-t{display:block;font:400 clamp(34px,5vw,52px)/1 Newsreader,"Iowan Old Style",Georgia,serif;letter-spacing:-.02em;color:#efeae0;margin-bottom:10px}'
    '.kkp-grid-lead-d{display:block;color:#a7b1b4;font:400 15.5px/1.5 "IBM Plex Sans",system-ui,-apple-system,sans-serif;max-width:52ch}'
    '.kkp-grid-lead-go{display:inline-block;margin-top:14px;font:500 12px/1 ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.14em;color:#c1e8ce}'
    '@media(max-width:760px){.kkp-grid-lead{grid-template-columns:1fr}}'
    '@media(prefers-reduced-motion:reduce){.kkp-grid-lead{transition:none}}'
)
LEAD = (
    '<!-- KKP-GRID-LEAD-1 · Grid leads this hub (Identity/tools/grid/install_door.py) -->\n'
    f'<style>{LEAD_CSS}</style>\n'
    f'<a class="kkp-grid-lead" href="{GRID}">\n'
    f'  <img src="{GRID}cover-grid.jpg" width="1104" height="684" loading="lazy" decoding="async" '
    'alt="Grid cover art: the contiguous United States drawn in light from 9,581 generating plants, coloured by fuel">\n'
    '  <span><span class="kkp-grid-lead-k">◇ Live instrument · Grid</span><span class="kkp-grid-lead-t">Grid</span>'
    '<span class="kkp-grid-lead-d">The U.S. power grid, live from public sources, on night-light, satellite and 3D terrain maps you can fly '
    'from your own GPS position, with a certified spectral auditor that refuses what a corrupted topology file would pass.</span>'
    '<span class="kkp-grid-lead-go">OPEN GRID ↗</span></span>\n'
    '</a>\n'
    '<!-- /KKP-GRID-LEAD-1 -->\n'
)

# Pages whose own policy forbids runtime script imports (NOESIS intake/discovery:
# "No source scripts imported at runtime") or that carry a strict CSP get the
# static link only: no script, and no inline style where CSP would block it.
DOOR_LINK_ONLY = DOOR.replace(f'<script src="{GRID}door.js" defer></script>\n', '')
DOOR_PLAIN = (
    '<!-- KKP-GRID-DOOR-1 · doorway to Grid (link only: this page forbids runtime scripts and inline styles) -->\n'
    f'<p class="kkp-grid-door-plain"><a id="kkp-grid-door" href="{GRID}">Grid · live U.S. power-grid monitor ↗</a></p>\n'
    '<!-- /KKP-GRID-DOOR-1 -->\n'
)


def door_for(rel, text):
    if re.search(r'http-equiv="Content-Security-Policy"', text, re.I):
        return DOOR_PLAIN
    if "noesis/" in rel:
        return DOOR_LINK_ONLY
    return DOOR


BLOCK = {name: re.compile(rf"<!-- {name} .*?<!-- /{name} -->\n?", re.S) for name in ("KKP-GRID-DOOR-1", "KKP-GRID-LEAD-1")}


def strip(text, name):
    return BLOCK[name].sub("", text)


def insert_door(text, rel=""):
    text = strip(text, "KKP-GRID-DOOR-1")
    door = door_for(rel, text)
    m = list(re.finditer(r"</body\s*>", text, re.I))
    if m:
        i = m[-1].start()
        return text[:i] + door + text[i:]
    m = list(re.finditer(r"</html\s*>", text, re.I))
    if m:
        i = m[-1].start()
        return text[:i] + door + text[i:]
    return text.rstrip("\n") + "\n" + door


def wrapped(open_tag="", close_tag=""):
    """The lead block with any wrapper kept inside its markers, so re-runs replace it whole."""
    head, rest = LEAD.split("\n", 1)
    body, tail = rest.rsplit("<!-- /KKP-GRID-LEAD-1 -->", 1)
    return f"{head}\n{open_tag}{body}{close_tag}<!-- /KKP-GRID-LEAD-1 -->\n"


def lead_identity(text):
    m = re.search(r'<header class="mast wrap"[^>]*>', text)
    j = text.find("\n", text.find("</header>", m.end())) + 1
    return text[:j] + wrapped('<div class="wrap">\n', "</div>\n") + text[j:]


def lead_user_root(text):
    m = re.search(r'<div class="doors">\s*\n', text)
    return text[:m.end()] + wrapped() + text[m.end():]


def lead_user_website(text):
    i = text.find('<nav class="route-grid"')
    return text[:i] + wrapped() + text[i:]


def lead_e47_home(text):
    s = text.find('<section class="atlas-hero atlas-page"')
    e = text.find("</section>", s)
    k = text.rfind("</div>", s, e)
    return text[:k] + wrapped() + text[k:]


def lead_flowshield(text):
    s = text.find('<section class="research-hero"')
    e = text.find("\n", text.find("</section>", s)) + 1
    return text[:e] + wrapped() + text[e:]


HUBS = {
    ("identity", "index.html"): lead_identity,
    ("nicholaskouns-create.github.io", "index.html"): lead_user_root,
    ("nicholaskouns-create.github.io", "website/index.html"): lead_user_website,
    ("e47-kartekeya", "website/index.html"): lead_e47_home,
    ("nicholaskouns-create.github.io", "flowshield.html"): lead_flowshield,
}


def title_of(text):
    m = re.search(r"<title>(.*?)</title>", text, re.S | re.I)
    return re.sub(r"\s+", " ", m.group(1)).strip() if m else ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    root = Path(a.root)
    survey = []
    changed = 0
    for repo, base, sub, excl in REPOS:
        rdir = root / repo
        pub = rdir / sub if sub else rdir
        for f in sorted(pub.rglob("*.html")):
            rel_repo = f.relative_to(rdir).as_posix()
            if "/.git/" in f.as_posix() or "node_modules" in rel_repo or rel_repo in excl:
                continue
            rel_pub = f.relative_to(pub).as_posix()
            url = SITE + base + (rel_pub[:-10] if rel_pub.endswith("index.html") else rel_pub)
            raw = f.read_bytes()
            text = raw.decode("utf-8")
            new = insert_door(text, rel_repo)
            hub = HUBS.get((repo, rel_repo))
            if hub:
                new = hub(strip(new, "KKP-GRID-LEAD-1"))
            if new != text:
                changed += 1
                if not a.dry_run:
                    f.write_bytes(new.encode("utf-8"))
            kind = "plain" if door_for(rel_repo, text) is DOOR_PLAIN else "link-only" if door_for(rel_repo, text) is DOOR_LINK_ONLY else "door"
            survey.append({"repo": repo, "path": rel_repo, "url": url, "title": title_of(text), "door": kind, "lead": bool(hub)})
    for repo, rel in TEMPLATES:
        f = root / repo / rel
        text = f.read_text(encoding="utf-8")
        new = insert_door(text)
        if new != text and not a.dry_run:
            f.write_text(new, encoding="utf-8")
        survey.append({"repo": repo, "path": rel, "url": None, "title": title_of(text) + " (template)", "door": "door", "lead": False})
    published = [s for s in survey if s["url"]]
    out = {"schema": "KKP-GRID-SURFACES-1.0", "grid": GRID, "count": len(published),
           "templates": [s["repo"] + "/" + s["path"] for s in survey if not s["url"]],
           "by_repo": {r[0]: sum(1 for s in published if s["repo"] == r[0]) for r in REPOS}, "surfaces": survey}
    if not a.dry_run:
        (root / "identity" / "grid" / "data" / "surfaces.json").write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"changed": changed, "published": len(published), "templates": out["templates"], "by_repo": out["by_repo"], "hubs": sum(1 for s in survey if s["lead"])}, indent=1))


if __name__ == "__main__":
    main()
