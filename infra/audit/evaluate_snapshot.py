"""Evaluate a metadata-only Supabase audit snapshot without network or secrets.

Never equate a configuration check with authenticated end-to-end execution.
"""
import json
import sys

SCHEMA = "mnemosyne_monorail_audit.v1"
EXPECTED = {
    "worker_nologin": True,
    "worker_no_bypassrls": True,
    "private_bucket": True,
    "source_rls": True,
    "storage_rls": True,
    "anon_schema_usage": False,
    "authenticated_schema_usage": False,
    "public_table_grants": 0,
    "worker_expected_grants": 2,
    "worker_unexpected_grants": 0,
    "invalid_content_paths": 0,
    "invalid_object_paths": 0,
}


def _nonnegative_int(value):
    return type(value) is int and value >= 0


def evaluate(snapshot):
    if not isinstance(snapshot, dict) or snapshot.get("schema") != SCHEMA:
        raise ValueError("Unexpected or missing audit schema")
    m, rail = snapshot.get("mnemosyne"), snapshot.get("monorail")
    if not isinstance(m, dict) or not isinstance(rail, dict):
        raise ValueError("Missing audit sections")
    for field in ("source_documents", "private_objects"):
        if not _nonnegative_int(m.get(field)):
            raise ValueError("Missing or invalid count: " + field)
    for field in ("receipt_triggers", "privileged_receipt_triggers"):
        if not _nonnegative_int(rail.get(field)):
            raise ValueError("Missing or invalid count: " + field)
    checks = {key: "PASS" if type(m.get(key)) is type(expected) and
              m.get(key) == expected else "FAIL" for key, expected in EXPECTED.items()}
    for field in ("receipts_table_exists", "canonical_sql_exists"):
        if type(rail.get(field)) is not bool:
            raise ValueError("Missing or invalid Monorail field: " + field)
    return {
        "schema": SCHEMA,
        "security_baseline": "PASS" if all(v == "PASS" for v in checks.values()) else "FAIL",
        "checks": checks,
        "ingestion_end_to_end": "UNVERIFIED",
        "hosted_storage_roundtrip": "UNVERIFIED",
        "monorail_receipt_ledger": "PRESENT_NOT_VALIDATED" if rail["receipts_table_exists"] else "NOT_DEPLOYED",
        "monorail_sql_canonicalizer": "PRESENT_NOT_VALIDATED" if rail["canonical_sql_exists"] else "NOT_DEPLOYED",
        "independent_receipt_validator": "NOT_ASSESSED",
        "kx_station_reconciliation": "NOT_ASSESSED",
        "threat20_privileged_trigger_bypass": "NOT_ASSESSED",
        "encrypted_backup_restore": "NOT_ASSESSED",
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python evaluate_snapshot.py snapshot.json")
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, list) and len(data) == 1 and isinstance(data[0], dict):
        data = data[0].get("snapshot", data[0])
    print(json.dumps(evaluate(data), sort_keys=True, indent=2))


if __name__ == "__main__":
    main()
