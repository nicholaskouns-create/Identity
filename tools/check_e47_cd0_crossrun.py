#!/usr/bin/env python3
"""Audit an unsigned, content-addressed cross-run E47 [C,D] column-zero receipt.

This checks source bytes at both recorded Git commits, the current checkout,
and an independent exact-integer reconstruction. It does NOT re-run Coq/Lean
or independently attest historical GitHub job status.
"""
from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "evidence/routes/KX-E47-KERNEL/casimir_d_column0_crossrun.json"


def git(*args: str, data: bytes | None = None) -> bytes:
    return subprocess.run(
        ["git", *args], cwd=ROOT, input=data, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, check=True
    ).stdout


def audit_sources(receipt: dict) -> None:
    observations = receipt["compiler_observations"]
    assert {x["language"] for x in observations} == {"Coq", "Lean"}
    assert all(x["job_conclusion"] == "success" for x in observations)
    assert len({x["commit"] for x in observations}) == 2
    assert {x["axiom_audit"] for x in observations} == {
        "Closed under the global context", "[propext, Lean.ofReduceBool]"
    }
    assert {(x["language"], x["conclusion"]) for x in receipt["negative_observations"]} == {
        ("Lean", "failure"), ("Coq", "cancelled")
    }
    for item in receipt["source_files"]:
        path = item["path"]
        current = (ROOT / path).read_bytes()
        assert git("hash-object", "--stdin", data=current).decode().strip() == item["git_blob_sha1"], path
        if "sha256" in item:
            assert hashlib.sha256(current).hexdigest() == item["sha256"], path
        for observed in observations:
            historical = git("show", observed["commit"] + ":" + path)
            assert historical == current, (observed["commit"], path)
    print("E47_CD0_CROSSRUN_SOURCE_BYTES_MATCH")


def audit_exact_integer_column() -> None:
    n = 125
    def a(i: int) -> int: return i // 25
    def b(i: int) -> int: return (i // 5) % 5
    def c(i: int) -> int: return i % 5

    z = [[6 - a(i) - b(i) - c(i) if i == j else 0
          for j in range(n)] for i in range(n)]
    u = [[
        int(a(i) + 1 == a(j) and b(i) == b(j) and c(i) == c(j)) * a(j) * (5 - a(j))
        + int(a(i) == a(j) and b(i) + 1 == b(j) and c(i) == c(j)) * b(j) * (5 - b(j))
        + int(a(i) == a(j) and b(i) == b(j) and c(i) + 1 == c(j)) * c(j) * (5 - c(j))
        for j in range(n)] for i in range(n)]
    d = [[
        int(a(i) == a(j) + 1 and b(i) == b(j) and c(i) == c(j))
        + int(a(i) == a(j) and b(i) == b(j) + 1 and c(i) == c(j))
        + int(a(i) == a(j) and b(i) == b(j) and c(i) == c(j) + 1)
        for j in range(n)] for i in range(n)]

    def mm(x: list[list[int]], y: list[list[int]]) -> list[list[int]]:
        return [[sum(x[i][k] * y[k][j] for k in range(n) if x[i][k])
                 for j in range(n)] for i in range(n)]

    du, zz = mm(d, u), mm(z, z)
    casimir = [[du[i][j] + zz[i][j] + z[i][j]
                for j in range(n)] for i in range(n)]
    cd, dc = mm(casimir, d), mm(d, casimir)
    assert all(cd[i][0] == dc[i][0] for i in range(n))
    print("E47_CD0_EXACT_INTEGER_125_ROWS_PASS")
    # Stronger independent computation; not a compiler theorem.
    assert all(cd[i][j] == dc[i][j] for i in range(n) for j in range(n))
    print("E47_CD_EXACT_INTEGER_15625_ENTRIES_PASS")


if __name__ == "__main__":
    receipt = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert receipt["schema_version"] == "e47.crossrun.evidence.v1"
    assert receipt["kind"] == "unsigned_content_addressed_compiler_evidence_join"
    assert receipt["scope"]["column_zero_based"] == 0
    assert receipt["scope"]["rows"] == receipt["scope"]["dimension"] == 125
    audit_sources(receipt)
    audit_exact_integer_column()
