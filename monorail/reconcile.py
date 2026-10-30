"""Reconcile Monorail theorem identifiers against the City's citizen registry.

Two failure modes this catches, both of which would otherwise pass silently:

  1. EVIDENCE UPGRADE BY TRANSPORT. A route station declares a fare higher
     than the canonical citizen already carries. Compiling a Lean file may
     well justify promoting that citizen from E1 to E0 — but that is a
     CANONICAL PROMOTION, a human act recorded in approval_queue. A route
     run is not allowed to perform it by writing a receipt.

  2. SILENT CITIZEN CREATION. A theorem_id that matches no citizen_code.
     Writing one would fork the registry and create a duplicate identity.
     The route reports it and stops; a human decides whether the code is a
     typo, an alias, or a genuinely new citizen.

Snapshot read live from project gpkjvihkyectnenvnbng on 2026-10-25 via the
Supabase MCP tool. This process holds no credentials, so the snapshot is
data, not a connection; `--refresh` regenerates it from a fresh query.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

# Order is authority order; index 0 is the strongest fare.
FARES = ("E0", "E1", "E2", "E3", "E4")

CITY_SNAPSHOT: dict[str, dict[str, str]] = {
    "E47-CARRIER-125":      {"evidence_class": "E0",      "status": "validated"},
    "E47-CASIMIR-SPECTRUM": {"evidence_class": "E1",      "status": "validated"},
    "E47-KERNEL-47":        {"evidence_class": "E1",      "status": "validated"},
    "E47-PROJECTOR":        {"evidence_class": "E1",      "status": "validated"},
    "E47-CONTINUOUS":       {"evidence_class": "E1",      "status": "validated"},
    "E47-DISCRETE":         {"evidence_class": "E1",      "status": "validated"},
    "CAT-E47-C01":          {"evidence_class": "E0 + E1", "status": "canonical"},
    "CAT-E47-C02":          {"evidence_class": "E0 + E1", "status": "canonical"},
    "CAT-E47-C03":          {"evidence_class": "E0 + E1", "status": "canonical"},
    "B5-125-C04":           {"evidence_class": "E0+E1",   "status": "validated"},
    "B5-125-C08":           {"evidence_class": "E0+E1",   "status": "validated"},
}
SNAPSHOT_SOURCE = "public.mathematical_identities @ gpkjvihkyectnenvnbng, 2026-10-25"


def _strongest(city_class: str) -> str:
    """'E0 + E1' carries E0. Take the strongest fare the citizen holds."""
    present = [f for f in FARES if f in city_class]
    return present[0] if present else "E4"


def reconcile_station(theorem_id: str, route_class: str) -> dict[str, Any]:
    city = CITY_SNAPSHOT.get(theorem_id)
    if city is None:
        return {"theorem_id": theorem_id, "route_class": route_class,
                "city_class": None, "city_status": None,
                "verdict": "UNREGISTERED",
                "detail": "no citizen_code matches; do not auto-create — a route "
                          "may not mint a civic identity",
                "blocks_promotion": True}
    held = _strongest(city["evidence_class"])
    if FARES.index(route_class) < FARES.index(held):
        return {"theorem_id": theorem_id, "route_class": route_class,
                "city_class": city["evidence_class"], "city_status": city["status"],
                "verdict": "UPGRADE_REQUIRES_APPROVAL",
                "detail": f"route declares {route_class}, citizen holds "
                          f"{city['evidence_class']}. Transfer does not upgrade "
                          f"evidence; route this through approval_queue as a "
                          f"human_gate canonical promotion.",
                "blocks_promotion": True}
    return {"theorem_id": theorem_id, "route_class": route_class,
            "city_class": city["evidence_class"], "city_status": city["status"],
            "verdict": "CONSISTENT", "detail": "route fare does not exceed the "
                                               "citizen's recorded class",
            "blocks_promotion": False}


def reconcile_route(passports: list[dict[str, Any]]) -> dict[str, Any]:
    seen: dict[str, str] = {}
    for p in passports:
        seen.setdefault(p["theorem_id"], p["evidence_class"])
    rows = [reconcile_station(t, c) for t, c in sorted(seen.items())]
    return {
        "schema_version": "monorail.reconciliation.v1",
        "snapshot_source": SNAPSHOT_SOURCE,
        "consistent": sum(r["verdict"] == "CONSISTENT" for r in rows),
        "unregistered": sum(r["verdict"] == "UNREGISTERED" for r in rows),
        "upgrades_requiring_approval":
            sum(r["verdict"] == "UPGRADE_REQUIRES_APPROVAL" for r in rows),
        "promotion_blocked": any(r["blocks_promotion"] for r in rows),
        "rows": rows,
    }


def write_report(passports: list[dict[str, Any]], out: str | Path) -> Path:
    rep = reconcile_route(passports)
    path = Path(out)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(rep, indent=2) + "\n")
    return path
