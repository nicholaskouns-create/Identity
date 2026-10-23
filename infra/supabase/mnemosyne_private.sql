-- Applied to existing Supabase project 2026-10-23.
-- This file is the reviewed reproducibility snapshot, not an instruction to rerun blindly.
create schema if not exists mnemosyne_private;
revoke all on schema mnemosyne_private from public, anon, authenticated;
create table if not exists mnemosyne_private.source_documents (
 id uuid primary key default gen_random_uuid(), title text not null, source_uri text,
 source_sha256 text check (source_sha256 is null or source_sha256 ~ '^[a-f0-9]{64}$'),
 storage_path text, evidence_class text not null default 'historical_source',
 recorded_at timestamptz not null default now(), metadata jsonb not null default '{}'::jsonb
);
create table if not exists mnemosyne_private.proof_records (
 id uuid primary key default gen_random_uuid(), claim text not null,
 status text not null check (status in ('proven','numerically_tested','hypothesis','refuted','unverified')),
 source_document_id uuid references mnemosyne_private.source_documents(id),
 code_commit text, certificate_sha256 text, recorded_at timestamptz not null default now()
);
create table if not exists mnemosyne_private.experiment_runs (
 id uuid primary key default gen_random_uuid(), experiment_type text not null,
 code_commit text, parameters jsonb not null default '{}'::jsonb,
 metrics jsonb not null default '{}'::jsonb, artifact_path text,
 created_at timestamptz not null default now()
);
create table if not exists mnemosyne_private.provenance_links (
 id uuid primary key default gen_random_uuid(), source_uri text not null,
 target_uri text not null, relation text not null,
 verified_at timestamptz, created_at timestamptz not null default now()
);
alter table mnemosyne_private.source_documents enable row level security;
alter table mnemosyne_private.proof_records enable row level security;
alter table mnemosyne_private.experiment_runs enable row level security;
alter table mnemosyne_private.provenance_links enable row level security;
revoke all on all tables in schema mnemosyne_private from public, anon, authenticated;
