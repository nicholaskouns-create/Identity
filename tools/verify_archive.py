"""Read-only SHA-256 receipt verification for exported Mnemosyne JSON archives.

Usage: python tools/verify_archive.py /path/outside/repo/mnemosyne-archive.json
No network access, database credentials, record content output, or file writes.
This checks archive integrity, not authorship, timestamps, proofs, or evidence validity.
It rejects duplicate IDs, a stricter precaution than the browser importer.
"""
import argparse
import hashlib
import hmac
import json
from pathlib import Path

from migrate_archive import canonical

FORMAT = "mnemosyne-archive-v1"
MAX_BYTES = 20_000_000
MAX_RECORDS = 10_000
RECEIPT_FIELDS = ("id", "title", "kind", "content", "created_at", "sha256")


def verify_archive(data):
    """Return a count or raise ValueError; never expose record contents."""
    if not isinstance(data, dict) or data.get("format") != FORMAT:
        raise ValueError("Unsupported archive format")
    records = data.get("records")
    if not isinstance(records, list) or len(records) > MAX_RECORDS:
        raise ValueError("Invalid archive records array or count")
    seen = set()
    for index, record in enumerate(records):
        if not isinstance(record, dict) or any(
            not isinstance(record.get(key), str) for key in RECEIPT_FIELDS
        ):
            raise ValueError(f"Record {index}: missing or invalid receipt fields")
        if record["id"] in seen:
            raise ValueError(f"Record {index}: duplicate ID (import would overwrite)")
        seen.add(record["id"])
        expected = hashlib.sha256(canonical(record).encode("utf-8")).hexdigest()
        if not hmac.compare_digest(record["sha256"], expected):
            raise ValueError(f"Record {index}: SHA-256 receipt mismatch")
    return len(records)


def verify_file(path):
    if path.stat().st_size > MAX_BYTES:
        raise ValueError("Archive exceeds 20 MB browser import limit")
    return verify_archive(json.loads(path.read_text(encoding="utf-8")))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, help="Local exported Mnemosyne JSON archive")
    args = parser.parse_args(argv)
    try:
        count = verify_file(args.archive)
    except (OSError, UnicodeError, json.JSONDecodeError):
        print("ARCHIVE_RECEIPTS_FAIL: cannot read or parse archive")
        return 1
    except ValueError as exc:
        # Only controlled error strings and record indices, never record contents.
        print(f"ARCHIVE_RECEIPTS_FAIL: {exc}")
        return 1
    print(f"ARCHIVE_RECEIPTS_PASS: {count} records; integrity only, read-only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
