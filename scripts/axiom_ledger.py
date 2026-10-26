#!/usr/bin/env python3
"""
Axiom ledger gate for the E47 formal layer.

The existing workflows grep for `sorry` and `admit`. That catches an
unfinished proof but not a proof closed by `native_decide`, which compiles
the claim to native code, runs it, and mints a fresh axiom asserting the
result. A file can be green and still trust the compiler rather than the
kernel.

This script runs each Lean file, reads its `#print axioms` output, and
classifies every theorem:

    CLEAN     depends on no axioms at all
    STANDARD  only propext / Classical.choice / Quot.sound
    NATIVE    a native_decide axiom (Lean.ofReduceBool or *.native_decide.ax_*)
    BROKEN    sorryAx, or a user-declared axiom

BROKEN always fails. NATIVE fails too, unless the file is named in
--allow-native, which exists so a known gap can be carried explicitly and
counted rather than passing in silence. Remove a file from that list once
its proofs are kernel-checked and the gate tightens by itself.

Usage
  python3 scripts/axiom_ledger.py formal/e47/*.lean
  python3 scripts/axiom_ledger.py --allow-native formal/e47/E47ConcreteMatrix.lean \\
          --lean-cmd "lake env lean" formal/e47/E47ConcreteMatrix.lean
"""

from __future__ import annotations

import argparse
import re
import shlex
import subprocess
import sys
from pathlib import Path

STANDARD = {"propext", "Classical.choice", "Quot.sound"}
NATIVE_PAT = re.compile(r"ofReduceBool|native_decide\.ax|ofReduceNat")
AXLINE = re.compile(r"^'([^']+)' (?:depends on axioms: \[(.*)\]|does not depend on any axioms)")
SOURCE_BAD = re.compile(r"(^|\s)(sorry|admit)(\s|$)")
SOURCE_AXIOM = re.compile(r"^\s*axiom\s+\w+", re.M)


def classify(axioms: list[str]) -> str:
    if not axioms:
        return "CLEAN"
    if any("sorryAx" in a for a in axioms):
        return "BROKEN"
    if any(NATIVE_PAT.search(a) for a in axioms):
        return "NATIVE"
    if set(axioms) <= STANDARD:
        return "STANDARD"
    return "BROKEN"


def check_source(path: Path) -> list[str]:
    """Source-level problems that need no compiler."""
    problems = []
    text = path.read_text(encoding="utf-8", errors="ignore")
    for n, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith("--") or line.lstrip().startswith("/-"):
            continue
        if SOURCE_BAD.search(line):
            problems.append(f"{path}:{n}: unfinished proof ({line.strip()[:50]})")
    for m in SOURCE_AXIOM.finditer(text):
        problems.append(f"{path}: declares an axiom: {m.group(0).strip()}")
    return problems


def run_lean(path: Path, lean_cmd: str, timeout: int) -> tuple[int, str]:
    cmd = shlex.split(lean_cmd) + [str(path)]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout + p.stderr
    except subprocess.TimeoutExpired:
        return 124, f"TIMEOUT after {timeout}s"
    except FileNotFoundError:
        return 127, f"not found: {cmd[0]}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--lean-cmd", default="lean")
    ap.add_argument("--allow-native", action="append", default=[],
                    help="file permitted to carry native_decide axioms (tracked, not silent)")
    ap.add_argument("--timeout", type=int, default=2400)
    args = ap.parse_args()

    allow = {Path(a).name for a in args.allow_native}
    tally = {"CLEAN": 0, "STANDARD": 0, "NATIVE": 0, "BROKEN": 0}
    failures: list[str] = []
    native_tracked: list[str] = []

    print("=" * 78)
    print("E47 AXIOM LEDGER")
    print("=" * 78)

    for f in args.files:
        path = Path(f)
        if not path.exists():
            failures.append(f"{path}: missing")
            continue

        failures.extend(check_source(path))

        rc, out = run_lean(path, args.lean_cmd, args.timeout)
        if rc != 0:
            failures.append(f"{path}: did not compile (rc={rc}) {out.strip().splitlines()[0][:70] if out.strip() else ''}")
            print(f"\n  {path}  — DID NOT COMPILE")
            continue

        if "declaration uses 'sorry'" in out:
            failures.append(f"{path}: compiler reports a declaration uses sorry")

        rows = []
        for line in out.splitlines():
            m = AXLINE.match(line.strip())
            if not m:
                continue
            name, ax = m.group(1), m.group(2)
            axioms = [a.strip() for a in ax.split(",")] if ax else []
            verdict = classify(axioms)
            tally[verdict] += 1
            rows.append((name, verdict, axioms))
            if verdict == "BROKEN":
                failures.append(f"{path}: {name} -> {axioms}")
            elif verdict == "NATIVE":
                if path.name in allow:
                    native_tracked.append(f"{path.name}: {name}")
                else:
                    failures.append(f"{path}: {name} closed by native_decide (not kernel-checked)")

        flag = "  [native allowed here]" if path.name in allow else ""
        print(f"\n  {path}{flag}")
        if not rows:
            print("      compiled; no #print axioms statements")
        for name, verdict, axioms in rows:
            detail = "" if verdict == "CLEAN" else "  " + ", ".join(axioms)
            print(f"      {verdict:<9}{name}{detail}")

    print("\n" + "=" * 78)
    total = sum(tally.values())
    print(f"  {tally['CLEAN']} clean   {tally['STANDARD']} standard-axioms   "
          f"{tally['NATIVE']} native_decide   {tally['BROKEN']} broken   ({total} audited)")

    if native_tracked:
        print(f"\n  TRACKED GAP — {len(native_tracked)} theorem(s) closed by native_decide,")
        print("  permitted by --allow-native. These trust the Lean compiler and its")
        print("  evaluation, not the kernel. Convert to `decide` to remove the flag:")
        for t in native_tracked:
            print(f"      {t}")

    if failures:
        print(f"\n  FAILED — {len(failures)} problem(s):")
        for f in failures:
            print(f"      {f}")
        print("=" * 78)
        return 1

    print("\n  PASS")
    print("=" * 78)
    return 0


if __name__ == "__main__":
    sys.exit(main())
