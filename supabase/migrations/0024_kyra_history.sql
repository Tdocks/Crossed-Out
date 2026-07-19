-- 0024: Persisted Kyra conversation history.
--
-- Kyra previously had session amnesia — every open seeded from mock data and
-- the conversation vanished on close. This table stores each user's rolling
-- conversation so Kyra picks up where they left off across sessions/devices.
--
-- Security:
--   * Own-rows RLS only (select / insert / delete to authenticated).
--   * No UPDATE grant — messages are immutable once written; the only
--     mutation is "start fresh," which deletes the user's own rows.
--   * This is sensitive pastoral data: no anon access of any kind.

create table if not exists public.kyra_messages (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  role       text not null check (role in ('user', 'kyra')),
  body       text not null check (char_length(body) between 1 and 6000),
  created_at timestamptz not null default now()
);

create index if not exists kyra_messages_user_created_idx
  on public.kyra_messages (user_id, created_at);

alter table public.kyra_messages enable row level security;

drop policy if exists "own kyra_messages select" on public.kyra_messages;
create policy "own kyra_messages select" on public.kyra_messages
  for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "own kyra_messages insert" on public.kyra_messages;
create policy "own kyra_messages insert" on public.kyra_messages
  for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "own kyra_messages delete" on public.kyra_messages;
create policy "own kyra_messages delete" on public.kyra_messages
  for delete to authenticated
  using (auth.uid() = user_id);

revoke all on table public.kyra_messages from anon;
grant select, insert, delete on table public.kyra_messages to authenticated;
