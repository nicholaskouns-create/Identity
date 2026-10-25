-- city_formalism.monorail_receipts — the Monorail proof-receipt ledger.
-- Reviewed migration, 2026-10-25. ADDITIVE ONLY.
--
-- Touches no existing table, column, row, policy, grant or trigger.
-- cube_moves, machine_certificates and identity_evidence_receipts are NOT
-- modified and NOT copied. Certificates are referenced, never duplicated:
-- see machine_certificate_code below, which is a soft reference by code, not
-- a foreign key, precisely because machine_certificates rows are mutable
-- (updated_at + row_version, no immutability trigger) and an immutable
-- receipt must not assert that a mutable row will still say what it says.
--
-- WHY A NEW TABLE (schema audit, 2026-10-25):
--   public.cube_moves      append-only IS enforced by trigger, but prev_hash
--                          has no FK and no unique index, the hash columns are
--                          length-64-only with no hex check, and the row shape
--                          (kind CHECK, instance_id FK NOT NULL, permutation,
--                          displaced, geometry_energy) cannot hold a proof
--                          receipt without relaxing its constraints or
--                          fabricating geometry. Left untouched.
--   machine_certificates   no content-hash column and mutable rows; cannot
--                          anchor a chain. Left untouched, referenced by code.
--
-- LIMIT OF THE GUARANTEE, stated in the schema rather than assumed:
--   A hash chain inside a database is NOT independently immutable against a
--   privileged administrator. service_role and postgres can disable triggers
--   and rewrite history. This ledger makes tampering DETECTABLE to anyone
--   holding an external copy; it does not make it impossible. External
--   checkpoints or signed anchors are required for that, and are deliberately
--   NOT claimed here. See monorail_checkpoints below for the anchor surface.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- Canonical serialization. MUST agree byte-for-byte with
-- monorail/passport.py :: canonical_bytes().
--
-- jsonb::text is NOT usable here: jsonb orders object keys by (length, bytes),
-- while the Python verifier sorts them lexicographically. The digests would
-- diverge on real data. This function therefore emits the canonical form
-- explicitly: keys sorted lexicographically at every depth, no insignificant
-- whitespace, the receipt_hash field excluded, UTF-8 unescaped.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION city_formalism.monorail_canonical_json(doc jsonb)
RETURNS text
LANGUAGE plpgsql IMMUTABLE STRICT AS $fn$
DECLARE
  k text; parts text[] := '{}'; elem jsonb;
BEGIN
  CASE jsonb_typeof(doc)
    WHEN 'object' THEN
      FOR k IN SELECT key FROM jsonb_object_keys(doc) AS t(key) ORDER BY key COLLATE "C"
      LOOP
        parts := parts || (to_json(k)::text || ':' ||
                           city_formalism.monorail_canonical_json(doc -> k));
      END LOOP;
      RETURN '{' || array_to_string(parts, ',') || '}';
    WHEN 'array' THEN
      FOR elem IN SELECT value FROM jsonb_array_elements(doc)
      LOOP
        parts := parts || city_formalism.monorail_canonical_json(elem);
      END LOOP;
      RETURN '[' || array_to_string(parts, ',') || ']';
    WHEN 'string' THEN RETURN to_json(doc #>> '{}')::text;
    WHEN 'number' THEN RETURN doc::text;
    WHEN 'boolean' THEN RETURN doc::text;
    ELSE RETURN 'null';
  END CASE;
END;
$fn$;

CREATE OR REPLACE FUNCTION city_formalism.monorail_receipt_digest(passport jsonb)
RETURNS text LANGUAGE sql IMMUTABLE STRICT AS $fn$
  SELECT encode(digest(
    convert_to(city_formalism.monorail_canonical_json(passport - 'receipt_hash'),
               'UTF8'), 'sha256'), 'hex');
$fn$;

-- ---------------------------------------------------------------------------
-- The ledger.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS city_formalism.monorail_receipts (
  receipt_hash          text PRIMARY KEY CHECK (receipt_hash ~ '^[a-f0-9]{64}$'),
  parent_receipt_hash   text NOT NULL    CHECK (parent_receipt_hash ~ '^[a-f0-9]{64}$'),
  schema_version        text NOT NULL,
  route_id              text NOT NULL,
  station               text NOT NULL,
  object_id             text NOT NULL,
  theorem_id            text NOT NULL,
  source_commit         text NOT NULL CHECK (source_commit ~ '^[a-f0-9]{7,40}$'),
  source_hash           text NOT NULL CHECK (source_hash ~ '^[a-f0-9]{64}$'),
  environment_lock_hash text NOT NULL CHECK (environment_lock_hash ~ '^[a-f0-9]{64}$'),
  proof_system          text NOT NULL,
  compiler_version      text,
  assumptions           jsonb NOT NULL DEFAULT '[]'::jsonb,
  verification_status   text NOT NULL
      CHECK (verification_status IN ('PASS','FAIL','PENDING','BLOCKED')),
  evidence_class        text NOT NULL CHECK (evidence_class IN ('E0','E1','E2','E3','E4')),
  scope                 text,
  run_url               text,
  artifact_hashes       jsonb NOT NULL DEFAULT '[]'::jsonb,
  -- The exact body the digest covers. Immutable; the row is the certificate.
  passport              jsonb NOT NULL,
  -- Soft reference to existing evidence. NOT a foreign key: those rows are
  -- mutable, and a hard link would let a later edit silently change what this
  -- immutable receipt appears to assert.
  machine_certificate_code text,
  transit_operation_code   text,
  timestamp_utc         timestamptz NOT NULL,
  recorded_at           timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT monorail_no_self_parent   CHECK (parent_receipt_hash <> receipt_hash),
  CONSTRAINT monorail_assumptions_array CHECK (jsonb_typeof(assumptions) = 'array'),
  CONSTRAINT monorail_artifacts_array   CHECK (jsonb_typeof(artifact_hashes) = 'array'),
  CONSTRAINT monorail_passport_object   CHECK (jsonb_typeof(passport) = 'object'),
  -- The digest must match the body. This is the constraint cube_moves lacks:
  -- it makes the stored hash a FACT ABOUT THE ROW, not an assertion about it.
  CONSTRAINT monorail_digest_matches_body
    CHECK (receipt_hash = city_formalism.monorail_receipt_digest(passport)),
  -- The body must agree with the indexed columns it is indexed by.
  CONSTRAINT monorail_body_agrees CHECK (
        passport ->> 'receipt_hash'        = receipt_hash
    AND passport ->> 'parent_receipt_hash' = parent_receipt_hash
    AND passport ->> 'theorem_id'          = theorem_id
    AND passport ->> 'verification_status' = verification_status
    AND passport ->> 'evidence_class'      = evidence_class
  )
);

COMMENT ON TABLE city_formalism.monorail_receipts IS
  'Append-only SHA-256 chained proof passports from the Elevated Reproducibility Monorail. receipt_hash is CHECK-verified against the canonical serialization of passport, so a stored digest is a fact about the row rather than a claim. Integrity only: a hash proves neither authorship nor mathematical correctness, and a database chain is not immutable against a privileged administrator. Transfer does not upgrade evidence.';

-- Genesis convention, explicit: exactly one row per route may carry the
-- all-zero parent, and it is that route's first station.
CREATE UNIQUE INDEX IF NOT EXISTS monorail_receipts_one_genesis_per_route
  ON city_formalism.monorail_receipts (route_id)
  WHERE parent_receipt_hash = repeat('0', 64);

-- Single linear chain: a parent may be consumed once. Forks are rejected by
-- the database, not detected afterwards.
CREATE UNIQUE INDEX IF NOT EXISTS monorail_receipts_parent_consumed_once
  ON city_formalism.monorail_receipts (parent_receipt_hash)
  WHERE parent_receipt_hash <> repeat('0', 64);

CREATE INDEX IF NOT EXISTS monorail_receipts_route_idx
  ON city_formalism.monorail_receipts (route_id, timestamp_utc);

-- Parent-link validation. A non-genesis receipt must name a parent that
-- already exists. Enforced at append time, in-transaction.
CREATE OR REPLACE FUNCTION city_formalism.monorail_check_parent()
RETURNS trigger LANGUAGE plpgsql AS $fn$
BEGIN
  IF NEW.parent_receipt_hash <> repeat('0', 64)
     AND NOT EXISTS (SELECT 1 FROM city_formalism.monorail_receipts
                     WHERE receipt_hash = NEW.parent_receipt_hash) THEN
    RAISE EXCEPTION
      'orphan receipt: parent % is not in the ledger', NEW.parent_receipt_hash
      USING ERRCODE = 'foreign_key_violation';
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS monorail_receipts_parent_link ON city_formalism.monorail_receipts;
CREATE TRIGGER monorail_receipts_parent_link
  BEFORE INSERT ON city_formalism.monorail_receipts
  FOR EACH ROW EXECUTE FUNCTION city_formalism.monorail_check_parent();

-- Append-only, enforced in the database rather than by convention.
CREATE OR REPLACE FUNCTION city_formalism.monorail_receipts_immutable()
RETURNS trigger LANGUAGE plpgsql AS $fn$
BEGIN
  RAISE EXCEPTION
    'city_formalism.monorail_receipts is append-only; % is not permitted. File a correction instead.',
    TG_OP USING ERRCODE = 'restrict_violation';
END;
$fn$;

DROP TRIGGER IF EXISTS monorail_receipts_no_change ON city_formalism.monorail_receipts;
CREATE TRIGGER monorail_receipts_no_change
  BEFORE UPDATE OR DELETE ON city_formalism.monorail_receipts
  FOR EACH ROW EXECUTE FUNCTION city_formalism.monorail_receipts_immutable();

-- ---------------------------------------------------------------------------
-- External anchor surface. Empty by design. This is where a signed or
-- off-site checkpoint goes to close the privileged-administrator gap. No
-- anchor is claimed by this migration.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS city_formalism.monorail_checkpoints (
  checkpoint_id   text PRIMARY KEY,
  route_id        text NOT NULL,
  head_receipt    text NOT NULL CHECK (head_receipt ~ '^[a-f0-9]{64}$'),
  receipt_count   integer NOT NULL CHECK (receipt_count > 0),
  anchor_kind     text NOT NULL CHECK (anchor_kind IN ('git_commit','ci_run','signature','external')),
  anchor_ref      text NOT NULL,
  anchored_at     timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE city_formalism.monorail_checkpoints IS
  'External anchors for the receipt chain. Empty until a real off-site checkpoint exists. A database-internal chain is not immutable against a privileged administrator; this table is where that gap is closed, and its emptiness is an honest statement that it is not yet closed.';

-- Read-only verification view. Recomputes every digest from the stored body.
CREATE OR REPLACE VIEW city_formalism.monorail_chain_status AS
SELECT r.route_id,
       r.station,
       r.theorem_id,
       r.verification_status,
       r.evidence_class,
       r.receipt_hash,
       r.parent_receipt_hash,
       (r.receipt_hash = city_formalism.monorail_receipt_digest(r.passport)) AS digest_ok,
       (r.parent_receipt_hash = repeat('0', 64)
        OR EXISTS (SELECT 1 FROM city_formalism.monorail_receipts p
                   WHERE p.receipt_hash = r.parent_receipt_hash))           AS parent_ok,
       r.timestamp_utc
FROM city_formalism.monorail_receipts r;

ALTER TABLE city_formalism.monorail_receipts   ENABLE ROW LEVEL SECURITY;
ALTER TABLE city_formalism.monorail_receipts   FORCE  ROW LEVEL SECURITY;
ALTER TABLE city_formalism.monorail_checkpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE city_formalism.monorail_checkpoints FORCE  ROW LEVEL SECURITY;

REVOKE ALL ON city_formalism.monorail_receipts    FROM PUBLIC;
REVOKE ALL ON city_formalism.monorail_checkpoints FROM PUBLIC;
REVOKE ALL ON city_formalism.monorail_chain_status FROM PUBLIC;

COMMIT;
