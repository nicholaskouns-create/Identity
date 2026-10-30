# Decision packet — apply `city_formalism.monorail_receipts`

One decision is requested. Nothing below has been executed.

## The action

Apply `infra/supabase/monorail_receipts.sql` to project `gpkjvihkyectnenvnbng`
as a named migration.

Creates, all new:

- `city_formalism.monorail_receipts` — the receipt ledger
- `city_formalism.monorail_checkpoints` — external anchor surface, empty
- `city_formalism.monorail_chain_status` — read-only verification view
- 3 functions, 2 triggers, 3 indexes, 1 extension (`pgcrypto`, if absent)

Alters or drops: **nothing**.

## Tested artifacts

| Test | Result | Where |
|---|---|---|
| Migration applies clean | pass | local PostgreSQL 16.15 |
| Python ↔ SQL ↔ JS canonical form | 26/26 | `test_canonical_crosslang.py` |
| Every route receipt, digests match | all | Python, SQL and JS |
| Migration integrity scenarios | 15/15 | `test_migration_pg.py` |
| Write bundle against a production-schema clone | receipts + transit rows, chain-verified | `prodclone` database |
| Monorail scenarios | 18/18 | `test_monorail.py` |
| Independent CI | success | run [40229699025](https://github.com/nicholaskouns-create/Identity/actions/runs/40229699025) |

## Expected effect

Three new objects in an existing private schema. No existing row changes. No
existing grant or policy changes. `cube_moves`, `machine_certificates`,
`corrections`, `transit_events` and `approval_queue` are untouched.

Storage: negligible — the current route's receipts are roughly 15 KB.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Tested on PG 16.15, production is **17.6** | **medium** | nothing version-specific is used (CHECK-with-function, partial unique indexes, plpgsql triggers, pgcrypto are stable across 16→17). Closable before deploy by running the same suite on a Supabase branch. |
| `pgcrypto` created if absent | low | `IF NOT EXISTS`; widely present on Supabase already |
| A CHECK calling a function blocks later edits to that function | low | intended. Changing canonicalization is a new contract version, not an edit |
| Append-only means no rollback by deletion | **by design** | forward recovery only; see OPERATIONS.md §8 |
| Name collision in `city_formalism` | low | verified absent: `to_regclass` returns NULL |

## Prerequisite checks

```sql
select to_regclass('city_formalism.monorail_receipts');     -- expect NULL
select current_setting('server_version');                   -- expect 17.x
select count(*) from city_formalism.identity_evidence_receipts;  -- expect 7
select count(*) from public.cube_moves;                     -- expect 1
```

## Post-deployment verification

```sql
-- objects exist
select to_regclass('city_formalism.monorail_receipts'),
       to_regclass('city_formalism.monorail_checkpoints');
-- append-only actually enforced (both must ERROR)
update city_formalism.monorail_receipts set station='x';
delete from city_formalism.monorail_receipts;
-- existing tables unchanged
select count(*) from public.cube_moves;                     -- still 1
select count(*) from city_formalism.identity_evidence_receipts;  -- still 7
```

Then, separately, the receipts:

```sql
\i evidence/routes/KX-E47-KERNEL/supabase_write_bundle.sql
select count(*) from city_formalism.monorail_chain_status
 where digest_ok and parent_ok;                             -- expect 9
```

## Recovery

While empty, `DROP TABLE city_formalism.monorail_receipts CASCADE` is clean —
but it is destructive and needs its own approval. Once receipts exist, there
is no rollback: append a correction and a superseding receipt instead.

## What this does NOT authorize

- writing receipts (a separate step, above)
- any change to RLS or grants on existing tables
- new service credentials
- Notion writes
- merging PR #77
- promoting any mathematical claim to canonical

## Recommendation

Close the version gap first. A Supabase **development branch** gives a real
PostgreSQL 17.6 to run the identical suite against; it is billable, which is
itself an approval decision. If you would rather not, applying directly is
low risk on the evidence above — but 16.15 is what was tested, and that is
the honest caveat.
