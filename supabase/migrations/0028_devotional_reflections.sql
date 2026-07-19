-- 0028: Private devotional reflections + archive.
--
-- A user can write ONE personal reflection per built-in devotional (editing
-- updates it), and browse an archive of past devotionals + reflections in
-- More → Devotionals.
--
-- PRIVACY (the product promise this schema must keep):
--   * Strict own-rows RLS: select/insert/update/delete only where
--     auth.uid() = user_id, granted to `authenticated` only; all anon
--     access revoked. No cross-user read path exists.
--   * Reflections are NEVER sent to Kyra or any AI. The app does not
--     include them in any edge-function payload.
--   * `shared_with_kyra` exists ONLY as a seam for a possible FUTURE,
--     explicit, per-user opt-in. It defaults to false, the app never sets
--     it, and nothing reads it today. Do not wire it into any AI path
--     without building the explicit opt-in UI first.

create table if not exists public.devotional_reflections (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  devotional_id uuid not null references public.devotionals(id) on delete cascade,
  body          text not null check (char_length(body) between 1 and 8000),
  reflected_on  date not null default current_date,
  shared_with_kyra boolean not null default false,   -- future opt-in seam; unused
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (user_id, devotional_id)
);

create index if not exists devotional_reflections_user_updated_idx
  on public.devotional_reflections (user_id, updated_at desc);

alter table public.devotional_reflections enable row level security;

drop policy if exists "own devotional_reflections select" on public.devotional_reflections;
create policy "own devotional_reflections select" on public.devotional_reflections
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "own devotional_reflections insert" on public.devotional_reflections;
create policy "own devotional_reflections insert" on public.devotional_reflections
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "own devotional_reflections update" on public.devotional_reflections;
create policy "own devotional_reflections update" on public.devotional_reflections
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own devotional_reflections delete" on public.devotional_reflections;
create policy "own devotional_reflections delete" on public.devotional_reflections
  for delete to authenticated using (auth.uid() = user_id);

revoke all on table public.devotional_reflections from anon;
grant select, insert, update, delete on table public.devotional_reflections to authenticated;

-- Keep updated_at honest on every edit.
create or replace function public.co_touch_devotional_reflection()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists devotional_reflections_touch on public.devotional_reflections;
create trigger devotional_reflections_touch
  before update on public.devotional_reflections
  for each row execute function public.co_touch_devotional_reflection();
