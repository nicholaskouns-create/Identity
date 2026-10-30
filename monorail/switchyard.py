"""The Correction Switchyard (the City's Black-Line Revision Switchyard).

Append-only. A failure is never overwritten and never deleted: it is
classified, linked to the smallest corrective obligation, and left in place.
A corrected upstream station SUSPENDS every affected downstream route until
it is rerun, per the Monorail charter.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from passport import GENESIS_PARENT, compute_receipt_hash, utc_now

# Defect taxonomy, from directive step 5. Each maps to the smallest
# corrective obligation that could clear it.
DEFECTS: dict[str, str] = {
    "compiler_failure": "Fix the proof term or the tactic; recompile the named file.",
    "missing_source": "Restore the file at the recorded path, or correct the route's station path.",
    "compiler_unavailable": "Install the pinned compiler; regenerate environment.lock and rerun.",
    "invalid_assumption": "Discharge or declare the assumption; re-audit #print axioms.",
    "broken_dependency": "Rerun the parent station, then revalidate this station.",
    "matrix_identity_false": "Recompute the identity in exact arithmetic; correct the statement.",
    "ci_failure": "Inspect the run log; rerun the workflow on the same commit.",
    "environment_mismatch": "Pin the compiler version; regenerate environment.lock.",
    "missing_certificate": "Re-emit the certificate from the recorded commit.",
    "corrupted_certificate": "Re-emit from source; do not edit the stored receipt.",
    "superseded_claim": "Record the superseding claim; leave the original in place.",
}


class Switchyard:
    """An append-only JSONL ledger of defects and corrections."""

    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def entries(self) -> list[dict[str, Any]]:
        if not self.path.exists():
            return []
        out = []
        for line in self.path.read_text().splitlines():
            if line.strip():
                out.append(json.loads(line))
        return out

    def _last_hash(self) -> str:
        e = self.entries()
        return e[-1]["entry_hash"] if e else GENESIS_PARENT

    def file(self, *, defect: str, route_id: str, station: str,
             receipt_hash: str | None, detail: str,
             supersedes: str | None = None) -> dict[str, Any]:
        """Record a defect. Preserves the original evidence by reference."""
        if defect not in DEFECTS:
            raise ValueError(f"unknown defect class {defect!r}")
        entry = {
            "schema_version": "monorail.switchyard.v1",
            "kind": "DEFECT",
            "defect_class": defect,
            "route_id": route_id,
            "station": station,
            "evidence_receipt": receipt_hash,
            "detail": detail,
            "corrective_obligation": DEFECTS[defect],
            "supersedes": supersedes,
            "resolved": False,
            "parent_entry_hash": self._last_hash(),
            "timestamp_utc": utc_now(),
        }
        entry["entry_hash"] = compute_receipt_hash({**entry, "receipt_hash": None})
        with self.path.open("a") as fh:
            fh.write(json.dumps(entry, sort_keys=True, ensure_ascii=False) + "\n")
        return entry

    def correct(self, *, defect_entry_hash: str, correction_receipt: str,
                detail: str) -> dict[str, Any]:
        """Record a correction. References the defect; never rewrites it."""
        known = {e["entry_hash"] for e in self.entries()}
        if defect_entry_hash not in known:
            raise ValueError("correction references an unknown defect entry")
        entry = {
            "schema_version": "monorail.switchyard.v1",
            "kind": "CORRECTION",
            "corrects_entry": defect_entry_hash,
            "correction_receipt": correction_receipt,
            "detail": detail,
            "parent_entry_hash": self._last_hash(),
            "timestamp_utc": utc_now(),
        }
        entry["entry_hash"] = compute_receipt_hash({**entry, "receipt_hash": None})
        with self.path.open("a") as fh:
            fh.write(json.dumps(entry, sort_keys=True, ensure_ascii=False) + "\n")
        return entry

    def open_defects(self) -> list[dict[str, Any]]:
        corrected = {e["corrects_entry"] for e in self.entries()
                     if e.get("kind") == "CORRECTION"}
        return [e for e in self.entries()
                if e.get("kind") == "DEFECT" and e["entry_hash"] not in corrected]

    def suspends(self, route_id: str) -> bool:
        """An open defect on a route suspends it until the station is rerun."""
        return any(d["route_id"] == route_id for d in self.open_defects())
