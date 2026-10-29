"""Mnemosyne private content-addressed ingestion (stdlib HTTP, optional psycopg).

Offline: python ingest.py FILE
Trusted worker only: python ingest.py FILE --execute
Secrets MNEMOSYNE_SERVICE_KEY and MNEMOSYNE_DB_DSN must be provisioned
externally. Never expose them in Git, CI, logs, or a browser.

Workflow: SHA-256 exact bytes -> private upload (no upsert) -> authenticated
download/readback and SHA-256 -> transactional DB registration. Never DELETE.
Failed registration may leave an orphaned object for separate reconciliation.
The DB DSN must be a narrowly scoped PostgreSQL role with SELECT/INSERT
on mnemosyne_private.source_documents, not a Supabase API service key.
"""
from pathlib import Path
import hashlib
import json
import mimetypes
import os
import stat
import sys
import urllib.error
import urllib.request
from urllib.parse import quote

PROJECT_URL = "https://gpkjvihkyectnenvnbng.supabase.co"
BUCKET = "mnemosyne-private"
MAX_BYTES = 50 * 1024 * 1024
ALLOWED_MIME = frozenset({
    "application/pdf", "text/plain", "text/markdown", "application/json",
    "text/html", "application/octet-stream",
})


class IntegrityError(RuntimeError):
    """Stored bytes do not match the local SHA-256 receipt."""


def receipt(path):
    p = Path(path)
    if p.is_symlink() or not p.is_file():
        raise ValueError("Expected regular, non-symlink file")
    with p.open("rb") as f:
        if not stat.S_ISREG(os.fstat(f.fileno()).st_mode):
            raise ValueError("Expected regular file")
        data = f.read(MAX_BYTES + 1)
    if not data or len(data) > MAX_BYTES:
        raise ValueError("File must be nonempty and at most 50 MiB")
    digest = hashlib.sha256(data).hexdigest()
    mime = mimetypes.guess_type(p.name)[0] or "application/octet-stream"
    if mime not in ALLOWED_MIME:
        raise ValueError("Unsupported media type")
    key = "sha256/" + digest[:2] + "/" + digest
    return {"name": p.name, "sha256": digest, "size": len(data),
            "mime": mime, "key": key}, data


def _object_url(base_url, key):
    parts = key.split("/")
    if not (len(parts) == 3 and parts[0] == "sha256" and
            len(parts[2]) == 64 and parts[1] == parts[2][:2] and
            all(c in "0123456789abcdef" for c in parts[2])):
        raise ValueError("Invalid content-addressed storage key")
    return base_url.rstrip("/") + "/storage/v1/object/" + BUCKET + "/" + quote(key, safe="/")


def _request(url, token, *, method, data=None, mime=None, timeout=60):
    headers = {"apikey": token, "Authorization": "Bearer " + token}
    if mime:
        headers["Content-Type"] = mime
    if method == "POST":
        headers["x-upsert"] = "false"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as response:
        if method == "GET":
            payload = response.read(MAX_BYTES + 1)
            if len(payload) > MAX_BYTES:
                raise IntegrityError("Stored object exceeds 50 MiB")
            return payload
        return response.status


def upload_and_verify(record, data, token, *, base_url=PROJECT_URL):
    if len(data) != record["size"] or hashlib.sha256(data).hexdigest() != record["sha256"]:
        raise IntegrityError("Local payload changed since receipt")
    url = _object_url(base_url, record["key"])
    existed = False
    try:
        status = _request(url, token, method="POST", data=data, mime=record["mime"])
        if status not in (200, 201):
            raise RuntimeError("Unexpected private storage upload status")
    except urllib.error.HTTPError as exc:
        duplicate = exc.code == 409
        if exc.code == 400:
            try:
                error = json.loads(exc.read(4096))
                duplicate = (str(error.get("statusCode")) == "409" or
                             error.get("error") == "Duplicate")
            except (ValueError, AttributeError):
                duplicate = False
        if not duplicate:
            raise
        existed = True
    stored = _request(url, token, method="GET")
    if len(stored) != record["size"] or hashlib.sha256(stored).hexdigest() != record["sha256"]:
        raise IntegrityError("Private Storage readback SHA-256 mismatch")
    return "existing_verified" if existed else "uploaded_verified"


# Partial unique index mnemosyne_source_storage_path_unique deployed 2026-10-25.
INSERT_SQL = """
INSERT INTO mnemosyne_private.source_documents
    (title, source_sha256, storage_path, evidence_class, metadata)
VALUES (%s, %s, %s, %s, %s::jsonb)
ON CONFLICT (storage_path) WHERE storage_path IS NOT NULL DO NOTHING
RETURNING id, source_sha256
"""
LOOKUP_SQL = """
SELECT id, source_sha256 FROM mnemosyne_private.source_documents
WHERE storage_path = %s
"""


def register_metadata(record, connection):
    meta = json.dumps({"mime": record["mime"], "size": record["size"]}, sort_keys=True)
    with connection.transaction():
        with connection.cursor() as cursor:
            cursor.execute(INSERT_SQL, (record["name"], record["sha256"],
                                        record["key"], "historical_source", meta))
            row = cursor.fetchone()
            if row is None:
                cursor.execute(LOOKUP_SQL, (record["key"],))
                row = cursor.fetchone()
                if row is None or str(row[1]) != record["sha256"]:
                    raise IntegrityError("Storage key conflicts with another source digest")
                return str(row[0]), "existing_verified"
            return str(row[0]), "registered"


def ingest(path, *, token, connection, base_url=PROJECT_URL):
    record, data = receipt(path)
    storage_state = upload_and_verify(record, data, token, base_url=base_url)
    document_id, db_state = register_metadata(record, connection)
    return {"sha256": record["sha256"], "size": record["size"],
            "storage_path": record["key"], "storage": storage_state,
            "registration": db_state, "document_id": document_id}


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) not in (1, 2) or (len(argv) == 2 and argv[1] != "--execute"):
        raise SystemExit("Usage: python ingest.py FILE [--execute]")
    if len(argv) == 1:
        r, _ = receipt(argv[0])
        print(json.dumps({"sha256": r["sha256"], "size": r["size"],
                          "storage_path": r["key"], "mode": "offline_receipt"}, sort_keys=True))
        return
    token = os.environ.get("MNEMOSYNE_SERVICE_KEY")
    dsn = os.environ.get("MNEMOSYNE_DB_DSN")
    if not token or not dsn:
        raise RuntimeError("MNEMOSYNE_SERVICE_KEY and MNEMOSYNE_DB_DSN required externally")
    try:
        import psycopg
    except ImportError as exc:
        raise RuntimeError("Install psycopg[binary] in the trusted worker environment") from exc
    with psycopg.connect(dsn) as connection:
        result = ingest(argv[0], token=token, connection=connection)
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
