-- Run on PostgreSQL/Supabase. Non-destructive private namespace.
CREATE SCHEMA IF NOT EXISTS city_formalism;
REVOKE ALL ON SCHEMA city_formalism FROM PUBLIC, anon, authenticated;
CREATE TABLE IF NOT EXISTS city_formalism.atlas_records (
 logical_id text PRIMARY KEY, title text NOT NULL, record_date text,
 source text, artifact_type text, formalism_family text,
 evidence_class text, canonical_url text, source_sha256 text,
 parent_supersedes text, role text, atlas_page integer, atlas_row integer,
 source_pdf_sha256 text NOT NULL
);
CREATE TABLE IF NOT EXISTS city_formalism.algebra_identities (
 theorem_id text PRIMARY KEY, statement text NOT NULL,
 derivation text NOT NULL, verification_method text NOT NULL,
 verification_status text NOT NULL
);
CREATE INDEX IF NOT EXISTS city_formalism_family_idx
 ON city_formalism.atlas_records(formalism_family);
CREATE INDEX IF NOT EXISTS city_formalism_evidence_idx
 ON city_formalism.atlas_records(evidence_class);
ALTER TABLE city_formalism.atlas_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE city_formalism.algebra_identities ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA city_formalism FROM PUBLIC, anon, authenticated;
