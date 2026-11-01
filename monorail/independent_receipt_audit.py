"""Read-only, independent Monorail v1 SHA-256 receipt-chain verifier.

Deliberately does not import monorail.passport, the browser verifier, or SQL.
Integrity is not authenticity: this tool neither signs nor validates signatures.
"""
from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import re
import sys
from pathlib import Path

GENESIS = "0" * 64
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
VERSION = "monorail.passport.v1"
MAX_BYTES = 8 * 1024 * 1024


class AuditError(ValueError):
    pass


def _unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise AuditError("duplicate JSON object key")
        result[key] = value
    return result


def _reject_number(value):
    raise AuditError("floating-point or non-finite JSON number outside v1 contract")


def parse_receipts(raw: bytes) -> list[dict]:
    if len(raw) > MAX_BYTES:
        raise AuditError("receipt bundle exceeds 8 MiB limit")
    try:
        data = json.loads(raw.decode("utf-8"), object_pairs_hook=_unique_pairs,
                          parse_float=_reject_number, parse_constant=_reject_number)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise AuditError("invalid UTF-8 JSON receipt bundle") from exc
    if not isinstance(data, list) or not data:
        raise AuditError("expected nonempty JSON array of passports")
    return data


def _validate(value, path="$", depth=0):
    if depth > 64:
        raise AuditError("nesting exceeds audit limit")
    if value is None or isinstance(value, bool):
        return
    if isinstance(value, int):
        if not (-(2 ** 63) < value < 2 ** 63):
            raise AuditError(f"{path}: integer outside canonical contract")
        return
    if isinstance(value, str):
        if "\x00" in value or any(0xD800 <= ord(c) <= 0xDFFF for c in value):
            raise AuditError(f"{path}: nonportable string")
        return
    if isinstance(value, list):
        for i, item in enumerate(value):
            _validate(item, f"{path}[{i}]", depth + 1)
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if not isinstance(key, str):
                raise AuditError(f"{path}: nonstring object key")
            _validate(key, path, depth + 1)
            _validate(item, f"{path}.{key}", depth + 1)
        return
    raise AuditError(f"{path}: unsupported canonical type")


def receipt_digest(passport: dict) -> str:
    if not isinstance(passport, dict):
        raise AuditError("passport is not an object")
    body = {key: value for key, value in passport.items() if key != "receipt_hash"}
    _validate(body)
    encoded = json.dumps(body, ensure_ascii=False, sort_keys=True,
                         separators=(",", ":"), allow_nan=False).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def audit(passports: list[dict]) -> dict:
    if not isinstance(passports, list) or not passports:
        raise AuditError("no receipts to audit")
    expected_parent = GENESIS
    seen = set()
    for index, passport in enumerate(passports):
        if not isinstance(passport, dict):
            raise AuditError(f"receipt {index}: expected object")
        if passport.get("schema_version") != VERSION:
            raise AuditError(f"receipt {index}: unsupported schema version")
        claimed = passport.get("receipt_hash")
        parent = passport.get("parent_receipt_hash")
        if not isinstance(claimed, str) or not HEX64.fullmatch(claimed):
            raise AuditError(f"receipt {index}: malformed digest")
        if not isinstance(parent, str) or not HEX64.fullmatch(parent):
            raise AuditError(f"receipt {index}: malformed parent")
        if not hmac.compare_digest(claimed, receipt_digest(passport)):
            raise AuditError(f"receipt {index}: digest mismatch")
        if not hmac.compare_digest(parent, expected_parent):
            raise AuditError(f"receipt {index}: chain link mismatch")
        if claimed in seen:
            raise AuditError(f"receipt {index}: duplicate digest")
        seen.add(claimed)
        expected_parent = claimed
    return {"status": "PASS", "schema_version": VERSION,
            "verified_receipts": len(passports), "head_sha256": expected_parent,
            "assurance": "integrity-and-ordered-chain-only",
            "signature_validation": "NOT_PERFORMED",
            "database_readback": "NOT_PERFORMED"}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path, help="UTF-8 JSON array of Monorail v1 passports")
    args = parser.parse_args(argv)
    try:
        raw = args.bundle.read_bytes()
        report = audit(parse_receipts(raw))
    except (AuditError, OSError) as exc:
        print(json.dumps({"status": "FAIL", "reason": str(exc)}))
        return 1
    print(json.dumps(report, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
