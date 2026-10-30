"""Supabase adapter — the existing Mathematical City, connected.

MODE: LIVE-READ / WRITE-GATED.

Honest statement of what this module can and cannot do:

  This process holds NO database credentials. It cannot open a connection.
  What it does is emit the exact statements, validated against the live
  schema (columns, CHECK constraints and uniqueness pulled from the real
  project on 2026-10-25), for a credentialed operator or the Supabase MCP
  tool to execute. Reads during this session were performed through that
  tool and are reported as LIVE. Writes are GATED and were not performed.

  Calling this "a live write integration" would be false, so it does not.

Existing City tables are REFERENCED, never recreated:
  public.machine_certificates   compiler certificates  (mutable rows)
  public.corrections            the Correction Switchyard
  public.transit_events         Monorail transport history
  public.approval_queue         human gate for canonical promotion
  public.cube_moves             geometry ledger — UNTOUCHED, by design
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

NAME = "supabase"
MODE = "LIVE-READ / WRITE-GATED"
PROJECT_REF = "gpkjvihkyectnenvnbng"
TARGET_SCHEMA = "city_formalism"
_SHA256_RE = re.compile(r"^[a-f0-9]{64}$")

# Verified against the live project, 2026-10-25.
ACCESS_SCOPES = ("private", "workspace", "public")
APPROVAL_CLASSES = ("auto", "auto_notify", "human_gate")
APPROVAL_STATUSES = ("pending", "approved", "rejected", "modified",
                     "held", "executed", "cancelled")

# Defect classes, extended per directive section V.
DEFECT_CLASSES = (
    "environment_mismatch", "compiler_failure", "missing_dependency",
    "mathematical_counterexample", "invalid_assumption", "digest_mismatch",
    "broken_parent_link", "unauthorized_mutation", "transport_failure",
    "ci_infrastructure_failure", "test_harness_false_pass",
    "missing_source", "compiler_unavailable", "superseded_claim",
)


class ReplicaError(RuntimeError):
    pass


def status() -> dict:
    return {
        "adapter": NAME,
        "mode": MODE,
        "project_ref": PROJECT_REF,
        "reads": "LIVE (performed via Supabase MCP this session)",
        "writes": "GATED — statements emitted for review; none executed",
        "ledger_table": f"{TARGET_SCHEMA}.monorail_receipts",
        "ledger_deployed": "NO — migration awaits explicit approval",
        "cube_moves": "untouched by design",
    }


def _q(v: Any) -> str:
    """Quote a value as a SQL literal. None becomes NULL."""
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int,)):
        return str(v)
    if isinstance(v, (dict, list)):
        return "'" + json.dumps(v, ensure_ascii=False).replace("'", "''") + "'::jsonb"
    return "'" + str(v).replace("'", "''") + "'"


# --- receipts ---------------------------------------------------------------

def insert_receipt_sql(p: dict[str, Any],
                       machine_certificate_code: str | None = None,
                       transit_operation_code: str | None = None) -> str:
    """The exact INSERT for one passport. Validated, not executed."""
    for f in ("receipt_hash", "parent_receipt_hash", "source_hash",
              "environment_lock_hash"):
        if not _SHA256_RE.match(p.get(f) or ""):
            raise ReplicaError(f"{f} must be 64 lowercase hex")
    cols = ["receipt_hash", "parent_receipt_hash", "schema_version", "route_id",
            "station", "object_id", "theorem_id", "source_commit", "source_hash",
            "environment_lock_hash", "proof_system", "compiler_version",
            "assumptions", "verification_status", "evidence_class", "scope",
            "run_url", "artifact_hashes", "passport", "machine_certificate_code",
            "transit_operation_code", "timestamp_utc"]
    vals = [p["receipt_hash"], p["parent_receipt_hash"], p["schema_version"],
            p["route_id"], p["station"], p["object_id"], p["theorem_id"],
            p["source_commit"], p["source_hash"], p["environment_lock_hash"],
            p["proof_system"], p.get("compiler_version"), p.get("assumptions", []),
            p["verification_status"], p["evidence_class"], p.get("scope"),
            p.get("run_url"), p.get("artifact_hashes", []), p,
            machine_certificate_code, transit_operation_code,
            p["timestamp_utc"]]
    return (f"insert into {TARGET_SCHEMA}.monorail_receipts\n  ("
            + ", ".join(cols) + ")\nvalues\n  ("
            + ", ".join(_q(v) for v in vals) + ");")


# --- transit events ---------------------------------------------------------

def transit_event_sql(route_id: str, passport: dict[str, Any],
                      source_system: str, destination_system: str) -> str:
    """One row per Monorail transport, success or failure. Append-only log."""
    op = f"MONORAIL-{route_id}-{passport['station']}"
    payload = {
        "object_id": passport["object_id"],
        "theorem_id": passport["theorem_id"],
        "receipt_hash": passport["receipt_hash"],
        "parent_receipt_hash": passport["parent_receipt_hash"],
        "evidence_class": passport["evidence_class"],
        "verification_status": passport["verification_status"],
        "source_commit": passport["source_commit"],
        "run_url": passport.get("run_url"),
        "note": "Transfer does not upgrade evidence.",
    }
    st = "completed" if passport["verification_status"] == "PASS" else "failed"
    return ("insert into public.transit_events\n"
            "  (operation_code, event_type, source_system, destination_system,"
            " payload, correlation_id, status, access_scope)\nvalues\n  ("
            + ", ".join(_q(v) for v in [op, "monorail_transport", source_system,
                                        destination_system, payload,
                                        passport["receipt_hash"], st, "private"])
            + ");")


# --- corrections (the Switchyard, in the City's own table) ------------------

def correction_sql(defect_class: str, route_id: str, station: str,
                   receipt_hash: str, detail: str, obligation: str,
                   superseded_claim: str | None = None) -> str:
    """A defect, filed as a City correction. Never overwrites the original."""
    if defect_class not in DEFECT_CLASSES:
        raise ReplicaError(f"unknown defect class {defect_class!r}")
    code = f"MONORAIL-{route_id}-{station}-{receipt_hash[:8]}"
    meta = {"defect_class": defect_class, "route_id": route_id,
            "station": station, "evidence_receipt": receipt_hash,
            "corrective_obligation": obligation,
            "preserves_original": True}
    return ("insert into public.corrections\n"
            "  (correction_code, title, superseded_claim, corrected_claim,"
            " reason, status, metadata, access_scope)\nvalues\n  ("
            + ", ".join(_q(v) for v in [
                code, f"Monorail defect: {defect_class} at {station}",
                superseded_claim, obligation, detail, "open", meta, "private"])
            + ");")


# --- approval queue (canonical promotion gate) ------------------------------

def promotion_request_sql(route_id: str, object_id: str, head_receipt: str,
                          evidence: dict[str, Any]) -> str:
    """Request canonical promotion. action_class is human_gate, always.

    No automated path may bypass this. The row is a REQUEST; approval is a
    human act recorded in decision_by/decided_at, and this adapter has no
    function that sets those.
    """
    return ("insert into public.approval_queue\n"
            "  (action_code, action_class, source_agent_code, destination_system,"
            " object_key, proposed_action, reason, before_state, after_state,"
            " evidence, rollback_plan, status, access_scope)\nvalues\n  ("
            + ", ".join(_q(v) for v in [
                f"MONORAIL-PROMOTE-{route_id}-{head_receipt[:8]}",
                "human_gate", "monorail-route-runner", "city_formalism",
                object_id,
                f"Promote {object_id} to canonical on route {route_id}",
                "Route certified; every station PASS and hash chain intact.",
                {"canonical": False}, {"canonical": True}, evidence,
                "Append a superseding correction; receipts are never deleted.",
                "pending", "private"])
            + ");")


# --- reconciliation ---------------------------------------------------------

def reconcile(local: list[dict[str, Any]], remote_hashes: list[str]) -> dict:
    """Compare the local chain against whatever the ledger actually holds."""
    mine = set(remote_hashes)
    theirs = {p["receipt_hash"] for p in local}
    return {"in_both": len(mine & theirs),
            "ledger_only": sorted(mine - theirs),
            "local_only": sorted(theirs - mine),
            "consistent": mine == theirs}


def emit_bundle(passports: list[dict[str, Any]], route_id: str,
                out: str | Path) -> Path:
    """Write every gated statement to one reviewable file. Nothing executes."""
    lines = [
        "-- Monorail write bundle. REVIEW BEFORE EXECUTING.",
        f"-- route {route_id} · {len(passports)} receipts",
        "-- Requires city_formalism.monorail_receipts to exist "
        "(infra/supabase/monorail_receipts.sql, not yet applied).",
        "-- Wrapped in a transaction: all receipts land or none do.",
        "BEGIN;", ""]
    for p in passports:
        lines += [insert_receipt_sql(p), "", transit_event_sql(
            route_id, p, "github_actions", "city_formalism"), ""]
    lines += ["COMMIT;"]
    path = Path(out)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")
    return path
