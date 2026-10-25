#!/usr/bin/env python3
"""Render a route manifest as a GitHub step summary.

Lives in a file rather than an inline heredoc: a heredoc terminator indented
inside a YAML `run:` block is not recognised by the shell, which is what broke
CI run #5. A script has no quoting or indentation layer to get wrong.
"""
import json
import sys
from pathlib import Path


def render(manifest: dict) -> str:
    m, out = manifest, []
    out.append(f"## Route {m['route_id']} — {m['status']}\n")
    out.append(f"- commit `{m['source_commit'][:12]}`")
    out.append(f"- environment lock `{m['environment_lock_hash'][:12]}`")
    out.append(f"- hash chain: {'INTACT' if m['chain_intact'] else 'BROKEN'}")
    out.append(f"- open defects: {m['open_defects']}")
    led = m.get("ledger", {})
    out.append(f"- ledger: {led.get('mode', '?')} — "
               f"{led.get('statements_emitted', 0)} statements emitted, "
               f"{'executed' if led.get('executed') else 'none executed'}")
    rec = m.get("citizen_reconciliation")
    if rec:
        out.append(f"- citizens: {rec['consistent']} consistent, "
                   f"{rec['unregistered']} unregistered, "
                   f"{rec['upgrades_requiring_approval']} upgrade(s) needing approval")
        if rec["promotion_blocked"]:
            out.append("- **promotion blocked**: transfer does not upgrade evidence")
    out.append("\n| Station | Theorem | Status | Fare |")
    out.append("|---|---|---|---|")
    for s in m["stations"]:
        out.append(f"| {s['station']} | `{s['theorem_id']}` | "
                   f"{s['status']} | {s['evidence_class']} |")
    out.append("\n_Transfer does not upgrade evidence._")
    return "\n".join(out) + "\n"


def main() -> int:
    paths = sorted(Path("evidence/routes").glob("*/route_manifest.json"))
    if not paths:
        print("no route manifest found", file=sys.stderr)
        return 1
    text = "\n".join(render(json.loads(p.read_text())) for p in paths)
    target = sys.argv[1] if len(sys.argv) > 1 else None
    if target:
        with open(target, "a") as fh:
            fh.write(text)
    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
