# Monorail v1 independent receipt verifier

This is an **additive, read-only offline implementation** of `CANONICAL.md`. It does not import `passport.py`, the browser verifier, or the proposed SQL serializer. It accepts a local UTF-8 JSON **array** of ordered `monorail.passport.v1` receipts and recomputes SHA-256 hashes, enforces genesis/parent links, and rejects duplicate hashes and unsupported canonical types.

```sh
python -m monorail.independent_receipt_audit /path/to/local-receipts.json
python -m unittest discover -s monorail -p 'test_independent_receipt_audit.py' -v
```

Exit status 0 means an ordered chain passed these checks. Exit status 1 means a mismatch or invalid input. The report contains only the count, chain head hash, and assurance scope. It does not print receipt bodies. The tool never connects to Supabase or GitHub and has no write path. Input limit: 8 MiB.

**Evidence boundary:** A SHA-256 chain detects alteration relative to its supplied hashes but does not authenticate the signer, establish that a compiler ran, prove an E0/E1 claim, or defend against an actor who can rewrite an entire chain. It does not inspect privileged triggers or solve Threat 20. The SQL receipt ledger and canonical function are absent in the live project as of 2026-11-01 readback. The tool must not be called a deployed independent validator until wired to a separately authorized, read-only production source and exercised against actual receipts.

The CI suite uses synthetic receipts, invalid-input cases, and one cross-check against the existing `monorail.passport` producer. This preserves independent verifier implementation while testing compatibility with the producer.
