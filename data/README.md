# Mathematical City: source formalism and E47 algebra database

Source: *Mathematical City — 341-Row Primary Source Formalism Atlas*, six-page source PDF.
Extracted 341 distinct logical IDs, preserving title, date, source, artifact type, formalism family,
evidence class, canonical URL, supplied SHA-256, parent/supersedes, role and page/row provenance.
Source PDF SHA-256: `c3a753057636e1212e2c7ce1d596e86b225c93623104f54c9ee550413b6d5a4e`.

## Data
- `mathematical_city_341_records.csv`: all 341 records; source-derived catalog, not independent certification of all claims.
- `city_formalism_schema.sql`: PostgreSQL table definitions; use in a private, unexposed schema.
- `e47_algebra.md`: exact projector/annihilator/Bézout derivation and status boundary.

## Hosted database
The owner's existing Supabase project includes private schema `city_formalism`:
- `atlas_records`: 341 records, including source page and source PDF fingerprint;
- `algebra_identities`: 9 mathematical statements with distinct verification statuses.

Both tables have row-level security enabled. The `anon` and `authenticated`
roles have **no** schema USAGE permission. The database is not a public browser API.

## Local SQL examples
```sql
select logical_id, title, evidence_class, canonical_url
from city_formalism.atlas_records
where formalism_family = 'E47 Canonical Spectral Kernel';
select theorem_id, statement, verification_status
from city_formalism.algebra_identities
order by theorem_id;
```
All hosted algebra records describe E47; do not infer that every atlas entry has been proven.
