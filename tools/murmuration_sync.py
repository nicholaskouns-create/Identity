#!/usr/bin/env python3
"""Publish a public, read-only, provenance-aware GitHub snapshot for Murmuration.

Only public GitHub repository metadata is collected. Never fetch secrets, private
documents, or repository contents. No central authority over source repositories.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import urllib.error
import urllib.request

REPOS = ("Identity", "E47-Kartekeya")
OWNER = "nicholaskouns-create"
SCHEMA = "mc.murmuration.feed/1"

def fetch(repo, token=None):
    url = f"https://api.github.com/repos/{OWNER}/{repo}/commits?per_page=1"
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "murmuration-public-feed/1"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=20) as response:
        obj = json.load(response)
    if not isinstance(obj, list) or not obj:
        raise ValueError("GitHub returned no commit")
    item = obj[0]
    sha = item["sha"]
    if len(sha) != 40 or any(c not in "0123456789abcdef" for c in sha):
        raise ValueError("Invalid commit SHA")
    return {"id": f"github:{OWNER}/{repo}", "kind": "public_github_repository",
            "url": f"https://github.com/{OWNER}/{repo}",
            "commit_sha": sha, "commit_url": item["html_url"],
            "source_timestamp": item["commit"]["committer"]["date"],
            "status": "ok"}

def build(fetcher, timestamp):
    sources = []
    for repo in REPOS:
        try:
            sources.append(fetcher(repo))
        except (urllib.error.URLError, ValueError, KeyError, TimeoutError, OSError) as exc:
            sources.append({"id": f"github:{OWNER}/{repo}", "kind": "public_github_repository",
                            "url": f"https://github.com/{OWNER}/{repo}", "status": "unavailable",
                            "error_class": type(exc).__name__})
    body = {"schema": SCHEMA, "generated_at": timestamp, "scope": "public-github-metadata-only",
            "sources": sources, "authority": "informational-only",
            "limitations": ["No private Notion, Drive, Supabase or Grok access",
                            "A source commit SHA is not a theorem certificate",
                            "No browser execution or deployed instrument health verified"]}
    raw = json.dumps(body, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    body["sha256"] = hashlib.sha256(raw).hexdigest()
    return body

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="murmuration/feed.json")
    args = parser.parse_args()
    now = dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")
    doc = build(lambda r: fetch(r, os.environ.get("GITHUB_TOKEN")), now)
    path = pathlib.Path(args.output)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{path}: {sum(s['status']=='ok' for s in doc['sources'])}/{len(doc['sources'])} sources")
    if not any(s["status"] == "ok" for s in doc["sources"]):
        raise SystemExit("No sources reachable; feed not publishable")

if __name__ == "__main__":
    main()
