"""Offline, fail-closed evaluator for a *trusted operator's* read-only SQL snapshot.

No network, credentials, database writes, document content or public access.
The snapshot is produced by mnemosyne_monorail_posture.sql. The checker deliberately
keeps the Mnemosyne and Monorail architectures separate.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

SECURITY = (
    'bucket_present', 'bucket_private', 'worker_present', 'worker_no_login',
    'worker_no_bypassrls', 'source_rls_enabled', 'anon_schema_denied',
    'authenticated_schema_denied', 'worker_select', 'worker_insert',
    'worker_update_denied', 'worker_delete_denied',
    'worker_select_policy', 'worker_insert_policy',
)
# A blocked operational milestone is not a security regression. In particular,
# a missing receipt table cannot be interpreted as protection against Threat 20.
MILESTONES = (
    'restricted_runtime_login_present', 'monorail_receipts_present',
    'monorail_checkpoints_present',
)
COUNTS = ('source_rows', 'private_objects', 'monorail_receipt_trigger_count')


def evaluate(snapshot: dict) -> dict:
    if not isinstance(snapshot, dict) or type(snapshot.get('schema_version')) is not int or snapshot['schema_version'] != 1:
        raise ValueError('Unsupported or missing snapshot schema_version')
    for key in SECURITY + MILESTONES:
        if type(snapshot.get(key)) is not bool:
            raise ValueError(f'Missing/non-boolean field: {key}')
    for key in COUNTS:
        if type(snapshot.get(key)) is not int or snapshot[key] < 0:
            raise ValueError(f'Missing/invalid nonnegative count: {key}')
    if snapshot.get('bucket_size_limit') is not None and (
        type(snapshot['bucket_size_limit']) is not int or snapshot['bucket_size_limit'] <= 0
    ):
        raise ValueError('Invalid bucket size limit')
    failures = sorted(k for k in SECURITY if not snapshot[k])
    blocked = sorted(k for k in MILESTONES if not snapshot[k])
    if not snapshot['monorail_receipts_present']:
        blocked.append('threat20_trigger_bypass_not_testable_without_receipt_table')
    else:
        # Trigger existence alone cannot certify its privileges or absence of bypass.
        blocked.append('threat20_privileged_trigger_bypass_not_independently_verified')
    # The following are deliberately not inferred from schema catalog evidence.
    blocked.extend(('hosted_ingest_readback_unverified', 'receipt_signature_unverified',
                    'independent_validator_unverified', 'encrypted_restore_unverified'))
    return {
        'status': 'FAIL' if failures else ('BLOCKED' if blocked else 'PASS'),
        'security_regressions': failures,
        'unverified_milestones': sorted(set(blocked)),
        'observations': {key: snapshot[key] for key in COUNTS},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('snapshot', type=Path, help='JSON output of the read-only SQL query')
    args = parser.parse_args()
    try:
        raw = json.loads(args.snapshot.read_text(encoding='utf-8'))
        # Accept either the JSON object itself or the SQL row wrapper.
        data = raw['posture'] if isinstance(raw, dict) and 'posture' in raw else raw
        report = evaluate(data)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(json.dumps({'status': 'INVALID', 'error': str(exc)}, sort_keys=True))
        return 1
    print(json.dumps(report, indent=2, sort_keys=True))
    return 1 if report['status'] == 'FAIL' else (2 if report['status'] == 'BLOCKED' else 0)


if __name__ == '__main__':
    raise SystemExit(main())
