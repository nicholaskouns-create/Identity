#!/usr/bin/env python3
"""Bounded anonymous HTTP census of the Monorail's 54 catalogued exits.

Separate from the 17-door entry probe and the historical 177-link census.
Never request the two restricted Drive originals or the known-broken
historical Tower highlighter URL. Public HTTP outcomes are evidence, not
compiler certificates. No response bodies are stored.
"""
from __future__ import annotations

import json
import os
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urldefrag, urlsplit
from urllib.request import Request, urlopen

from probe_public_doors import read_corpus

OUTPUT = Path("monorail/live-exit-evidence.json")
HISTORICAL = {"links_followed": 177, "failures": 4,
              "status": "retained historical baseline; not re-crawled"}


def partition_exits(data: dict) -> tuple[list[dict], list[dict]]:
    public, excluded = [], []
    repairs = {r["id"]: r for r in data["repairs"]}
    for station in data["stations"]:
        for link in station["links"]:
            row = {"station": station["slug"], "label": link["label"],
                   "url": link["href"], "state": link["state"]}
            if link["state"] == "restricted":
                row["reason"] = "owner_only_original_not_requested"
                excluded.append(row)
            elif (link.get("repair") == "highlight"
                  and link["href"] == repairs["highlight"]["failed"]):
                row["reason"] = "historical_404_not_requested"
                excluded.append(row)
            else:
                parsed = urlsplit(link["href"])
                if parsed.scheme != "https" or not parsed.netloc:
                    raise ValueError("Non-HTTPS public exit: " + link["href"])
                public.append(row)
    if len(public) + len(excluded) != 54:
        raise ValueError("Catalogued exit identity count changed")
    if sorted(r["reason"] for r in excluded) != [
        "historical_404_not_requested",
        "owner_only_original_not_requested",
        "owner_only_original_not_requested",
    ]:
        raise ValueError("Historical exclusions changed; review explicitly")
    return public, excluded


def probe_exit(row: dict, timeout: float = 15) -> dict:
    result = dict(row)
    result.update(http_status=None, final_url=None, outcome="network_error")
    # Fragments are browser-local and never part of the HTTP request.
    url, _ = urldefrag(row["url"])
    req = Request(url, headers={
        "User-Agent": "MathematicalCity-Monorail-Exit-Audit/1.0",
        "Accept": "*/*",
    })
    try:
        with urlopen(req, timeout=timeout) as response:
            result["http_status"] = response.status
            result["final_url"] = response.geturl()
            response.read(1)
            result["outcome"] = ("http_ok" if 200 <= response.status < 400
                                 else "http_error")
    except HTTPError as error:
        result["http_status"] = error.code
        result["final_url"] = error.geturl()
        result["outcome"] = "http_error"
    except (URLError, TimeoutError, OSError) as error:
        result["error_type"] = type(error).__name__
        result["outcome"] = "network_error"
    return result


def audit(data: dict, workers: int = 6) -> dict:
    public, excluded = partition_exits(data)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        results = list(pool.map(probe_exit, public))
    return {
        "audit_type": "anonymous_catalogued_exit_http_get",
        "observed_utc": datetime.now(timezone.utc).isoformat(),
        "source_commit": os.environ.get("GITHUB_SHA", "local"),
        "catalogued_exit_count": 54,
        "public_exit_attempts": len(public),
        "excluded_originals": excluded,
        "historical_census": HISTORICAL,
        "http_ok": sum(r["outcome"] == "http_ok" for r in results),
        "http_error": sum(r["outcome"] == "http_error" for r in results),
        "network_error": sum(r["outcome"] == "network_error" for r in results),
        "results": results,
        "evidence_boundary": (
            "HTTP GET only; no browser execution, compiler certification, "
            "private Drive read, or repeat of the original 177-link census"
        ),
    }


def main() -> int:
    result = audit(read_corpus())
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n",
                      encoding="utf-8")
    print("Catalogued exits: 54; attempted public: "
          + str(result["public_exit_attempts"])
          + "; restricted/historical excluded: "
          + str(len(result["excluded_originals"])))
    print("HTTP OK: " + str(result["http_ok"])
          + "; HTTP failures: " + str(result["http_error"])
          + "; transport failures: " + str(result["network_error"]))
    for row in result["results"]:
        print(str(row["http_status"] or "NETWORK") + " "
              + row["station"] + "/" + row["label"] + ": " + row["url"])
    print("Evidence:", OUTPUT)
    # This job is an observation, not a release gate. Preserve all failed
    # destinations in the artifact for one-defect-per-run remediation.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
