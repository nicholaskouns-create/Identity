"""Clock and authorization metadata, aligned to the existing City contracts.

Discovered 2026-10-25 in nicholaskouns-create/auth-kernel @ ce4ae4c:

  .github/workflows/clock-evidence.yml emits schema `e47-clock-evidence-v1`
  with observed_at_utc, host_monotonic_ns, clock_id, e47_tick (null) and
  clock_status "not-attested". It already separates wall-clock time from a
  monotonic host counter and from an E47 tick, and already refuses to assert
  attestation. The Monorail adopts those field names rather than inventing
  parallel ones.

  auth_kernel.py / RULES.txt state the authorization invariant:
  "Invoke requires Candidate, the syntactic gate, a live nonce, an active
  subject, and a requester who is that subject's bound principal.
  A valid signature observes. It does not derive Invoke."

That invariant is exactly the Monorail's: a receipt digest OBSERVES that a
body is intact. It does not DERIVE the authority to promote a claim. The
two systems agree, so this adapter maps between them instead of adding a
second authorization model.

KEY MANAGEMENT: none. This module computes no HMAC and holds no secret.
Signing requires a key from an approved secret store, which has not been
provisioned, so signatures are reported as absent rather than faked.
"""
from __future__ import annotations

import os
import time
from datetime import datetime, timezone
from typing import Any

NAME = "clock_auth"
MODE = "CONTRACT-ALIGNED / UNSIGNED"
CLOCK_SCHEMA = "e47-clock-evidence-v1"
AUTH_SOURCE = "nicholaskouns-create/auth-kernel @ ce4ae4c"

# The four time notions the directive requires be kept apart.
TIME_KINDS = {
    "observed_at_utc":   "wall clock on the executing host; not attested",
    "host_monotonic_ns": "monotonic counter; measures elapsed time only",
    "logical_seq":       "position in the receipt chain; ordering, not duration",
    "e47_tick":          "Quantum Clock application tick; null unless the clock ran",
    "signed_at":         "cryptographic signing time; null while unsigned",
}

# Operations the auth kernel gates. None may be derived from a signature.
GATED_OPERATIONS = (
    "receipt_submission", "evidence_correction", "canonical_promotion",
    "cross_platform_write", "production_migration",
)


def status() -> dict:
    return {
        "adapter": NAME, "mode": MODE,
        "clock_schema": CLOCK_SCHEMA,
        "auth_source": AUTH_SOURCE,
        "signing": "NOT CONFIGURED — no key provisioned; receipts are unsigned",
        "clock_status": "not-attested",
        "gated_operations": list(GATED_OPERATIONS),
    }


def clock_evidence(logical_seq: int) -> dict[str, Any]:
    """Time metadata for one receipt, in the City's existing schema.

    e47_tick stays None unless the Quantum Clock actually produced one. A
    logical sequence number is NOT a tick, and a tick is NOT evidence of
    quantum hardware execution.
    """
    return {
        "schema": CLOCK_SCHEMA,
        "observed_at_utc": datetime.now(timezone.utc).isoformat(),
        "host_monotonic_ns": time.monotonic_ns(),
        "clock_id": os.environ.get("RUNNER_NAME", "local-host"),
        "logical_seq": logical_seq,
        "e47_tick": None,
        "signed_at": None,
        "clock_status": "not-attested",
    }


def authorization_state(operation: str) -> dict[str, Any]:
    """What the auth kernel would require, and what is actually present."""
    if operation not in GATED_OPERATIONS:
        raise ValueError(f"unknown gated operation {operation!r}")
    return {
        "operation": operation,
        "requires": ["candidate", "syntactic_gate", "live_nonce",
                     "active_subject", "bound_principal"],
        "present": [],
        "authorized": False,
        "reason": "no auth-kernel session; this process holds no nonce, no "
                  "subject and no key. A receipt digest observes integrity "
                  "and does not derive Invoke.",
    }


def describe_time_kinds() -> dict[str, str]:
    return dict(TIME_KINDS)
