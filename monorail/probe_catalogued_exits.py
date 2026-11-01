#!/usr/bin/env python3
"""Bounded anonymous HTTP census of the Monorail's 54 catalogued exits.

Separate from the 17-door entry probe and the historical 177-link census.
Never request the two restricted Drive originals or the known-broken
historical Tower highlighter URL. Block unreviewed 30x destinations before
urllib follows them. Preserve one source-backed external app redirect.
Public HTTP outcomes are not compiler certificates. No response bodies are stored.
"""
from __future__ import annotations

import json
import os
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urldefrag, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

from probe_public_doors import read_corpus

OUTPUT = Path("monorail/live-exit-evidence.json")
HISTORICAL = {"links_followed": 177, "failures": 4,
              "status": "retained historical baseline; not re-crawled"}

# Immutable identities of the three historical exclusions. The catalogue's
# mutable "state" label is not sufficient authorization evidence: exchanging
# one restricted label for another could otherwise cause a private original
# to be anonymously requested while the 51/3 counts still appear correct.
EXPECTED_EXCLUDED = {
    "https://cdn.jsdelivr.net/npm/highlight.js@11.10.0/lib/highlight.min.js":
        "historical_404_not_requested",
    "https://docs.google.com/document/d/1wCmn5J4Tjo0qVV5AOoHUxD1tXComhPf7lU1ntzKtaMs/edit":
        "owner_only_original_not_requested",
    "https://drive.google.com/file/d/1-bCyEuWcN1rtRb1IJF02O8tTe7RbmaEC/view":
        "owner_only_original_not_requested",
}
EXPECTED_REPAIR_URLS = {
    "highlight": "https://cdn.jsdelivr.net/npm/highlight.js@11.10.0/lib/highlight.min.js",
    "mirror": "https://docs.google.com/document/d/1wCmn5J4Tjo0qVV5AOoHUxD1tXComhPf7lU1ntzKtaMs/edit",
    "modsync": "https://drive.google.com/file/d/1-bCyEuWcN1rtRb1IJF02O8tTe7RbmaEC/view",
}


# Reviewable navigation fixture. Unlike a count-only 51/3 census, this
# catches public exit URL swaps, query/fragment loss and relabeling without
# creating or merging any Mathematical City citizen identity.
EXPECTED_EXIT_IDENTITIES_PATH = Path(__file__).with_name("expected_exit_identities.json")

# Source-backed exception, not a wildcard host allowlist. Supabase's deployed
# city-app-host Edge Function v10 explicitly returns this 302 for slug=spectra
# (verified 2026-10-31). Preserve the original host link and its target as
# distinct identities. Any other cross-host/path redirect remains a failure.
REVIEWED_EXTERNAL_REDIRECTS = {
    "https://gpkjvihkyectnenvnbng.supabase.co/functions/v1/city-app-host/spectra/":
        "https://dune-orchid-berry-mountain.grok.me/?lab=operator#operator",
}


def verify_catalogued_exit_identities(data: dict) -> None:
    baseline = json.loads(EXPECTED_EXIT_IDENTITIES_PATH.read_text(encoding="utf-8"))
    expected = baseline["exits"]
    observed = [
        {"station": station["slug"], "label": link["label"],
         "url": link["href"], "state": link["state"],
         "repair": link.get("repair")}
        for station in data["stations"] for link in station["links"]
    ]

    def by_identity(rows: list[dict]) -> dict:
        indexed = {}
        for row in rows:
            key = (row["station"], row["label"])
            if key in indexed:
                raise ValueError("Duplicate catalogued exit identity: " + "/".join(key))
            indexed[key] = (row["url"], row["state"], row.get("repair"))
        return indexed

    expected_by_id = by_identity(expected)
    observed_by_id = by_identity(observed)
    if len(expected) != 54 or len(observed) != 54:
        raise ValueError("Catalogued exit fixture count changed; review explicitly")
    if observed_by_id != expected_by_id:
        changed = sorted(
            "/".join(key) for key in set(observed_by_id) | set(expected_by_id)
            if observed_by_id.get(key) != expected_by_id.get(key)
        )
        raise ValueError(
            "Catalogued exit identity changed; review explicitly: "
            + ", ".join(changed)
        )


def partition_exits(data: dict) -> tuple[list[dict], list[dict]]:
    public, excluded = [], []
    repairs = {r["id"]: r for r in data["repairs"]}
    for repair_id, original_url in EXPECTED_REPAIR_URLS.items():
        if repairs[repair_id]["failed"] != original_url:
            raise ValueError("Historical repair URL identity changed: " + repair_id)
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
    observed_excluded = {r["url"]: r["reason"] for r in excluded}
    if (len(observed_excluded) != len(excluded)
            or observed_excluded != EXPECTED_EXCLUDED):
        raise ValueError("Excluded original URL identities changed; review explicitly")
    verify_catalogued_exit_identities(data)
    return public, excluded


class RestrictedDriveRedirect(HTTPError):
    """Redirect to an unreviewed Google Drive/Docs destination, not fetched."""


class ExitIdentityRedirectBlocked(HTTPError):
    """Redirect to a different exit identity; destination not fetched."""


class SameExitRedirect(HTTPRedirectHandler):
    """Allow same-exit redirects, never an unrelated page, host or private Drive."""

    def __init__(self, original_url: str):
        super().__init__()
        self.original = urlsplit(original_url)

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        target = urlsplit(newurl)
        # Do not request restricted Drive originals even when a public exit
        # redirects into one. Check this before the general identity guard.
        safe_url = target._replace(query="", fragment="").geturl()
        if target.hostname in {"drive.google.com", "docs.google.com"}:
            raise RestrictedDriveRedirect(
                safe_url, code, "restricted_drive_redirect_blocked", headers, fp
            )
        if (req.full_url in REVIEWED_EXTERNAL_REDIRECTS
                and newurl == REVIEWED_EXTERNAL_REDIRECTS[req.full_url]):
            return super().redirect_request(req, fp, code, msg, headers, newurl)
        original_path = self.original.path.rstrip("/") or "/"
        target_path = target.path.rstrip("/") or "/"
        if (target.scheme != self.original.scheme
                or target.netloc.lower() != self.original.netloc.lower()
                or target_path != original_path
                # Pinned query parameters select the requested exit's view.
                # A same-path 302 must not turn ?view=atlas into ?view=learn
                # or ?module=eidolon into another instrument.
                # Unpinned exits retain canonical query redirects.
                or (self.original.query and target.query != self.original.query)
                # An explicitly changed SPA fragment changes the requested
                # instrument/view. Fragment-free Location inherits the source
                # fragment in browsers and remains valid canonicalization.
                or (self.original.fragment and target.fragment
                    and target.fragment != self.original.fragment)):
            raise ExitIdentityRedirectBlocked(
                safe_url, code, "exit_identity_redirect_blocked", headers, fp
            )
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def safe_urlopen(req: Request, timeout: float, source_url: str | None = None):
    # The HTTP request correctly omits browser-local #fragments, but the
    # redirect policy must retain the catalogued SPA view's full identity.
    # urllib follows 30x before probe_exit can inspect final_url.
    return build_opener(SameExitRedirect(source_url or req.full_url)).open(req, timeout=timeout)


def receipt_url(observed_url: str, source_url: str) -> str:
    """Keep only reviewed query parameters in durable HTTP evidence.

    A same-exit redirect may legitimately use a query for its HTTP request,
    but a new query is not part of the pinned source identity and may carry
    credentials. Do not persist it in public CI artifacts.
    """
    observed, source = urlsplit(observed_url), urlsplit(source_url)
    # A blocked 30x target can carry URL userinfo (user:password@host).
    # It is not part of any reviewed exit identity and must never enter the
    # public CI artifact, even when the redirect query has been removed.
    observed = observed._replace(netloc=observed.netloc.rsplit("@", 1)[-1])
    reviewed = REVIEWED_EXTERNAL_REDIRECTS.get(source_url)
    # Browser SPA fragments are never sent over HTTP. Compare the served URL
    # against the fragment-free source so a pinned query (e.g. Eidolon
    # ?module=eidolon#flight) survives in the evidence receipt.
    # A same-exit trailing-slash canonicalization may preserve the pinned
    # query while changing the URL's spelling. Keep that reviewed view in the
    # public receipt instead of silently dropping ?view=atlas or ?module=eidolon.
    # Never preserve a newly introduced or altered query.
    same_exit = (
        observed.scheme == source.scheme
        and observed.netloc.lower() == source.netloc.lower()
        and (observed.path.rstrip("/") or "/") == (source.path.rstrip("/") or "/")
    )
    if ((same_exit and observed.query == source.query)
            or (reviewed and observed_url == urldefrag(reviewed)[0])):
        return observed._replace(fragment="").geturl()
    return observed._replace(query="", fragment="").geturl()


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
        with safe_urlopen(req, timeout=timeout, source_url=row["url"]) as response:
            result["http_status"] = response.status
            observed_final_url = response.geturl()
            result["final_url"] = receipt_url(observed_final_url, row["url"])
            response.read(1)
            result["outcome"] = ("http_ok" if 200 <= response.status < 400
                                 else "http_error")
            reviewed = REVIEWED_EXTERNAL_REDIRECTS.get(row["url"])
            if (reviewed and observed_final_url
                    and urlsplit(observed_final_url)._replace(fragment="").geturl()
                    == urlsplit(reviewed)._replace(fragment="").geturl()):
                result["reviewed_redirect"] = reviewed
    except RestrictedDriveRedirect as error:
        result["http_status"] = error.code
        result["final_url"] = receipt_url(error.geturl(), row["url"])
        result["outcome"] = "restricted_redirect_blocked"
    except ExitIdentityRedirectBlocked as error:
        result["http_status"] = error.code
        result["final_url"] = receipt_url(error.geturl(), row["url"])
        result["outcome"] = "exit_identity_redirect_blocked"
    except HTTPError as error:
        result["http_status"] = error.code
        result["final_url"] = receipt_url(error.geturl(), row["url"])
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
        "http_error": sum(r["outcome"] in {
            "http_error", "restricted_redirect_blocked",
            "exit_identity_redirect_blocked"} for r in results),
        "exit_identity_redirect_blocked": sum(
            r["outcome"] == "exit_identity_redirect_blocked" for r in results
        ),
        "reviewed_external_redirects": sum(
            "reviewed_redirect" in r for r in results
        ),
        "restricted_redirect_blocked": sum(
            r["outcome"] == "restricted_redirect_blocked" for r in results
        ),
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
          + "; transport failures: " + str(result["network_error"])
          + "; Drive redirects blocked: "
          + str(result["restricted_redirect_blocked"])
          + "; wrong-exit redirects blocked: "
          + str(result["exit_identity_redirect_blocked"])
          + "; reviewed external redirects: "
          + str(result["reviewed_external_redirects"]))
    for row in result["results"]:
        print(str(row["http_status"] or "NETWORK") + " "
              + row["station"] + "/" + row["label"] + ": " + row["url"])
    print("Evidence:", OUTPUT)
    # This job is an observation, not a release gate. Preserve all failed
    # destinations in the artifact for one-defect-per-run remediation.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
