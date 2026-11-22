#!/usr/bin/env python3
"""Render the Grid share card (grid/og-grid.png, 1200x630) and its cover art
(grid/cover-grid.png) from tools/grid/share_card.html with headless Chromium,
then check glyph coverage so no character falls back to a missing glyph.

  python3 tools/grid/render_share_card.py [--chrome /usr/bin/google-chrome]
"""
import argparse
import functools
import http.server
import re
import threading
from pathlib import Path

from fontTools.ttLib import TTFont
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "grid" / "fonts"


def serve():
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT))
    handler.log_message = lambda *a, **k: None
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


def glyph_check(html):
    text = re.sub(r"<[^>]+>", " ", html.split("<script>")[0])
    text += " ".join(re.findall(r"'([^']*)'|`([^`]*)`", html.split("<script>")[1]).__str__())
    chars = {c for c in text if ord(c) > 126}
    covered = set()
    for f in FONTS.glob("*.woff2"):
        covered |= set(TTFont(str(f)).getBestCmap().keys())
    missing = sorted(c for c in chars if ord(c) not in covered and not c.isspace())
    return missing


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chrome", default=None)
    a = ap.parse_args()
    html = (ROOT / "tools" / "grid" / "share_card.html").read_text(encoding="utf-8")
    missing = glyph_check(html)
    if missing:
        raise SystemExit(f"glyphs without a font: {missing}")
    srv = serve()
    url = f"http://127.0.0.1:{srv.server_address[1]}/tools/grid/share_card.html"
    with sync_playwright() as p:
        kw = {"args": ["--no-sandbox"]}
        if a.chrome:
            kw["executable_path"] = a.chrome
        b = p.chromium.launch(**kw)
        for scale, out in ((1, "og-grid.png"), (2, "og-grid@2x.png")):
            pg = b.new_page(viewport={"width": 1200, "height": 630}, device_scale_factor=scale)
            pg.goto(url)
            info = pg.evaluate("window.render()")
            pg.wait_for_timeout(300)
            pg.screenshot(path=str(ROOT / "grid" / out), clip={"x": 0, "y": 0, "width": 1200, "height": 630})
            if scale == 2:
                pg.locator("#art").screenshot(path=str(ROOT / "grid" / "cover-grid.png"))
            print(out, info)
        b.close()
    srv.shutdown()


if __name__ == "__main__":
    main()
