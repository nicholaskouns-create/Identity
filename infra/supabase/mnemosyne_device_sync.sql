-- Reproducibility snapshot of public.mnemosyne_records after mnemosyne_device_sync,
-- mnemosyne_records_text_id, and mnemosyne_records_created_at_text.
-- Owner-scoped archive rows only. Do not grant this table to anon.
-- created_at is text so the SHA-256 canonical string round-trips unchanged.
create table if not exists public.mnemosyne_records (
  id text primary key check (char_length(id) between 1 and 80 and id !~ '[[:cntrl:][:space:]]'),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 300),
  kind text not null check (kind in ('proven','numerically_tested','hypothesis','refuted','unverified','historical')),
  content text not null check (char_length(content) <= 20000),
  created_at text not null check (char_length(created_at) between 10 and 80 and created_at !~ '[[:cntrl:]]'),
  sha256 text not null check (sha256 ~ '^[a-f0-9]{64}$'),
  updated_at timestamptz not null default now()
);
alter table public.mnemosyne_records enable row level security;
alter table public.mnemosyne_records replica identity full;
revoke all on public.mnemosyne_records from public, anon;
grant select, insert, update, delete on public.mnemosyne_records to authenticated;
-- Policies: select, insert, update, delete where owner_id = auth.uid(), role authenticated.
-- Publication: supabase_realtime includes public.mnemosyne_records.
