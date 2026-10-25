#!/usr/bin/env python3
"""The nine scenarios from directive step 9, plus the transport law.

Each test must FAIL LOUDLY on the bad path. A system that silently accepts a
tampered receipt is worse than no system, so every negative case asserts that
the defect is detected and recorded, not merely that nothing crashed.
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE.parent / "adapters"))

import supabase_adapter as supa
from passport import (GENESIS_PARENT, PassportError, canonical_bytes,
                      compute_receipt_hash, make_passport, transport,
                      verify_chain, verify_passport)
from switchyard import Switchyard

H = "a" * 64
RESULTS: list[tuple[str, bool, str]] = []


def check(name: str, cond: bool, note: str = "") -> None:
    RESULTS.append((name, bool(cond), note))


def mk(theorem="E47-KERNEL-47", parent=GENESIS_PARENT, status="PASS",
       ec="E0", ts="2026-10-25T00:00:00Z", **kw):
    return make_passport(
        object_id="E47-CASIMIR", theorem_id=theorem, source_commit="4dcec1d",
        source_hash=H, parent_receipt_hash=parent, proof_system="Lean",
        compiler_version="4.35.0", environment_lock_hash=H, assumptions=[],
        verification_status=status, evidence_class=ec, artifact_hashes=[H],
        timestamp_utc=ts, **kw)


# 1 — valid certificate propagation
a = mk(); b = mk("E47-RANK-78", a["receipt_hash"], ec="E1")
ok, notes = verify_chain([a, b])
check("1 valid certificate propagation", ok, notes[-1])

# 2 — tampered certificate detection
t = json.loads(json.dumps(b)); t["verification_status"] = "PASS"
t["evidence_class"] = "E0"                       # forged upgrade, hash untouched
good, why = verify_passport(t)
check("2 tampered certificate detected", not good, why)

# 3 — missing parent hash
orphan = mk("E47-ORPHAN", "b" * 64)
ok3, n3 = verify_chain([a, orphan])
check("3 missing/forged parent detected", not ok3,
      next((x for x in n3 if "broken link" in x), ""))

# 4 — failed compiler execution recorded, not swallowed
with tempfile.TemporaryDirectory() as d:
    y = Switchyard(Path(d) / "c.jsonl")
    e = y.file(defect="compiler_failure", route_id="R", station="s",
               receipt_hash=H, detail="grind failed")
    check("4 compiler failure filed + route suspended",
          y.suspends("R") and len(y.open_defects()) == 1,
          e["corrective_obligation"])

    # 5 — duplicate receipt submission
    r = supa.Replica(Path(d) / "rep.jsonl")
    r.insert(a)
    try:
        r.insert(a)
        check("5 duplicate receipt rejected", False, "second insert accepted")
    except supa.ReplicaError as ex:
        check("5 duplicate receipt rejected", True, str(ex))

    # 6 — network interruption: partial replication, then recovery
    r2 = supa.Replica(Path(d) / "rep2.jsonl")
    r2.insert(a)                                   # b never arrives
    rec = r2.reconcile([a, b])
    check("6 network interruption leaves detectable gap",
          not rec["consistent"] and rec["local_only"] == [b["receipt_hash"]],
          f"{len(rec['local_only'])} row(s) missing from replica")

    # 9 — recovery after partial failure
    r2.insert(b)
    rec2 = r2.reconcile([a, b])
    check("9 recovery after partial failure", rec2["consistent"],
          f"{rec2['in_both']} rows reconciled")

    # 7 — conflicting replicas
    r3 = supa.Replica(Path(d) / "rep3.jsonl")
    forged = json.loads(json.dumps(a)); forged["source_commit"] = "deadbee"
    r3.path.write_text(json.dumps(forged, sort_keys=True) + "\n")
    rec3 = r3.reconcile([a])
    check("7 conflicting replica detected",
          rec3["conflicting"] == [a["receipt_hash"]],
          "same receipt hash, different body")

    # 8 — unauthorized promotion
    try:
        transport(b, "promote", "Citadel", authorized_class="E0")  # E1 -> E0
        check("8 unauthorized promotion blocked", False, "upgrade permitted")
    except PassportError as ex:
        check("8 unauthorized promotion blocked", True, str(ex))

    # corrections reference, never rewrite
    before = y.path.read_text()
    y.correct(defect_entry_hash=e["entry_hash"], correction_receipt=H,
              detail="recompiled on Lean 4.35.0")
    after = y.path.read_text()
    check("correction appends, never rewrites",
          after.startswith(before) and not y.open_defects(),
          "original defect line byte-identical")

# transport law: lawful transfer preserves lineage and does not upgrade
moved = transport(a, "T", "Verification Precinct")
check("transport preserves evidence class", moved["evidence_class"] == a["evidence_class"])
check("transport links to its origin", moved["parent_receipt_hash"] == a["receipt_hash"])
check("transport may lower the fare",
      transport(a, "T", "Observatory", authorized_class="E2")["evidence_class"] == "E2")

# canonical serialization is key-order independent
shuffled = dict(reversed(list(a.items())))
check("canonical form is key-order independent",
      canonical_bytes(shuffled) == canonical_bytes(a))
# The digest must not cover itself. Note `parent_receipt_hash` legitimately
# contains that substring, so test the KEY, not the bytes.
_body = json.loads(canonical_bytes(a))
check("receipt hash excludes itself",
      "receipt_hash" not in _body and "parent_receipt_hash" in _body,
      "digest covers the body and the parent link, not its own field")

width = max(len(n) for n, _, _ in RESULTS)
passed = 0
for name, ok_, note in RESULTS:
    print(f"  {'PASS' if ok_ else 'FAIL'}  {name:<{width}}  {note[:62]}")
    passed += ok_
print(f"\n  {passed}/{len(RESULTS)} scenarios passed")
sys.exit(0 if passed == len(RESULTS) else 1)
