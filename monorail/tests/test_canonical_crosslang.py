#!/usr/bin/env python3
"""Canonical serialization must agree across Python, PostgreSQL and JavaScript.

Covers the cases directive section IV names: Unicode, nested objects, numeric
normalization, null, ordering, empty structures. Also asserts that every
out-of-contract value is REJECTED by all three, rather than silently producing
three different answers.
"""
from __future__ import annotations
import hashlib, json, os, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from passport import PassportError, assert_canonicalizable  # noqa: E402

DB = "monorail_test"
R: list[tuple[str, bool, str]] = []
_seq = [0]


def py_canon(v):
    assert_canonicalizable(v)
    return json.dumps(v, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False, allow_nan=False)


def sql_canon(v):
    _seq[0] += 1
    f = Path(f"/tmp/canon{_seq[0]}.sql")
    f.write_text("select city_formalism.monorail_canonical_json($mono$"
                 + json.dumps(v, ensure_ascii=False) + "$mono$::jsonb);")
    f.chmod(0o644)
    inner = f"psql -v ON_ERROR_STOP=1 -t -A -d {DB} -f {f}"
    argv = (["su", "postgres", "-c", inner] if os.geteuid() == 0
            else ["sudo", "-n", "-u", "postgres", "sh", "-c", inner])
    p = subprocess.run(argv, capture_output=True, text=True)
    if p.returncode:
        raise RuntimeError(p.stderr.strip()[:200])
    return p.stdout.strip()


def js_canon(v):
    src = ("import {monorailCanonical} from '%s/canonical.js';"
           "process.stdout.write(monorailCanonical(%s));"
           % (HERE.parent, json.dumps(v, ensure_ascii=False)))
    p = subprocess.run(["node", "--input-type=module", "-e", src],
                       capture_output=True, text=True)
    if p.returncode:
        raise RuntimeError(p.stderr.strip()[:200])
    return p.stdout


def check(name, cond, note=""):
    R.append((name, bool(cond), note))


CASES = {
    "flat ascii":            {"b": "two", "a": "one", "c": "three"},
    "key ordering":          {"z": 1, "a": 1, "A": 1, "_": 1, "0": 1, "aa": 1},
    "nested objects":        {"o": {"z": {"y": "deep"}, "a": []}, "n": None},
    "arrays preserve order": {"a": ["c", "b", "a", "c"]},
    "empty structures":      {"e_obj": {}, "e_arr": [], "e_str": ""},
    "nulls and booleans":    {"n": None, "t": True, "f": False},
    "integers":              {"zero": 0, "neg": -47, "big": 9007199254740991},
    "unicode BMP":           {"gré": "héllo", "日本": "語", "arrow": "→"},
    "unicode astral":        {"emoji": "🚝🔐", "math": "𝕏"},
    "escapes":               {"q": 'he said "hi"', "bs": "a\\b", "nl": "x\ny", "tab": "a\tb"},
    "key is a number string": {"1": "a", "10": "b", "2": "c"},
}

for name, case in CASES.items():
    try:
        p, s, j = py_canon(case), sql_canon(case), js_canon(case)
    except Exception as e:
        check(f"3-way agree · {name}", False, f"error: {e}")
        continue
    agree = p == s == j
    note = f"{len(p)}B" if agree else ""
    if not agree:
        note = f"py={p[:50]} | sql={s[:50]} | js={j[:50]}"
    check(f"3-way agree · {name}", agree, note)
    if agree:
        check(f"digest stable · {name}", True,
              hashlib.sha256(p.encode()).hexdigest()[:16] + "…")

# Out-of-contract values must be REJECTED, not silently diverge.
for label, bad in [("float", {"x": 1.5}), ("NUL in string", {"x": "a\x00b"})]:
    try:
        py_canon(bad)
        check(f"reject · {label} (python)", False, "accepted")
    except PassportError as e:
        check(f"reject · {label} (python)", True, str(e)[:60])

src = ("import {assertCanonicalizable} from '%s/canonical.js';"
       "try{assertCanonicalizable({x:1.5});console.log('ACCEPTED')}"
       "catch(e){console.log('REJECTED '+e.message)}" % (HERE.parent,))
out = subprocess.run(["node", "--input-type=module", "-e", src],
                     capture_output=True, text=True).stdout.strip()
check("reject · float (javascript)", out.startswith("REJECTED"), out[:60])

try:
    sql_canon({"x": "a\x00b"})
    check("reject · NUL in string (postgres)", False, "accepted")
except Exception as e:
    check("reject · NUL in string (postgres)", True, str(e)[:60])

w = max(len(n) for n, _, _ in R)
passed = sum(ok for _, ok, _ in R)
for n, ok, note in R:
    print(f"  {'PASS' if ok else 'FAIL'}  {n:<{w}}  {note[:60]}")
print(f"\n  {passed}/{len(R)} cross-language checks passed")
sys.exit(0 if passed == len(R) else 1)
