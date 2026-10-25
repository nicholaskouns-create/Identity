# Monorail verification transport — architecture and dependency map

Implements the **Elevated Reproducibility Monorail** charter already held in
Notion (`3a246094fd3081f0a356e5102d1561b9`) and the implementation contract in
`docs/proof-memory-bridge.md`. Nothing here replaces an existing component.

**Operating principle, enforced in code:** transfer does not upgrade evidence.
`passport.transport()` raises `PassportError` on any attempt to raise a fare.

## What already existed, and what this adds

| Charter component | Status before | This branch |
|---|---|---|
| Monorail charter, ten-stop ring, transport law | Notion prose | implemented |
| `evidence/routes/<id>/` layout | specified in charter | emitted |
| `python run_route.py <route_id>` | specified in charter | implemented |
| Correction Switchyard (⚫ Revision Switchyard) | named only | implemented |
| Proof DNA / lineage | `docs/proof-memory-bridge.md` v0.1 | dependency graph emitted |
| `mnemosyne_private` evidence schema | live in Supabase | unchanged; mirrored by a mock |
| `machine_certificates`, `mathematical_identities` | canonical rows | not touched |
| E47 Proof Forge lanes #15–#24 | ten open issues | stations tagged by lane |
| E0–E4 fare classes | City legend | used verbatim |

Terminology is preserved. The directive's four-value `evidence_class`
(`formal`/`exact-computation`/`numerical`/`experimental`) is **mapped** onto
the City's E0–E4 fare in `passport.DIRECTIVE_EVIDENCE_MAP`, not substituted
for it.

## Components

```
run_route.py                    route runner — the charter's command
monorail/
├── passport.py                 canonical serialization, SHA-256, hash chain,
│                               transport law, fare arithmetic
├── switchyard.py               append-only defect/correction ledger
├── routes.py                   station lists; Certified(R) = AND Pass(S_k)
├── adapters/
│   ├── github_adapter.py       LIVE   compilers, commit pinning, CI run URL
│   ├── supabase_adapter.py     MOCK   append-only replica + reconciliation
│   ├── notion_adapter.py       READ-VERIFIED / WRITE-DEFERRED
│   └── pages_adapter.py        LIVE generator / PUBLISH-DEFERRED
└── tests/test_monorail.py      the nine scenarios + the transport law
```

## Canonical serialization, fixed before hashing

`passport.canonical_bytes` drops the `receipt_hash` field, sorts keys at every
depth, emits no insignificant whitespace, encodes UTF-8 without ASCII escaping,
and rejects `NaN`/`Infinity`. `receipt_hash = SHA-256(canonical_bytes)`.

`parent_receipt_hash` links each receipt to the previous one; the first is the
genesis value (64 zeros). `verify_chain` recomputes every digest and every link.

**A hash proves integrity only.** Not authorship, not mathematical correctness.
Authenticated authorship needs signatures, which are not implemented here.

## What this is NOT

Not a blockchain. There are no independent validators, no consensus rules, and
no resistance to unilateral history modification — a writer with filesystem
access can rewrite the whole ledger. It is a **permissioned, hash-linked
ledger**: it makes tampering *detectable*, not *impossible*. A consensus
interface is deliberately out of scope and is not stubbed in.

## Emitted bundle

```
evidence/routes/<route_id>/
├── route_manifest.json          route state, stations, chain notes, adapters
├── dependency_graph.json        station order + Proof Forge issue lanes
├── numerical_certificate.json   E1 stations only, labelled as exact arithmetic
├── environment.lock             python/lean/coqc/platform/commit + clean flag
├── correction_status.json       open defects; suspension state
├── correction_status.jsonl      append-only ledger, hash-linked
├── receipts.jsonl               the passport chain
├── logs_<station>.txt           real compiler output, per station
├── supabase_replica.jsonl       MOCK replica
├── notion_citizen_block.md      reviewable civic record — paste, not auto-write
└── proof_browser.html           static Pages view of the route
```

## Governance

- No commits to `main`; this is a feature branch.
- Canonical promotion is **not** automated. The Notion adapter emits a block
  for a human to apply.
- No credentials anywhere in this tree. The mock replica holds no secrets and
  reaches no network.
- The runner is read-only against the repository: it compiles and writes under
  `evidence/routes/`, nothing else.
