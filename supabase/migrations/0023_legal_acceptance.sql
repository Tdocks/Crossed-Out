-- 0023: Legal / Terms acceptance records.
--
-- App Review Guideline 1.2 (UGC): apps with user-generated content must get
-- explicit agreement to terms that state zero tolerance for objectionable
-- content and abusive users. This table is the durable, per-account record of
-- WHICH version of the Terms each user accepted and WHEN.
--
-- Design:
--   * Append-only audit trail: authenticated users may INSERT and SELECT
--     their own rows only. No UPDATE/DELETE grants — an acceptance can never
--     be edited or retracted from the client.
--   * (user_id, doc, version) primary key makes recording idempotent
--     (ON CONFLICT DO NOTHING via the client's ignoreDuplicates upsert
--     needs no UPDATE privilege).
--   * Rows cascade away when the auth user is deleted (account deletion).

create table if not exists public.legal_acceptances (
  user_id     uuid not null references auth.users(id) on delete cascade,
  doc         text not null default 'terms',
  version     text not null,
  accepted_at timestamptz not null default now(),
  primary key (user_id, doc, version)
);

alter table public.legal_acceptances enable row level security;

drop policy if exists "own legal_acceptances select" on public.legal_acceptances;
create policy "own legal_acceptances select" on public.legal_acceptances
  for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "own legal_acceptances insert" on public.legal_acceptances;
create policy "own legal_acceptances insert" on public.legal_acceptances
  for insert to authenticated
  with check (auth.uid() = user_id);

revoke all on table public.legal_acceptances from anon;
grant select, insert on table public.legal_acceptances to authenticated;
