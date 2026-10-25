"""Proof passports and the hash-linked receipt chain.

Implements the Elevated Reproducibility Monorail's chain of custody.
Terminology follows the existing Notion charter and docs/proof-memory-bridge.md:
evidence classes are the City's E0-E4 fare, not a re-invented vocabulary.

Operating principle, enforced in code by `transport`: transfer does not
upgrade evidence.
"""
from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime, timezone
from typing import Any

SCHEMA_VERSION = "monorail.passport.v1"

# The City's fare classes. Order is the authority order; see CITY LEGEND.
EVIDENCE_CLASSES = ("E0", "E1", "E2", "E3", "E4")

# Directive vocabulary -> City fare. Kept explicit so neither side is overwritten.
DIRECTIVE_EVIDENCE_MAP = {
    "formal": "E0",
    "exact-computation": "E1",
    "numerical": "E2",
    "experimental": "E4",
}

VERIFICATION_STATUS = ("PASS", "FAIL", "PENDING", "BLOCKED")
ROUTE_STATES = ("OPEN", "LIMITED SERVICE", "SUSPENDED", "CONSTRUCTION",
                "OBSERVATORY SERVICE")

GENESIS_PARENT = "0" * 64
_SHA256_RE = re.compile(r"^[a-f0-9]{64}$")

# Fields excluded from the digest: receipt_hash is the digest itself.
_UNHASHED = ("receipt_hash",)


class PassportError(ValueError):
    """Raised when a passport violates the transport law or its schema."""


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def canonical_bytes(passport: dict[str, Any]) -> bytes:
    """Canonical serialization, defined BEFORE hashing (directive step 3).

    Rules, fixed for schema v1:
      - drop the hash field itself
      - sort keys at every depth
      - no insignificant whitespace
      - UTF-8, no ASCII escaping, so the bytes are stable across locales
      - reject NaN/Infinity, which have no canonical JSON form
    """
    body = {k: v for k, v in passport.items() if k not in _UNHASHED}
    return json.dumps(
        body, sort_keys=True, separators=(",", ":"),
        ensure_ascii=False, allow_nan=False,
    ).encode("utf-8")


def compute_receipt_hash(passport: dict[str, Any]) -> str:
    return sha256_hex(canonical_bytes(passport))


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def make_passport(
    *,
    object_id: str,
    theorem_id: str,
    source_commit: str,
    source_hash: str,
    parent_receipt_hash: str,
    proof_system: str,
    compiler_version: str,
    environment_lock_hash: str,
    assumptions: list[str],
    verification_status: str,
    evidence_class: str,
    artifact_hashes: list[str],
    route_id: str | None = None,
    station: str | None = None,
    scope: str = "",
    run_url: str | None = None,
    timestamp_utc: str | None = None,
) -> dict[str, Any]:
    """Build a sealed passport. The receipt_hash is computed, never supplied."""
    if evidence_class in DIRECTIVE_EVIDENCE_MAP:
        evidence_class = DIRECTIVE_EVIDENCE_MAP[evidence_class]
    if evidence_class not in EVIDENCE_CLASSES:
        raise PassportError(f"unknown evidence class {evidence_class!r}")
    if verification_status not in VERIFICATION_STATUS:
        raise PassportError(f"unknown verification status {verification_status!r}")
    if not _SHA256_RE.match(parent_receipt_hash):
        raise PassportError("parent_receipt_hash must be 64 lowercase hex")

    p: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "object_id": object_id,
        "theorem_id": theorem_id,
        "route_id": route_id,
        "station": station,
        "source_commit": source_commit,
        "source_hash": source_hash,
        "parent_receipt_hash": parent_receipt_hash,
        "proof_system": proof_system,
        "compiler_version": compiler_version,
        "environment_lock_hash": environment_lock_hash,
        "assumptions": sorted(assumptions),
        "verification_status": verification_status,
        "evidence_class": evidence_class,
        "scope": scope,
        "run_url": run_url,
        "artifact_hashes": sorted(artifact_hashes),
        "timestamp_utc": timestamp_utc or utc_now(),
    }
    p["receipt_hash"] = compute_receipt_hash(p)
    return p


def verify_passport(passport: dict[str, Any]) -> tuple[bool, str]:
    """Recompute the digest. A hash proves integrity only, never authorship."""
    claimed = passport.get("receipt_hash")
    if not isinstance(claimed, str) or not _SHA256_RE.match(claimed):
        return False, "missing or malformed receipt_hash"
    actual = compute_receipt_hash(passport)
    if actual != claimed:
        return False, f"receipt_hash mismatch: claims {claimed[:12]}…, computes {actual[:12]}…"
    return True, "receipt hash matches canonical serialization"


def verify_chain(passports: list[dict[str, Any]]) -> tuple[bool, list[str]]:
    """Check each receipt's own digest and its link to the previous receipt."""
    notes: list[str] = []
    ok = True
    expected_parent = GENESIS_PARENT
    seen: set[str] = set()
    for i, p in enumerate(passports):
        good, why = verify_passport(p)
        if not good:
            ok = False
            notes.append(f"[{i}] {p.get('theorem_id', '?')}: {why}")
            # A tampered body invalidates every link downstream of it.
        if p.get("parent_receipt_hash") != expected_parent:
            ok = False
            notes.append(
                f"[{i}] {p.get('theorem_id', '?')}: broken link — parent is "
                f"{str(p.get('parent_receipt_hash'))[:12]}…, expected {expected_parent[:12]}…")
        rh = p.get("receipt_hash")
        if rh in seen:
            ok = False
            notes.append(f"[{i}] duplicate receipt {str(rh)[:12]}… submitted twice")
        seen.add(rh)
        expected_parent = rh
    if ok:
        notes.append(f"chain intact across {len(passports)} receipt(s)")
    return ok, notes


def transport(passport: dict[str, Any], transformation: str,
              destination: str, authorized_class: str | None = None
              ) -> dict[str, Any]:
    """The Invariant Grammar transport law: (x, Q) |-> (T(x), M_T(Q)).

    Preserves identity lineage, dependency lineage, evidence class and
    verification history. `authorized_class` may only LOWER the fare.
    Raising it raises PassportError — transfer does not upgrade evidence.
    """
    current = passport["evidence_class"]
    new_class = current
    if authorized_class is not None:
        if authorized_class in DIRECTIVE_EVIDENCE_MAP:
            authorized_class = DIRECTIVE_EVIDENCE_MAP[authorized_class]
        if authorized_class not in EVIDENCE_CLASSES:
            raise PassportError(f"unknown evidence class {authorized_class!r}")
        if EVIDENCE_CLASSES.index(authorized_class) < EVIDENCE_CLASSES.index(current):
            raise PassportError(
                f"transport would upgrade evidence {current} -> {authorized_class}; "
                "transfer does not upgrade evidence")
        new_class = authorized_class

    moved = dict(passport)
    moved["parent_receipt_hash"] = passport["receipt_hash"]
    moved["evidence_class"] = new_class
    moved["station"] = destination
    moved["transformation"] = transformation
    moved["timestamp_utc"] = utc_now()
    moved.pop("receipt_hash", None)
    moved["receipt_hash"] = compute_receipt_hash(moved)
    return moved
