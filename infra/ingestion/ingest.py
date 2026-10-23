"""Server-side private ingestion. Python stdlib only; requires env configuration.
Never run with credentials in a browser or GitHub Actions from untrusted PRs.
Usage: MNEMOSYNE_DB_URL=... MNEMOSYNE_SERVICE_KEY=... python ingest.py file.pdf
The database is in an unexposed schema; this script uploads to private Storage.
Metadata registration requires a separate restricted server-side DB connector.
"""
from pathlib import Path
import hashlib
import json
import mimetypes
import os
import sys
import urllib.request
from urllib.parse import quote

PROJECT_URL = "https://gpkjvihkyectnenvnbng.supabase.co"
BUCKET = "mnemosyne-private"
MAX_BYTES = 50 * 1024 * 1024

def receipt(path):
    p = Path(path)
    if not p.is_file() or p.is_symlink():
        raise ValueError("Expected regular, non-symlink file")
    data = p.read_bytes()
    if len(data) > MAX_BYTES:
        raise ValueError("File exceeds 50 MiB")
    digest = hashlib.sha256(data).hexdigest()
    mime = mimetypes.guess_type(p.name)[0] or "application/octet-stream"
    if mime not in {"application/pdf","text/plain","text/markdown","application/json","text/html","application/octet-stream"}:
        raise ValueError("Unsupported media type")
    key = "sha256/" + digest[:2] + "/" + digest
    return {"name":p.name,"sha256":digest,"size":len(data),"mime":mime,"key":key}, data

def upload(path):
    record, data = receipt(path)
    secret = os.environ.get("MNEMOSYNE_SERVICE_KEY")
    if not secret:
        raise RuntimeError("MNEMOSYNE_SERVICE_KEY is required; never commit it")
    url = PROJECT_URL + "/storage/v1/object/" + BUCKET + "/" + quote(record["key"], safe="/")
    req = urllib.request.Request(url, data=data, method="POST", headers={
        "apikey": secret, "Authorization": "Bearer " + secret,
        "Content-Type": record["mime"], "x-upsert": "false"
    })
    with urllib.request.urlopen(req, timeout=60) as resp:
        record["upload_status"] = resp.status
    return record

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python ingest.py FILE")
    print(json.dumps(upload(sys.argv[1]), sort_keys=True))
