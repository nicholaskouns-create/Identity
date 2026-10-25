"""Notion adapter: mathematical citizen records and lineage.

STATUS IN THIS REPOSITORY: READ-VERIFIED, WRITE-DEFERRED.

The Notion workspace was read during discovery and the Monorail charter,
the Citadel and the Invariant Grammar Terminal were located there. Writing
a civic record is a canonical-promotion-adjacent act, so this adapter
emits a reviewable *reference block* rather than performing the write.
A human applies it. That satisfies 'require explicit human approval before
canonical promotion' without pretending the write happened.
"""
from __future__ import annotations

from typing import Any

NAME = "notion"
MODE = "READ-VERIFIED / WRITE-DEFERRED"

# Located during discovery, 2026-10-25.
CHARTER_PAGE = "3a246094fd3081f0a356e5102d1561b9"   # Elevated Reproducibility Monorail
TERMINAL_PAGE = "3a246094fd308142bf25e6357c6ddba5"  # Invariant Grammar Grand Monorail Terminal
CITADEL_PAGE = "3a246094fd308146a357c72c634d225c"   # Central Citadel


def status() -> dict:
    return {
        "adapter": NAME,
        "mode": MODE,
        "charter_page": CHARTER_PAGE,
        "citadel_page": CITADEL_PAGE,
        "writes": "deferred — canonical promotion requires explicit human approval",
    }


def citizen_block(passport: dict[str, Any], parents: list[str]) -> str:
    """A Notion-ready civic record. Review it, then paste it. No auto-write."""
    status_word = passport["verification_status"]
    return "\n".join([
        f"**Citizen:** `{passport['object_id']}` · theorem `{passport['theorem_id']}`",
        f"**Evidence class:** {passport['evidence_class']} "
        f"(carried without upgrade from the station of origin)",
        f"**Verification:** {status_word} · {passport['proof_system']} "
        f"{passport['compiler_version'] or 'version unrecorded'}",
        f"**Source commit:** `{passport['source_commit']}`",
        f"**Source SHA-256:** `{passport['source_hash']}`",
        f"**Environment lock:** `{passport['environment_lock_hash'][:16]}…`",
        f"**Assumptions:** {', '.join(passport['assumptions']) or 'none reported'}",
        f"**Parent receipt:** `{passport['parent_receipt_hash'][:16]}…`",
        f"**Receipt:** `{passport['receipt_hash']}`",
        f"**Parents:** {', '.join(parents) or '—'}",
        f"**Scope:** {passport['scope'] or 'not stated'}",
        f"**Run:** {passport['run_url'] or 'local execution, no CI run URL'}",
        "",
        "_Transfer does not upgrade evidence. A hash proves integrity, "
        "not authorship and not mathematical correctness._",
    ])
