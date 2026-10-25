"""Supabase adapter: append-only evidence replica and integrity re-check.

STATUS IN THIS REPOSITORY: MOCK.

No Supabase connector is authorized for this session, so there is no live
project to write to. The adapter therefore persists to a local JSONL file
that mimics an append-only table, and `status()` reports mode MOCK so no
caller can mistake it for a deployed integration. Live deployment is pending.

The mock deliberately enforces the same invariants the real schema does, so
that swapping in a live client is a change of transport and not of contract:
  - insert only; no update, no delete
  - source_sha256 must be 64 lowercase hex   (mnemosyne_private constraint)
  - evidence_class NOT NULL                  (mnemosyne_private constraint)
  - receipt_hash unique                      (duplicate submission rejected)

The real table targets are the existing ones named in docs/proof-memory-bridge.md.
This adapter does not propose replacing them.
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

NAME = "supabase"
MODE = "MOCK"
TARGET_SCHEMA = "mnemosyne_private"
_SHA256_RE = re.compile(r"^[a-f0-9]{64}$")


class ReplicaError(RuntimeError):
    pass


def status() -> dict:
    return {
        "adapter": NAME,
        "mode": MODE,
        "live_deployment": "PENDING — no Supabase connector authorized",
        "target_schema": TARGET_SCHEMA,
        "enforces": ["append_only", "sha256_format", "evidence_class_not_null",
                     "receipt_hash_unique"],
    }


class Replica:
    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def rows(self) -> list[dict[str, Any]]:
        if not self.path.exists():
            return []
        return [json.loads(l) for l in self.path.read_text().splitlines() if l.strip()]

    def insert(self, passport: dict[str, Any]) -> dict[str, Any]:
        rh = passport.get("receipt_hash", "")
        if not _SHA256_RE.match(rh or ""):
            raise ReplicaError("receipt_hash must be 64 lowercase hex")
        if not _SHA256_RE.match(passport.get("source_hash", "") or ""):
            raise ReplicaError("source_hash must be 64 lowercase hex")
        if not passport.get("evidence_class"):
            raise ReplicaError("evidence_class is NOT NULL")
        if any(r["receipt_hash"] == rh for r in self.rows()):
            raise ReplicaError(f"duplicate receipt {rh[:12]}… already replicated")
        with self.path.open("a") as fh:
            fh.write(json.dumps(passport, sort_keys=True, ensure_ascii=False) + "\n")
        return passport

    def reconcile(self, local: list[dict[str, Any]]) -> dict[str, Any]:
        """Compare the local ledger against the replica. Reports, never merges."""
        mine = {r["receipt_hash"]: r for r in self.rows()}
        theirs = {p["receipt_hash"]: p for p in local}
        conflicts = [h for h in mine.keys() & theirs.keys() if mine[h] != theirs[h]]
        return {
            "in_both": len(mine.keys() & theirs.keys()),
            "replica_only": sorted(mine.keys() - theirs.keys()),
            "local_only": sorted(theirs.keys() - mine.keys()),
            "conflicting": sorted(conflicts),
            "consistent": not conflicts and not (mine.keys() ^ theirs.keys()),
        }
