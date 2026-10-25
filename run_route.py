#!/usr/bin/env python3
"""Elevated Reproducibility Monorail — route runner.

    python run_route.py <route_id>

Executes stations in dependency order, stops the certification at the first
failure (downstream stations are BLOCKED, not skipped silently), preserves
logs, emits hash-linked passports, and writes the complete route manifest
to the layout the Monorail charter specifies:

    evidence/routes/<route_id>/
    ├── route_manifest.json
    ├── dependency_graph.json
    ├── numerical_certificate.json
    ├── environment.lock
    ├── correction_status.json
    ├── receipts.jsonl
    ├── notion_citizen_block.md
    └── proof_browser.html

Transfer does not upgrade evidence.
"""
from __future__ import annotations

import argparse
import json
import platform
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "monorail"))
sys.path.insert(0, str(ROOT / "monorail" / "adapters"))

import github_adapter as gh          # noqa: E402
import notion_adapter as notion      # noqa: E402
import pages_adapter as pages        # noqa: E402
import supabase_adapter as supa      # noqa: E402
from passport import (GENESIS_PARENT, make_passport, sha256_file,  # noqa: E402
                      sha256_hex, utc_now, verify_chain)
import reconcile as rec      # noqa: E402
from routes import ROUTES            # noqa: E402
from switchyard import Switchyard    # noqa: E402

DEFECT_FOR = {"lean": "compiler_failure", "coq": "compiler_failure",
              "python": "matrix_identity_false"}


def classify(kind: str, result: dict) -> str:
    """Pick the defect class from the actual failure, not just the station kind.

    Exit 127 is not a refuted theorem: it means the source or the compiler was
    not there. Filing those as `compiler_failure` would attach a corrective
    obligation ("fix the proof term") to a proof that was never read.
    """
    log = (result.get("log") or "").lower()
    if result.get("exit_code") == 127:
        return "missing_source" if "file missing" in log else "compiler_unavailable"
    if result.get("exit_code") == 124:
        return "environment_mismatch"
    return DEFECT_FOR[kind]


def environment_lock(repo: Path) -> tuple[dict, str]:
    """Pin the execution environment. Its digest goes in every passport."""
    lock = {
        "python": platform.python_version(),
        "platform": platform.platform(),
        "lean": gh._version(["lean", "--version"]),
        "coqc": gh._version(["coqc", "--version"]),
        "git_commit": gh.head_commit(repo),
        "worktree_clean": gh.worktree_clean(repo),
    }
    blob = json.dumps(lock, sort_keys=True, separators=(",", ":"))
    return lock, sha256_hex(blob.encode())


def run(route_id: str, repo: Path, outdir: Path | None = None) -> int:
    if route_id not in ROUTES:
        print(f"unknown route {route_id!r}; known: {', '.join(ROUTES)}", file=sys.stderr)
        return 2
    route = ROUTES[route_id]
    out = outdir or (repo / "evidence" / "routes" / route_id)
    out.mkdir(parents=True, exist_ok=True)

    lock, lock_hash = environment_lock(repo)
    (out / "environment.lock").write_text(json.dumps(lock, indent=2, sort_keys=True) + "\n")

    yard = Switchyard(out / "correction_status.jsonl")
    commit = lock["git_commit"]
    run_url = gh.run_url()

    print(f"MONORAIL · route {route_id} · {route['service']}")
    print(f"  commit {commit[:12]}  env-lock {lock_hash[:12]}")
    for a in (gh, supa, notion, pages):
        s = a.status()
        print(f"  adapter {s['adapter']:<9} {s['mode']}")
    print()

    passports: list[dict] = []
    parent = GENESIS_PARENT
    certified = True       # Certified(R) = AND of Pass(S_k)
    blocked_from: str | None = None

    for st in route["stations"]:
        name, kind, rel = st["name"], st["kind"], st["file"]

        if blocked_from:
            status, result = "BLOCKED", {
                "file": rel, "exit_code": None, "compiler": None,
                "compiler_version": None,
                "log": f"BLOCKED by upstream failure at station {blocked_from}"}
        else:
            result = (gh.run_python(repo, rel) if kind == "python"
                      else gh.compile_proof(repo, rel))
            status = "PASS" if result["exit_code"] == 0 else "FAIL"

        src = repo / rel
        src_hash = sha256_file(src) if src.is_file() else "0" * 64
        assumptions = [l.strip() for l in (result.get("log") or "").splitlines()
                       if "depends on axioms" in l]

        p = make_passport(
            object_id=route["object_id"], theorem_id=st["theorem_id"],
            source_commit=commit, source_hash=src_hash,
            parent_receipt_hash=parent, proof_system=kind.capitalize(),
            compiler_version=result.get("compiler_version") or "",
            environment_lock_hash=lock_hash, assumptions=assumptions,
            verification_status=status, evidence_class=st["evidence_class"],
            artifact_hashes=[src_hash], route_id=route_id, station=name,
            scope=route["scope"], run_url=run_url,
        )
        passports.append(p)
        parent = p["receipt_hash"]

        (out / f"logs_{name}.txt").write_text(
            f"$ {kind} {rel}\nexit {result['exit_code']}\n\n{result.get('log') or ''}\n")

        mark = {"PASS": "ok", "FAIL": "FAIL", "BLOCKED": "--"}[status]
        print(f"  [{mark:>4}] {name:<24} {rel}")

        if status == "FAIL":
            certified = False
            blocked_from = name
            yard.file(defect=classify(kind, result), route_id=route_id, station=name,
                      receipt_hash=p["receipt_hash"],
                      detail=(result.get("log") or "").splitlines()[0][:300]
                      if result.get("log") else f"exit {result['exit_code']}")

    chain_ok, chain_notes = verify_chain(passports)

    # Reconcile against the City's citizen registry BEFORE declaring anything.
    # A route may certify its own stations; it may not promote a citizen.
    recon = rec.reconcile_route(passports)
    rec.write_report(passports, out / "citizen_reconciliation.json")

    # The ledger write is GATED: emit the exact statements for review, do not
    # execute them. This process holds no database credentials by design.
    bundle = supa.emit_bundle(passports, route_id, out / "supabase_write_bundle.sql")
    reconciliation = supa.reconcile(passports, [])  # ledger not yet deployed

    # A certified route whose citizens do not reconcile is LIMITED SERVICE:
    # the stations passed, but the result may not be promoted as it stands.
    if certified and chain_ok:
        state = "LIMITED SERVICE" if recon["promotion_blocked"] else "OPEN"
    elif yard.suspends(route_id):
        state = "SUSPENDED"
    else:
        state = "CONSTRUCTION"

    manifest = {
        "schema_version": "monorail.route_manifest.v1",
        "route_id": route_id, "title": route["title"], "service": route["service"],
        "origin": route["origin"], "destination": route["destination"],
        "object_id": route["object_id"], "scope": route["scope"],
        "source_commit": commit, "environment_lock_hash": lock_hash,
        "generated_utc": utc_now(), "status": state,
        "certified": certified and chain_ok,
        "chain_intact": chain_ok, "chain_notes": chain_notes,
        "stations": [{"station": p["station"], "theorem_id": p["theorem_id"],
                      "status": p["verification_status"],
                      "evidence_class": p["evidence_class"],
                      "receipt_hash": p["receipt_hash"]} for p in passports],
        "open_defects": len(yard.open_defects()),
        "citizen_reconciliation": recon,
        "ledger": {"mode": supa.MODE,
                   "write_bundle": str(bundle.relative_to(repo)),
                   "statements_emitted": 2 * len(passports),
                   "executed": False,
                   "reason": "city_formalism.monorail_receipts not deployed; "
                             "production DDL awaits explicit approval",
                   "reconciliation": reconciliation},
        "adapters": [a.status() for a in (gh, supa, notion, pages)],
        "transport_law": "(x,Q) |-> (T(x), M_T(Q)); transfer does not upgrade evidence",
    }
    (out / "route_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    dep = {"schema_version": "monorail.dependency_graph.v1", "route_id": route_id,
           "root": route["object_id"], "parents": route["parents"],
           "edges": [{"from": route["stations"][i - 1]["name"],
                      "to": s["name"], "relation": "precedes"}
                     for i, s in enumerate(route["stations"]) if i > 0],
           "proof_forge_issues": sorted({s["issue"] for s in route["stations"]})}
    (out / "dependency_graph.json").write_text(json.dumps(dep, indent=2) + "\n")

    num = {"schema_version": "monorail.numerical_certificate.v1",
           "route_id": route_id, "source_commit": commit,
           "exact_arithmetic_stations": [
               {"station": p["station"], "theorem_id": p["theorem_id"],
                "status": p["verification_status"], "evidence_class": p["evidence_class"]}
               for p in passports if p["evidence_class"] == "E1"],
           "note": "E1 fare. Exact rational arithmetic, not a formal proof."}
    (out / "numerical_certificate.json").write_text(json.dumps(num, indent=2) + "\n")

    with (out / "receipts.jsonl").open("w") as fh:
        for p in passports:
            fh.write(json.dumps(p, sort_keys=True, ensure_ascii=False) + "\n")

    (out / "correction_status.json").write_text(json.dumps({
        "schema_version": "monorail.correction_status.v1", "route_id": route_id,
        "suspended": yard.suspends(route_id),
        "open_defects": yard.open_defects(),
        "ledger": str((out / "correction_status.jsonl").relative_to(repo)),
    }, indent=2) + "\n")

    (out / "notion_citizen_block.md").write_text(
        notion.citizen_block(passports[-1], route["parents"]) + "\n")
    pages.render(manifest, passports, chain_ok, chain_notes, out / "proof_browser.html")

    print()
    print(f"  chain      {'INTACT' if chain_ok else 'BROKEN'}")
    print(f"  ledger     {2 * len(passports)} statements emitted, 0 executed ({supa.MODE})")
    print(f"  defects    {len(yard.open_defects())} open")
    print(f"  citizens   {recon['consistent']} consistent, "
          f"{recon['unregistered']} unregistered, "
          f"{recon['upgrades_requiring_approval']} upgrade(s) needing approval")
    print(f"  ROUTE      {state}")
    print(f"  written    {out.relative_to(repo)}/")
    return 0 if (certified and chain_ok) else 1


def main() -> int:
    ap = argparse.ArgumentParser(description="Run a Monorail reproducibility route.")
    ap.add_argument("route_id", nargs="?", help="e.g. KX-E47-KERNEL")
    ap.add_argument("--list", action="store_true", help="list known routes")
    ap.add_argument("--out", help="output directory (default evidence/routes/<id>)")
    a = ap.parse_args()
    if a.list or not a.route_id:
        for k, v in ROUTES.items():
            print(f"{k}  {v['title']}  ({len(v['stations'])} stations)")
        return 0
    return run(a.route_id, ROOT, Path(a.out) if a.out else None)


if __name__ == "__main__":
    raise SystemExit(main())
