# Monorail operations guide

The Elevated Reproducibility Monorail, as implemented. This document describes
the **deployed state**, not an intention. Where something is not deployed, it
says so.

Charter: Notion `3a246094fd3081f0a356e5102d1561b9`.
Contract: `docs/proof-memory-bridge.md`. Serialization: `monorail/CANONICAL.md`.

## 1. Architecture

```
  theorem file ──► run_route.py ──► compiler (Lean 4.35.0 / Coq 8.18.0)
                        │                 │
                        │                 └─► real exit code + axiom audit
                        ▼
                  proof passport ──► canonical_bytes ──► SHA-256 ──► receipt
                        │                                              │
                        │                              parent_receipt_hash
                        ▼                                              ▼
        evidence/routes/<id>/  ◄─── chain ───►  city_formalism.monorail_receipts
                        │                              (NOT DEPLOYED)
      ┌─────────────────┼─────────────────┬──────────────────┐
      ▼                 ▼                 ▼                  ▼
  Correction      transit_events    approval_queue     site/proof/monorail
  Switchyard      (write-gated)     (human gate)       (browser verifier)
```

## 2. Trust boundaries

| Boundary | What crosses it | Who may write |
|---|---|---|
| Compiler → passport | exit code, version, axioms | route runner, from real output |
| Passport → receipt | canonical bytes | nobody; the digest is computed |
| Receipt → ledger | INSERT | credentialed operator, post-approval |
| Route → citizen registry | **nothing automatic** | human, via `approval_queue` |
| Ledger → browser | exported receipts | read-only; verified client-side |

The route runner holds **no database credentials by design**. It emits SQL; a
credentialed operator executes it. That is why "the adapter wrote to Supabase"
is never claimed.

## 3. The transport law

`(x, Q) ↦ (T(x), M_T(Q))`, enforced in `passport.transport()`, which raises
`PassportError` on any attempt to raise an E0–E4 fare. Independently,
`reconcile.py` compares every station's declared fare against the citizen
registry and blocks promotion when the route claims more than the City holds.

A route that certifies all stations but fails reconciliation is
**LIMITED SERVICE**, not OPEN. That is the current state of `KX-E47-KERNEL`.

## 4. Threat model — prevented, detected, out of scope

| # | Threat | Status | Mechanism |
|---|---|---|---|
| 1 | Modified certificate content | **Detected** | `CHECK receipt_hash = digest(passport)`; browser recompute |
| 2 | Forged receipt hash | **Prevented** | same CHECK rejects the INSERT |
| 3 | Missing parent receipt | **Prevented** | `monorail_check_parent` trigger |
| 4 | Forked chain | **Prevented** | unique index on `parent_receipt_hash` |
| 5 | Duplicate insert | **Prevented** | primary key on `receipt_hash` |
| 6 | Concurrent writers | **Prevented** | unique parent consumption; one writer wins |
| 7 | Failed transaction | **Prevented** | bundle wrapped in BEGIN/COMMIT |
| 8 | Invalid compiler output | **Detected** | real exit codes; `classify()` picks the defect |
| 9 | Evidence-class promotion | **Prevented** | `transport()` + `reconcile.py` |
| 10 | Broken workflow dependency | **Detected** | caused CI run #1 to fail; now a defect class |
| 11 | Incorrect shell quoting | **Detected** | harness raises on `syntax error` |
| 12 | Tests passing without asserting | **Detected** | same guard; this bug was real and is fixed |
| 13 | Unexpected trigger ordering | **Detected** | parent trigger fires before CHECKs; test asserts the *intended* constraint fires |
| 14 | Unauthorized Supabase access | **Prevented** | RLS forced, revoked from PUBLIC/anon/authenticated |
| 15 | Stale Notion references | **Detected** | reconciliation reports UNREGISTERED codes |
| 16 | Inaccessible repositories | **Detected** | discovery reports what it could not reach |
| 17 | Missing deployment secrets | **Detected** | `clock_auth_adapter` reports unsigned rather than faking |
| 18 | Pages cache staleness | **OUT OF SCOPE** | the browser verifier recomputes, so a stale page still cannot lie about a digest |
| 19 | Conflicting platform records | **Detected** | `reconcile()` reports ledger-only / local-only / conflicting |
| 20 | Privileged DB history modification | **OUT OF SCOPE** | `service_role`/`postgres` can disable triggers. `monorail_checkpoints` is the anchor surface and is **empty**. |

**No decentralization is claimed.** There are no independent validators, no
consensus, and no external anchor. Threat 20 is open and is the reason the
browser verifier works on an exported copy.

## 5. Correction Switchyard

Append-only. `switchyard.py` for the file ledger, `public.corrections` for the
City table. A correction REFERENCES the defect; the original row is never
rewritten. Defect classes are in `supabase_adapter.DEFECT_CLASSES`.

## 6. Canonical promotion

Only through `public.approval_queue` with `action_class = 'human_gate'`. The
adapter can create a **request**. It has no function that sets `decision_by`
or `decided_at`. No automated path sets them either.

## 7. Deployment

Not deployed. `city_formalism.monorail_receipts` does not exist in production.
See `monorail/DEPLOYMENT.md` for the decision packet.

## 8. Recovery

The ledger is append-only, so rollback by deletion is unsafe and unsupported.
Forward recovery only:

- **Bad receipt appended** → file a correction; append a superseding receipt.
- **Chain broken by an external write** → the browser verifier and
  `monorail_chain_status` both locate the first bad link by station.
- **Table created in error** → `DROP TABLE` is safe *only* while the table is
  empty, and is a destructive operation requiring its own approval.

## 9. Reproduction

```sh
python3 run_route.py KX-E47-KERNEL          # needs lean 4.35.0, coqc 8.18.0, numpy
python3 monorail/tests/test_monorail.py     # 15 scenarios
python3 monorail/tests/test_canonical_crosslang.py   # Python/SQL/JS agreement
python3 monorail/tests/test_migration_pg.py # 15 migration integrity tests
```

CI runs all four: `.github/workflows/monorail-route.yml`.

## 10. Known limitations

1. Receipts are **unsigned**. No key is provisioned.
2. No external anchor; threat 20 stands.
3. The ledger is **not deployed**; all writes are emitted, none executed.
4. Migration tested on PostgreSQL **16.15**; production runs **17.6**.
5. Canonical contract covers strings, integers, booleans, null, arrays and
   objects. Floats, NaN/Infinity and U+0000 are rejected, not supported.
6. Six of nine theorem identifiers match **no** City citizen. They are
   reported, never auto-created.
7. The carrier bridge (`E47Bridge`, E47-CORE-003) connects the **weight
   data** of the concrete 125-state operator to the block decomposition
   that yields 47, with three independent trace cross-checks. It does
   **not** connect the **eigenspaces**. `E47Centrality` (E47-CORE-004)
   adds lane #17's Z half: `[C, Z] = 0` on the genuine 125-term product,
   proved structurally after a brute-force `decide` was OOM-killed at 10
   minutes. Still open: `[C, U] = 0`, `[C, D] = 0`, and the identification
   of C's eigenspaces with the spin blocks (lane #19). So
   `dim ker (C−6I)(C−30I) = 47` for the full Casimir remains open.
