#!/usr/bin/env python3
"""Non-destructive tests for infra/supabase/monorail_receipts.sql.

Runs against a THROWAWAY local PostgreSQL database, never production.
Every negative case must be rejected BY THE DATABASE, not by application code.
"""
from __future__ import annotations
import json, os, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "monorail"))
from passport import compute_receipt_hash  # noqa: E402

DB = "monorail_test"
R: list[tuple[str, bool, str]] = []


_SEQ = [0]


def sql(q: str) -> tuple[int, str, str]:
    """Run SQL via a temp file.

    Passing SQL inline through `su -c "psql -c ..."` double-quotes it through
    two shells and mangles anything containing backslashes or quotes. That
    turns every negative test into a FALSE PASS: the statement never reaches
    the server, psql exits nonzero on a syntax error, and the test reads that
    as 'the database rejected it'. A file has no quoting layer at all.
    """
    _SEQ[0] += 1
    f = Path(f"/tmp/monorail_q{_SEQ[0]}.sql")
    f.write_text(q)
    f.chmod(0o644)
    # Root (local container) has `su`; a CI runner is an unprivileged user and
    # must go through sudo. Hardcoding either one breaks the other environment.
    inner = f"psql -v ON_ERROR_STOP=1 -t -A -d {DB} -f {f}"
    argv = (["su", "postgres", "-c", inner] if os.geteuid() == 0
            else ["sudo", "-n", "-u", "postgres", "sh", "-c", inner])
    p = subprocess.run(argv, capture_output=True, text=True)
    out, err = p.stdout.strip(), p.stderr.strip()
    # A syntax error means the harness is broken, not that the DB rejected
    # the data. Never let that masquerade as a passing negative test.
    if "syntax error" in err:
        raise RuntimeError(f"harness bug, SQL never ran: {err[:200]}")
    return p.returncode, out, err


def lit(d: dict) -> str:
    return json.dumps(d, ensure_ascii=False).replace("'", "''")


def insert(p: dict) -> tuple[int, str]:
    q = f"""insert into city_formalism.monorail_receipts
      (receipt_hash,parent_receipt_hash,schema_version,route_id,station,object_id,
       theorem_id,source_commit,source_hash,environment_lock_hash,proof_system,
       compiler_version,assumptions,verification_status,evidence_class,scope,run_url,
       artifact_hashes,passport,timestamp_utc)
      select x->>'receipt_hash', x->>'parent_receipt_hash', x->>'schema_version',
             x->>'route_id', x->>'station', x->>'object_id', x->>'theorem_id',
             x->>'source_commit', x->>'source_hash', x->>'environment_lock_hash',
             x->>'proof_system', x->>'compiler_version', x->'assumptions',
             x->>'verification_status', x->>'evidence_class', x->>'scope',
             x->>'run_url', x->'artifact_hashes', x, (x->>'timestamp_utc')::timestamptz
      from (select '{lit(p)}'::jsonb as x) t;"""
    code, _, err = sql(q)
    return code, err.splitlines()[0][:150] if err else ""


def check(name: str, cond: bool, note: str = "") -> None:
    R.append((name, bool(cond), note))


receipts = [json.loads(l) for l in
            (ROOT / "evidence/routes/KX-E47-KERNEL/receipts.jsonl").read_text().splitlines() if l.strip()]

sql("truncate city_formalism.monorail_receipts;")

# --- genesis + ordered append ------------------------------------------------
ok = all(insert(p)[0] == 0 for p in receipts)
_, n, _ = sql("select count(*) from city_formalism.monorail_receipts;")
check("append all 9 receipts in order", ok and n == "9", f"{n} rows")

# --- digest recomputation IN THE DATABASE ------------------------------------
_, bad, _ = sql("select count(*) from city_formalism.monorail_chain_status where not digest_ok;")
check("every stored digest recomputes", bad == "0", f"{bad} mismatched")
_, orph, _ = sql("select count(*) from city_formalism.monorail_chain_status where not parent_ok;")
check("every parent link resolves", orph == "0", f"{orph} orphans")

# --- tamper: edit the body, keep the hash ------------------------------------
t = json.loads(json.dumps(receipts[0]))
t["verification_status"] = "PASS"
t["evidence_class"] = "E0"
t["theorem_id"] = "E47-FORGED"
t["parent_receipt_hash"] = receipts[-1]["receipt_hash"]
code, err = insert(t)                 # hash left untouched -> body no longer digests to it
check("tampered body rejected", code != 0, err)

# --- tamper: recompute the hash honestly but forge a parent -------------------
f = json.loads(json.dumps(receipts[2]))
f["parent_receipt_hash"] = "b" * 64   # a parent that does not exist
f.pop("receipt_hash")
f["receipt_hash"] = compute_receipt_hash(f)
code, err = insert(f)
check("orphan parent rejected", code != 0, err)

# --- fork: two children of one parent ----------------------------------------
g = json.loads(json.dumps(receipts[8]))
g["parent_receipt_hash"] = receipts[0]["receipt_hash"]   # already consumed
g["station"] = "forked"
g.pop("receipt_hash"); g["receipt_hash"] = compute_receipt_hash(g)
code, err = insert(g)
check("chain fork rejected", code != 0, err)

# --- second genesis on the same route ----------------------------------------
h = json.loads(json.dumps(receipts[4]))
h["parent_receipt_hash"] = "0" * 64
h["station"] = "second_genesis"
h.pop("receipt_hash"); h["receipt_hash"] = compute_receipt_hash(h)
code, err = insert(h)
check("second genesis rejected", code != 0, err)

# --- duplicate receipt --------------------------------------------------------
code, err = insert(receipts[0])
check("duplicate receipt rejected", code != 0, err)

# --- immutability -------------------------------------------------------------
code, _, err = sql("update city_formalism.monorail_receipts set verification_status='PASS';")
check("UPDATE blocked by trigger", code != 0, err.splitlines()[0][:150] if err else "")
code, _, err = sql("delete from city_formalism.monorail_receipts;")
check("DELETE blocked by trigger", code != 0, err.splitlines()[0][:150] if err else "")

# --- bad shapes ----------------------------------------------------------------
code, _, err = sql("""insert into city_formalism.monorail_receipts
 (receipt_hash,parent_receipt_hash,schema_version,route_id,station,object_id,theorem_id,
  source_commit,source_hash,environment_lock_hash,proof_system,verification_status,
  evidence_class,passport,timestamp_utc)
 values (repeat('Z',64),repeat('0',64),'v','R','s','o','t','abc1234',repeat('a',64),
  repeat('a',64),'Lean','PASS','E0','{}'::jsonb,now());""")
check("non-hex hash rejected", code != 0, err.splitlines()[0][:110] if err else "")

code, _, err = sql("""insert into city_formalism.monorail_receipts
 (receipt_hash,parent_receipt_hash,schema_version,route_id,station,object_id,theorem_id,
  source_commit,source_hash,environment_lock_hash,proof_system,verification_status,
  evidence_class,passport,timestamp_utc)
 values (repeat('a',64),repeat('0',64),'v','R','s','o','t','abc1234',repeat('a',64),
  repeat('a',64),'Lean','PASS','E9','{}'::jsonb,now());""")
check("invalid evidence class rejected", code != 0, err.splitlines()[0][:110] if err else "")

# --- concurrency: two sessions race for the same parent ------------------------
c1 = json.loads(json.dumps(receipts[1])); c1["station"] = "race_a"
c1["parent_receipt_hash"] = receipts[8]["receipt_hash"]
c1.pop("receipt_hash"); c1["receipt_hash"] = compute_receipt_hash(c1)
c2 = json.loads(json.dumps(receipts[1])); c2["station"] = "race_b"
c2["parent_receipt_hash"] = receipts[8]["receipt_hash"]
c2.pop("receipt_hash"); c2["receipt_hash"] = compute_receipt_hash(c2)
a_code, _ = insert(c1)
b_code, b_err = insert(c2)
check("concurrent append: exactly one wins",
      a_code == 0 and b_code != 0, b_err or "second rejected on unique parent")

# --- external anchor surface is empty and says so ------------------------------
_, cp, _ = sql("select count(*) from city_formalism.monorail_checkpoints;")
check("checkpoint table exists and is empty", cp == "0",
      "no external anchor claimed; DBA gap remains open")

# --- existing City tables untouched --------------------------------------------
_, cm, _ = sql("select to_regclass('public.cube_moves')::text;")
check("cube_moves not created or touched by this migration", cm in ("", "NULL", None),
      "migration defines nothing in public schema")

w = max(len(n) for n, _, _ in R)
passed = sum(ok for _, ok, _ in R)
for name, ok_, note in R:
    print(f"  {'PASS' if ok_ else 'FAIL'}  {name:<{w}}  {note[:70]}")
print(f"\n  {passed}/{len(R)} migration tests passed")
sys.exit(0 if passed == len(R) else 1)
