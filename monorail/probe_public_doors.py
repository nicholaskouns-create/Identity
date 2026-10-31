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
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

CORPUS = Path(__file__).with_name("index.html")
SOURCE_URL = "https://nicholaskouns-create.github.io/Identity/monorail/"

# Historical 17-door source identities, not a redirect policy or an alias
# registry. A station may be intentionally moved only with an explicit
# reviewed update to this audit fixture; the independent apps stay untouched.
EXPECTED_STATION_URLS = {
    "home": "https://nicholaskouns-create.github.io/",
    "city": "https://nicholaskouns-create.github.io/E47-Kartekeya/",
    "work": "https://nicholaskouns-create.github.io/work/",
    "identity": "https://nicholaskouns-create.github.io/Identity/",
    "mnemosyne": "https://nicholaskouns-create.github.io/Identity/site/",
    "lean": "https://nicholaskouns-create.github.io/Identity/site/proof/lean-coq/",
    "plate": "https://nicholaskouns-create.github.io/e47-formal-validation.html",
    "spectra": "https://nicholaskouns-create.github.io/Identity/site/spectra/",
    "observatory": "https://nicholaskouns-create.github.io/E47-Kartekeya/interfaces/observatory/?view=learn",
    "instruments": "https://nicholaskouns-create.github.io/E47-Kartekeya/interfaces/instruments/",
    "neutrino": "https://nicholaskouns-create.github.io/E47-Kartekeya/interfaces/neutrino-flavor/",
    "matrix": "https://nicholaskouns-create.github.io/E47-Kartekeya/interfaces/matrix/",
    "time": "https://nicholaskouns-create.github.io/Time/",
    "planetarium": "https://nicholaskouns-create.github.io/E47-Kartekeya/interfaces/e47-planetarium/",
    "noesis": "https://nicholaskouns-create.github.io/noesis/",
    "lucas": "https://nicholaskouns-create.github.io/lucas-companion.html",
    "tower": "https://nicholaskouns-create.github.io/tower/#/explore",
}


# Historical repair evidence is immutable input, not a live HTTP result.
# Pin all four original URLs and classifications so the public 17-door
# receipt cannot silently relabel an owner-only 401 as a repaired 404/200.
# New findings belong in separate, additive evidence, not in this baseline.
EXPECTED_HISTORICAL_REPAIRS = {
    "highlight": ("404", "https://cdn.jsdelivr.net/npm/highlight.js@11.10.0/lib/highlight.min.js"),
    "paper": ("404", "https://raw.githubusercontent.com/nicholaskouns-create/E47-Kartekeya/main/research/e47/papers/fib_lucas_tower/tower_paper.tex"),
    "mirror": ("401", "https://docs.google.com/document/d/1wCmn5J4Tjo0qVV5AOoHUxD1tXComhPf7lU1ntzKtaMs/edit"),
    "modsync": ("401", "https://drive.google.com/file/d/1-bCyEuWcN1rtRb1IJF02O8tTe7RbmaEC/view"),
}


def read_corpus(path: Path = CORPUS) -> dict:
    html = path.read_text(encoding="utf-8")
    match = re.search(r'<script id="data" type="application/json">([\s\S]*?)</script>', html)
    if not match:
        raise ValueError("Monorail embedded source data absent")
    data = json.loads(match.group(1))
    stations = data["stations"]
    if len(stations) != 17 or len({s["slug"] for s in stations}) != 17:
        raise ValueError("Monorail 17-door identity census changed")
    observed_urls = {s["slug"]: s["href"] for s in stations}
    if observed_urls != EXPECTED_STATION_URLS:
        changed = sorted(
            slug for slug in set(observed_urls) | set(EXPECTED_STATION_URLS)
            if observed_urls.get(slug) != EXPECTED_STATION_URLS.get(slug)
        )
        raise ValueError("Door URL identity changed; review explicitly: " + ", ".join(changed))
    repairs = data["repairs"]
    if len(repairs) != 4 or len({r["id"] for r in repairs}) != 4:
        raise ValueError("Historical four-failure ledger changed")
    observed_repairs = {r["id"]: (str(r["status"]), r["failed"]) for r in repairs}
    if observed_repairs != EXPECTED_HISTORICAL_REPAIRS:
        changed = sorted(
            repair_id for repair_id in set(observed_repairs) | set(EXPECTED_HISTORICAL_REPAIRS)
            if observed_repairs.get(repair_id) != EXPECTED_HISTORICAL_REPAIRS.get(repair_id)
        )
        raise ValueError("Historical repair identity changed; review explicitly: "
                         + ", ".join(changed))
    for s in stations:
        if not s["href"].startswith("https://nicholaskouns-create.github.io/"):
            raise ValueError("Door outside declared public Pages host: " + s["href"])
    return data


class DoorIdentityRedirectBlocked(HTTPError):
    """A redirect away from the requested door; destination not fetched."""


class SameDoorRedirect(HTTPRedirectHandler):
    """Allow trailing-slash/query redirects, never a different door or host."""

    def __init__(self, original_url: str):
        super().__init__()
        self.original = urlsplit(original_url)

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        target = urlsplit(newurl)
        original_path = self.original.path.rstrip("/") or "/"
        target_path = target.path.rstrip("/") or "/"
        if (target.scheme != self.original.scheme
                or target.netloc.lower() != self.original.netloc.lower()
                or target_path != original_path):
            # Never follow an unreviewed destination. Do not log query tokens.
            safe_url = target._replace(query="", fragment="").geturl()
            raise DoorIdentityRedirectBlocked(
                safe_url, code, "door_identity_redirect_blocked", headers, fp
            )
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def safe_door_open(req: Request, timeout: float):
    return build_opener(SameDoorRedirect(req.full_url)).open(req, timeout=timeout)


def receipt_door_url(observed_url: str, source_url: str) -> str:
    """Redact unreviewed redirect queries from public door HTTP receipts.

    HTTP redirects may need a query to complete the request, but a query
    introduced by the destination is not part of the 17-door source fixture
    and could contain a credential. Preserve only the exact pinned query.
    """
    observed, source = urlsplit(observed_url), urlsplit(source_url)
    same_door = (
        observed.scheme == source.scheme
        and observed.netloc.lower() == source.netloc.lower()
        and (observed.path.rstrip("/") or "/") == (source.path.rstrip("/") or "/")
    )
    if same_door and observed.query == source.query:
        return observed._replace(fragment="").geturl()
    return observed._replace(query="", fragment="").geturl()


def probe_door(station: dict, timeout: float = 12) -> dict:
    url = station["href"]
    record = {"slug": station["slug"], "title": station["name"],
              "url": url, "http_status": None, "final_url": None,
              "outcome": "network_error"}
    req = Request(url, headers={"User-Agent": "MathematicalCity-Monorail-Audit/1.0",
                                "Accept": "text/html,*/*"})
    try:
        with safe_door_open(req, timeout=timeout) as response:
            record["http_status"] = response.status
            record["final_url"] = receipt_door_url(response.geturl(), url)
            response.read(1)
            record["outcome"] = "http_ok" if 200 <= response.status < 400 else "http_error"
    except DoorIdentityRedirectBlocked as error:
        record["http_status"] = error.code
        record["final_url"] = receipt_door_url(error.geturl(), url)
        record["outcome"] = "door_identity_redirect_blocked"
    except HTTPError as error:
        record["http_status"] = error.code
        record["final_url"] = receipt_door_url(error.geturl(), url)
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
        with safe_door_open(req, timeout=timeout) as response:
            payload = response.read()
            record["http_status"] = response.status
            record["served_sha256"] = hashlib.sha256(payload).hexdigest()
            record["matches_source"] = record["served_sha256"] == expected
            record["outcome"] = ("http_error" if response.status >= 400
                                 else "http_ok" if record["matches_source"]
                                 else "source_mismatch")
    except DoorIdentityRedirectBlocked as error:
        record["http_status"] = error.code
        record["outcome"] = "door_identity_redirect_blocked"
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
        "http_error": sum(r["outcome"] in {"http_error", "door_identity_redirect_blocked"}
                          for r in results),
        "door_identity_redirect_blocked": sum(
            r["outcome"] == "door_identity_redirect_blocked" for r in results
        ),
        "network_error": sum(r["outcome"] == "network_error" for r in results),
        "claim_boundary": "HTTP GET only; not a browser render, JS test, exit crawl or Pages revision attestation",
    }


def exit_status(result: dict, allow_undeployed_source: bool = False) -> int:
    """Keep live status failures strict; only permit expected PR source divergence."""
    entry = result["monorail_entry"]
    if (result["http_error"]
            or entry["outcome"] in {"http_error", "door_identity_redirect_blocked"}):
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
    print(f"Door identity redirects blocked: {result['door_identity_redirect_blocked']}")
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
