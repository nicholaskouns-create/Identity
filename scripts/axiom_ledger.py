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
import os
import re
import shlex
import subprocess
import tempfile
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


def strip_comments(text: str) -> list[tuple[int, str]]:
    """Source lines with comments removed, as (line number, code).

    Lean block comments nest, and a line inside one does not have to start
    with `/-`.  The previous version skipped only lines *beginning* with a
    comment marker, so prose inside a header block was scanned as code and any
    file whose documentation used the word `sorry` to describe its own state
    was reported as having an unfinished proof.  That is a false positive on
    exactly the files that are being most honest about themselves.
    """
    out, depth, i, line_no, cur = [], 0, 0, 1, []
    while i < len(text):
        two = text[i:i + 2]
        if depth == 0 and two == "--":
            while i < len(text) and text[i] != "\n":
                i += 1
            continue
        if two == "/-":
            depth += 1; i += 2; continue
        if two == "-/" and depth > 0:
            depth -= 1; i += 2; continue
        ch = text[i]
        if ch == "\n":
            out.append((line_no, "".join(cur))); cur = []; line_no += 1
        elif depth == 0:
            cur.append(ch)
        i += 1
    out.append((line_no, "".join(cur)))
    return out


def check_source(path: Path) -> list[str]:
    """Source-level problems that need no compiler."""
    problems = []
    text = path.read_text(encoding="utf-8", errors="ignore")
    for n, line in strip_comments(text):
        if SOURCE_BAD.search(line):
            problems.append(f"{path}:{n}: unfinished proof ({line.strip()[:50]})")
    code = "\n".join(c for _, c in strip_comments(text))
    for m in SOURCE_AXIOM.finditer(code):
        problems.append(f"{path}: declares an axiom: {m.group(0).strip()}")
    return problems


LOCAL_IMPORT = re.compile(r"(?m)^\s*import\s+([A-Z][A-Za-z0-9_.]*)\s*$")


def build_local_deps(files: list[Path], lean_cmd: str, timeout: int, out_dir: Path) -> list[str]:
    """Compile every module that a file in this set imports from the same set.

    Several files import a sibling by bare module name (`import Tensor125`).
    Run by itself, `lean` has no search path and reports `unknown module
    prefix`, which the ledger then recorded as a compile failure - a statement
    about the gate, not about the file.  Building the siblings into one
    directory and putting it on LEAN_PATH lets those files be audited rather
    than merely blamed.  Returns the names it could not build.
    """
    by_name = {f.stem: f for f in files}
    wanted, failed = set(), []
    for f in files:
        for m in LOCAL_IMPORT.findall(f.read_text(encoding="utf-8", errors="ignore")):
            root = m.split(".")[0]
            if root in by_name:
                wanted.add(root)
    out_dir.mkdir(parents=True, exist_ok=True)
    for name in sorted(wanted):
        cmd = shlex.split(lean_cmd) + ["-o", str(out_dir / f"{name}.olean"), str(by_name[name])]
        try:
            if subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).returncode != 0:
                failed.append(name)
        except Exception:
            failed.append(name)
    return failed


def run_lean(path: Path, lean_cmd: str, timeout: int, lean_path: Path | None = None) -> tuple[int, str]:
    cmd = shlex.split(lean_cmd) + [str(path)]
    env = None
    if lean_path is not None:
        env = dict(os.environ)
        env["LEAN_PATH"] = os.pathsep.join(filter(None, [str(lean_path), env.get("LEAN_PATH", "")]))
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=env)
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
    ap.add_argument("--allow-budget", action="append", default=[],
                    help="file permitted to exceed the runner's memory or time (tracked, not silent)")
    ap.add_argument("--timeout", type=int, default=2400)
    args = ap.parse_args()

    allow = {Path(a).name for a in args.allow_native}
    budget_allowed = {Path(a).name for a in args.allow_budget}
    budget_tracked: list[str] = []
    tally = {"CLEAN": 0, "STANDARD": 0, "NATIVE": 0, "BROKEN": 0}
    failures: list[str] = []
    native_tracked: list[str] = []

    print("=" * 78)
    print("E47 AXIOM LEDGER")
    print("=" * 78)

    paths = [Path(f) for f in args.files]
    dep_dir = Path(tempfile.mkdtemp(prefix="axiom-ledger-oleans-"))
    unbuilt = build_local_deps([q for q in paths if q.exists()], args.lean_cmd, args.timeout, dep_dir)
    if unbuilt:
        print(f"  note: sibling modules that would not build: {', '.join(unbuilt)}")

    for f in args.files:
        path = Path(f)
        if not path.exists():
            failures.append(f"{path}: missing")
            continue

        failures.extend(check_source(path))

        rc, out = run_lean(path, args.lean_cmd, args.timeout, dep_dir)
        # A file the runner killed for memory, or that ran out of time, has
        # told us nothing about its axioms.  Recording that as "did not
        # compile" states something false: the proof may be perfectly good and
        # the machine simply too small.  Tracked explicitly instead, the same
        # way a native_decide allowance is tracked rather than hidden.
        if rc in (137, -9, 124, -15):
            why = "out of memory (killed)" if rc in (137, -9) else f"over the {args.timeout}s limit"
            if path.name in budget_allowed:
                budget_tracked.append(f"{path.name}: {why}")
                print(f"\n  {path}  — NOT AUDITED, {why} [allowed here]")
            else:
                failures.append(f"{path}: {why}; axioms unknown, so nothing is certified")
                print(f"\n  {path}  — NOT AUDITED, {why}")
            continue
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

    if budget_tracked:
        print(f"\n  NOT AUDITED — {len(budget_tracked)} file(s) the runner could not finish,")
        print("  permitted by --allow-budget. Their axioms are unknown: this is not a")
        print("  pass, it is an absence of evidence, and it is recorded as one:")
        for t in budget_tracked:
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
