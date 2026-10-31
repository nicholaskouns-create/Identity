#!/usr/bin/env python3
"""Anonymous, bounded HTTP evidence for the 17 public Monorail doors.

This probes public door URLs only. It does not fetch restricted Drive originals,
rewrite the historical 177-link/four-failure census, or certify compiler results.
An HTTP failure, transport failure and source-only check are distinct outcomes.
"""
from __future__ import annotations

import argparse
import hashlib
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

CORPUS = Path(__file__).with_name("index.html")
SOURCE_URL = "https://nicholaskouns-create.github.io/Identity/monorail/"


def read_corpus(path: Path = CORPUS) -> dict:
    html = path.read_text(encoding="utf-8")
    match = re.search(r'<script id="data" type="application/json">([\s\S]*?)</script>', html)
    if not match:
        raise ValueError("Monorail embedded source data absent")
    data = json.loads(match.group(1))
    stations = data["stations"]
    if len(stations) != 17 or len({s["slug"] for s in stations}) != 17:
        raise ValueError("Monorail 17-door identity census changed")
    if len(data["repairs"]) != 4:
        raise ValueError("Historical four-failure ledger changed")
    for s in stations:
        if not s["href"].startswith("https://nicholaskouns-create.github.io/"):
            raise ValueError("Door outside declared public Pages host: " + s["href"])
    return data


def probe_door(station: dict, timeout: float = 12) -> dict:
    url = station["href"]
    record = {"slug": station["slug"], "title": station["name"],
              "url": url, "http_status": None, "final_url": None,
              "outcome": "network_error"}
    req = Request(url, headers={"User-Agent": "MathematicalCity-Monorail-Audit/1.0",
                                "Accept": "text/html,*/*"})
    try:
        with urlopen(req, timeout=timeout) as response:
            record["http_status"] = response.status
            record["final_url"] = response.geturl()
            response.read(1)
            record["outcome"] = "http_ok" if 200 <= response.status < 400 else "http_error"
    except HTTPError as error:
        record["http_status"] = error.code
        record["final_url"] = error.geturl()
        record["outcome"] = "http_error"
    except (URLError, TimeoutError, OSError) as error:
        record["error_type"] = type(error).__name__
        record["outcome"] = "network_error"
    return record



def probe_monorail_source(path: Path = CORPUS, timeout: float = 12) -> dict:
    """Check the public Monorail entry and byte-compare it to the checked-out source."""
    expected = hashlib.sha256(path.read_bytes()).hexdigest()
    record = {"url": SOURCE_URL, "http_status": None, "outcome": "network_error",
              "source_sha256": expected, "served_sha256": None, "matches_source": None}
    req = Request(SOURCE_URL, headers={"User-Agent": "MathematicalCity-Monorail-Audit/1.0",
                                      "Accept": "text/html,*/*"})
    try:
        with urlopen(req, timeout=timeout) as response:
            payload = response.read()
            record["http_status"] = response.status
            record["served_sha256"] = hashlib.sha256(payload).hexdigest()
            record["matches_source"] = record["served_sha256"] == expected
            record["outcome"] = ("http_error" if response.status >= 400
                                 else "http_ok" if record["matches_source"]
                                 else "source_mismatch")
    except HTTPError as error:
        record["http_status"] = error.code
        record["outcome"] = "http_error"
    except (URLError, TimeoutError, OSError) as error:
        record["error_type"] = type(error).__name__
        record["outcome"] = "network_error"
    return record


def audit(data: dict, workers: int = 4) -> dict:
    with ThreadPoolExecutor(max_workers=workers) as pool:
        results = list(pool.map(probe_door, data["stations"]))
    links = [link for station in data["stations"] for link in station["links"]]
    restricted = [link["href"] for link in links if link.get("state") == "restricted"]
    return {
        "audit_type": "anonymous_public_door_http_get",
        "observed_utc": datetime.now(timezone.utc).isoformat(),
        "source_commit": os.environ.get("GITHUB_SHA", "local"),
        "source_url": SOURCE_URL,
        "source_door_count": len(data["stations"]),
        "source_exit_count": len(links),
        "historical_census": {"links_followed": 177, "failures": 4,
                              "status": "retained historical baseline, not a fresh crawl"},
        "historical_failures": [{"url": r["failed"], "status": r["status"],
                                 "repair_id": r["id"]} for r in data["repairs"]],
        "restricted_originals_not_requested": restricted,
        "monorail_entry": probe_monorail_source(),
        "doors": results,
        "http_ok": sum(r["outcome"] == "http_ok" for r in results),
        "http_error": sum(r["outcome"] == "http_error" for r in results),
        "network_error": sum(r["outcome"] == "network_error" for r in results),
        "claim_boundary": "HTTP GET only; not a browser render, JS test, exit crawl or Pages revision attestation",
    }


def exit_status(result: dict, allow_undeployed_source: bool = False) -> int:
    """Keep live status failures strict; only permit expected PR source divergence."""
    entry = result["monorail_entry"]
    if result["http_error"] or entry["outcome"] == "http_error":
        return 1
    if entry["outcome"] == "source_mismatch" and not allow_undeployed_source:
        return 1
    if result["network_error"] or entry["outcome"] == "network_error":
        return 2
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="monorail/live-door-evidence.json")
    parser.add_argument("--allow-undeployed-source", action="store_true",
                        help="PR only: record expected served-vs-feature-source mismatch without failing")
    args = parser.parse_args(argv)
    result = audit(read_corpus())
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    entry = result["monorail_entry"]
    print(f"Monorail entry: {entry['http_status'] or 'NETWORK'}; "
          f"served bytes match source: {entry['matches_source']}")
    print(f"17 public doors: {result['http_ok']} HTTP OK; "
          f"{result['http_error']} HTTP failures; "
          f"{result['network_error']} transport failures")
    for door in result["doors"]:
        print(f"  {door['http_status'] or 'NETWORK'} {door['slug']}: {door['url']}")
    print("Evidence:", out)
    if args.allow_undeployed_source and entry["outcome"] == "source_mismatch":
        print("PR source differs from currently deployed main; mismatch retained in evidence.")
    return exit_status(result, allow_undeployed_source=args.allow_undeployed_source)


if __name__ == "__main__":
    sys.exit(main())
