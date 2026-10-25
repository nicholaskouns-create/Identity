"""GitHub Pages adapter: renders a route's receipts as a static proof browser.

LIVE as a generator. It writes an HTML file; publishing it is a separate,
authorized deployment step and is not performed here.
"""
from __future__ import annotations

import html
import json
from pathlib import Path
from typing import Any

NAME = "pages"
MODE = "LIVE (generator) / PUBLISH-DEFERRED"


def status() -> dict:
    return {"adapter": NAME, "mode": MODE,
            "publishes": "no — writes a file; deployment is a separate authorized step"}


def render(route: dict[str, Any], passports: list[dict[str, Any]],
           chain_ok: bool, chain_notes: list[str], out: str | Path) -> Path:
    rows = []
    for p in passports:
        cls = {"PASS": "pass", "FAIL": "fail", "PENDING": "pend",
               "BLOCKED": "blocked"}[p["verification_status"]]
        rows.append(
            f'<tr><td>{html.escape(p["station"] or "—")}</td>'
            f'<td><code>{html.escape(p["theorem_id"])}</code></td>'
            f'<td class="{cls}">{p["verification_status"]}</td>'
            f'<td>{html.escape(p["evidence_class"])}</td>'
            f'<td>{html.escape(p["proof_system"])} '
            f'{html.escape(p["compiler_version"] or "—")}</td>'
            f'<td><code>{html.escape(p["receipt_hash"][:16])}…</code></td>'
            f'<td><code>{html.escape(p["parent_receipt_hash"][:16])}…</code></td></tr>')
    notes = "".join(f"<li>{html.escape(n)}</li>" for n in chain_notes)
    doc = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Monorail route {html.escape(route['route_id'])}</title>
<style>
:root{{color-scheme:dark light}}
body{{background:#0c1724;color:#e8eef6;font:14px/1.6 ui-monospace,Menlo,monospace;margin:0;padding:24px}}
h1{{font-size:20px;margin:0 0 4px}} .sub{{color:#9fb2c9;margin:0 0 20px}}
table{{border-collapse:collapse;width:100%;font-size:13px}}
th,td{{border:1px solid #24364f;padding:6px 9px;text-align:left}}
th{{color:#d8a94a;font-weight:500}}
.pass{{color:#5fcf9e}} .fail{{color:#e86a6a}} .pend{{color:#e0975a}} .blocked{{color:#9fb2c9}}
.chain{{margin-top:20px;border-left:2px solid {'#5fcf9e' if chain_ok else '#e86a6a'};padding-left:12px}}
code{{color:#d8a94a}} .wrap{{overflow-x:auto}}
</style></head><body>
<h1>Route {html.escape(route['route_id'])} · {html.escape(route['status'])}</h1>
<p class="sub">{html.escape(route.get('title', ''))} &middot; commit
<code>{html.escape(route.get('source_commit', '?')[:12])}</code> &middot;
generated {html.escape(route.get('generated_utc', ''))}</p>
<div class="wrap"><table>
<tr><th>Station</th><th>Theorem</th><th>Status</th><th>Fare</th>
<th>Compiler</th><th>Receipt</th><th>Parent</th></tr>
{''.join(rows)}
</table></div>
<div class="chain"><b>Hash chain: {'INTACT' if chain_ok else 'BROKEN'}</b><ul>{notes}</ul></div>
<p class="sub">Transfer does not upgrade evidence. A receipt hash proves integrity
only &mdash; never authorship, never mathematical correctness.</p>
</body></html>"""
    path = Path(out)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(doc)
    return path
