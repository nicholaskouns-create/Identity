#!/usr/bin/env python3
"""Compile every self-contained E47 Lean and Coq proof and write the site page.

The Mathlib file is recorded as not run. A compiler failure is still written
into the page; the process then exits 1.
"""
from __future__ import annotations

import html
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEAN_FILES = [
    "formal/e47/E47Spectral.lean",
    "formal/e47/E47WeightAlgebra.lean",
    "formal/e47/unified/Core47.lean",
    "formal/e47/unified/RGFixed.lean",
    "formal/e47/unified/Retention.lean",
    "formal/e47/unified/Clock.lean",
    "formal/e47/unified/EncodedOracle.lean",
    "formal/e47/unified/Spin2Generators.lean",
    "formal/e47/unified/Tensor125.lean",
    "formal/e47/unified/RankNullity47.lean",
    "formal/e47/unified/E47Bridge.lean",
]
COQ_FILES = [
    "formal/e47/E47Spectral.v",
    "formal/e47/E47WeightAlgebra.v",
    "formal/e47/TowerIdentity.v",
    "formal/e47/unified/Core47.v",
    "formal/e47/unified/RGFixed.v",
    "formal/e47/unified/Retention.v",
    "formal/e47/unified/Clock.v",
    "formal/e47/unified/EncodedOracle.v",
    "formal/e47/unified/Spin2Generators.v",
    "formal/e47/unified/Tensor125.v",
    "formal/e47/unified/RankNullity47.v",
    "formal/e47/unified/E47Bridge.v",
]
PYTHON_FILES = [
    "simulation/validate_e47.py",
    "validation/e47_tensor_bracket_trace_exact.py",
    "validation/e47_rank_nullity_exact.py",
]
SKIPPED = [
    (
        "formal/e47/E47ConcreteMatrix.lean",
        "Imports Mathlib. This run does not build Mathlib, and the file is not in scripts/validate-formal-local.sh.",
    )
]


def version_of(cmd: list[str]) -> str:
    try:
        out = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return f"unavailable ({exc})"
    text = (out.stdout or out.stderr).strip().splitlines()
    return text[0] if text else f"exit {out.returncode}"


def compile_one(kind: str, rel: str, compiler: list[str]) -> dict:
    src = ROOT / rel
    if not src.is_file():
        return {"kind": kind, "file": rel, "code": 127, "seconds": 0, "log": "file missing"}
    work = Path(tempfile.mkdtemp(prefix="e47-"))
    try:
        dest = work / src.name
        shutil.copy(src, dest)
        started = time.monotonic()
        proc = subprocess.run(
            compiler + [src.name],
            cwd=work,
            capture_output=True,
            text=True,
            timeout=900,
        )
        seconds = int(time.monotonic() - started)
        log = (proc.stdout + proc.stderr).strip()
        return {"kind": kind, "file": rel, "code": proc.returncode, "seconds": seconds, "log": log}
    except subprocess.TimeoutExpired as exc:
        log = ((exc.stdout or "") + (exc.stderr or "")).strip() + "\nTIMEOUT after 900s"
        return {"kind": kind, "file": rel, "code": 124, "seconds": 900, "log": log}
    finally:
        shutil.rmtree(work, ignore_errors=True)


def run_python(rel: str) -> dict:
    started = time.monotonic()
    proc = subprocess.run(
        [sys.executable, str(ROOT / rel)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=900,
    )
    seconds = int(time.monotonic() - started)
    log = (proc.stdout + proc.stderr).strip()
    return {"kind": "python", "file": rel, "code": proc.returncode, "seconds": seconds, "log": log}


def esc(text: str) -> str:
    return html.escape(text if text else "(no compiler output)")


def row(item: dict) -> str:
    mark = "ok" if item["code"] == 0 else "no"
    label = "exit 0" if item["code"] == 0 else f"exit {item['code']}"
    return (
        "<tr>"
        f"<td><code>{html.escape(item['file'])}</code></td>"
        f"<td class=\"{mark}\">{label}</td>"
        f"<td>{item['seconds']}s</td>"
        f"<td><pre>{esc(item['log'])}</pre></td>"
        "</tr>"
    )


def render(rows: list[dict], skipped: list[tuple[str, str]], meta: dict) -> str:
    failed = [item for item in rows if item["code"] != 0]
    summary = "Every compiled file exited 0." if not failed else f"{len(failed)} file(s) failed."
    body = "\n".join(row(item) for item in rows)
    skipped_rows = "\n".join(
        f"<tr><td><code>{html.escape(path)}</code></td><td class=\"no\">not run</td><td>—</td><td>{html.escape(why)}</td></tr>"
        for path, why in skipped
    )
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Full E47 validation results</title>
<meta name="description" content="Full compiler output for the self-contained E47 Lean and Coq proofs, plus the two Python checks.">
<link rel="canonical" href="https://nicholaskouns-create.github.io/Identity/site/proof/lean-coq/validation.html">
<meta property="og:title" content="Full E47 validation results">
<meta property="og:description" content="{html.escape(summary)} Source {html.escape(meta['sha'])}.">
<meta property="og:url" content="https://nicholaskouns-create.github.io/Identity/site/proof/lean-coq/validation.html">
<style>
  body{{margin:0;background:#e8ecf3;color:#101826;font:16px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}}
  main{{max-width:1100px;margin:0 auto;padding:28px 18px 72px}}
  h1{{font-size:clamp(28px,5vw,40px);line-height:1.1;margin:8px 0 12px}}
  a{{color:#2258d6}}
  table{{width:100%;border-collapse:collapse;background:#fff;font-size:14px}}
  th,td{{text-align:left;padding:8px 10px;border-bottom:1px solid #eef1f6;vertical-align:top}}
  th{{font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:#5d6879}}
  pre{{white-space:pre-wrap;word-break:break-word;margin:0;font:12px/1.4 ui-monospace,Menlo,Consolas,monospace}}
  .ok{{color:#0b7a53;font-weight:700}}
  .no{{color:#9a5600;font-weight:700}}
  .kicker{{letter-spacing:.16em;text-transform:uppercase;font-size:12px;font-weight:700;color:#5d6879}}
  .note{{background:#f4faf7;border-left:4px solid #0b7a53;padding:12px 14px}}
  code{{font-family:ui-monospace,Menlo,Consolas,monospace;font-size:.92em}}
</style>
</head>
<body>
<main>
<p class="kicker">Open-source Lean and Coq · rewritten by the site validation workflow</p>
<h1>Full validation results</h1>
<p><a href="./">Lean · Coq explainer</a> · <a href="record.html">25 October boards</a></p>
<p class="note">{html.escape(summary)} Source <a href="https://github.com/nicholaskouns-create/Identity/commit/{html.escape(meta['sha'])}"><code>{html.escape(meta['sha'])}</code></a>. {html.escape(meta['lean'])}. {html.escape(meta['coq'])}. {html.escape(meta['python'])}. GitHub Pages cannot run these compilers. The workflow installs them and replaces this page.</p>
<table>
<thead><tr><th>File</th><th>Result</th><th>Time</th><th>Compiler output</th></tr></thead>
<tbody>
{body}
{skipped_rows}
</tbody>
</table>
</main>
</body>
</html>
"""


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: site_validate.py OUTPUT.html", file=sys.stderr)
        return 2
    out = Path(sys.argv[1])
    sha = subprocess.run(
        ["git", "-C", str(ROOT), "rev-parse", "HEAD"],
        check=False, capture_output=True, text=True,
    ).stdout.strip() or "unknown"
    meta = {
        "sha": sha,
        "lean": version_of(["lean", "--version"]),
        "coq": version_of(["coqc", "--version"]),
        "python": version_of([sys.executable, "--version"]),
    }
    rows = [compile_one("lean", rel, ["lean"]) for rel in LEAN_FILES]
    rows += [compile_one("coq", rel, ["coqc", "-q"]) for rel in COQ_FILES]
    for rel in PYTHON_FILES:
        try:
            rows.append(run_python(rel))
        except subprocess.TimeoutExpired:
            rows.append({"kind": "python", "file": rel, "code": 124, "seconds": 900, "log": "TIMEOUT after 900s"})
    out.write_text(render(rows, SKIPPED, meta), encoding="utf-8")
    print(f"wrote {out}")
    return 0 if all(item["code"] == 0 for item in rows) else 1


if __name__ == "__main__":
    sys.exit(main())
