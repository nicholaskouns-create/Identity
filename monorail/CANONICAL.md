# Monorail canonical serialization — contract v1

The digest is `SHA-256` over the canonical serialization of the passport body
with the `receipt_hash` field removed. Three implementations must agree
byte-for-byte: `monorail/passport.py`, `city_formalism.monorail_canonical_json()`
in the migration, and `monorailCanonical()` in the browser verifier.

## This is NOT RFC 8785 (JCS)

Stated plainly so nobody claims interoperability we have not built:

| | JCS (RFC 8785) | Monorail v1 |
|---|---|---|
| Key ordering | UTF-16 code-unit order | **Unicode code-point order** |
| Number form | ECMAScript `Number::toString` | **not supported at all** |
| Target | general JSON interop | this ledger only |

The two orderings differ only for keys containing astral-plane characters
(U+10000 and above), where UTF-16 sorts surrogates below U+E000–U+FFFF.
Monorail keys are drawn from a fixed field set, so the difference cannot
arise in practice — but it is a real incompatibility and is recorded, not
glossed over.

## Supported value types

Supported, and covered by tests:

- **object** — keys sorted by Unicode code point, ascending. Nesting allowed.
- **array** — order preserved exactly; it is data, not a set.
- **string** — minimal JSON escaping; non-ASCII emitted as raw UTF-8, never `\uXXXX`.
- **null**
- **boolean**
- **integer** — within the range PostgreSQL `jsonb` round-trips exactly.

**Not supported. A passport containing one is rejected before hashing:**

- **floating point.** Python emits `1.0`, `1e2` becomes `100.0`; PostgreSQL
  `jsonb` normalizes differently. The forms diverge and the digests would too.
- **NaN / Infinity.** No canonical JSON form exists.
- **U+0000 in a string.** PostgreSQL `jsonb` cannot store it at all, so the
  SQL side could never reproduce the Python digest.
- **duplicate keys.** Eliminated by the object model before serialization;
  which survivor wins is not defined, so the input is rejected instead.

`passport.assert_canonicalizable()` enforces this and raises `PassportError`
naming the offending path. The guard exists because an unsupported value does
not produce a wrong answer loudly — it produces a receipt that verifies in one
language and fails in another, which is the worst possible failure for a
ledger whose whole purpose is cross-checking.

## Empty structures

`{}` serializes to `{}` and `[]` to `[]`. Both are tested; neither is elided.

## Procedure

1. Remove `receipt_hash`.
2. Serialize per the rules above.
3. Encode UTF-8.
4. `SHA-256`, lowercase hex.

Any change to these rules is a **new contract version**, not an edit. Existing
receipts stay valid under the version they were sealed with, and the field
`schema_version` on every passport records it.
