-- 0042_security_hardening.sql
-- Backend security hardening from the pre-launch audit:
--   1. profiles self-escalation (BLOCKER) — client DELETE on profiles is
--      superfluous and dangerous now that delete_own_account() (0006) is the
--      supported deletion path; revoke it, mirroring the 0021 churches
--      lockdown pattern (client writes go through SECURITY DEFINER RPCs).
--   2. Inflatable social counters (MAJOR) — pray_for / encourage_post (0004)
--      are SECURITY DEFINER with no dedup, so a client can call them in a
--      loop and inflate prayed_count / heart_count arbitrarily. Add backing
--      tables with a per-user unique constraint, insert-once (ON CONFLICT DO
--      NOTHING), and set the counter to the real count(*) so it can never be
--      inflated and repeat taps are idempotent.
--   3. create_circle active-account gate (MINOR) — create_micro (0030)
--      gates on current_account_status() = 'active'; create_circle (0040)
--      does not. Add the same gate.
--   4. user_badges client insert (MINOR) — 0035 grants insert to
--      authenticated, letting a client self-award arbitrary badges. Revoke
--      it; award_earned_badges() is SECURITY DEFINER and unaffected.
--   5. user_notes duplicate/crash prevention — dedupe existing rows (keep
--      latest per user/verse) and add a unique index so the app can upsert
--      on conflict for the note-edit fix.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. profiles: no client DELETE. Account deletion goes through
--    delete_own_account() (0006_safety_and_account.sql), a SECURITY DEFINER
--    RPC that deletes the auth.users row directly (not through RLS/grants);
--    profiles cascades via its `references auth.users(id) on delete cascade`
--    FK, so this revoke does not affect account deletion.
-- ----------------------------------------------------------------------------
revoke delete on public.profiles from authenticated;

-- ----------------------------------------------------------------------------
-- 2. Idempotent prayer / encouragement reactions.
-- ----------------------------------------------------------------------------
create table if not exists public.prayer_reactions (
  user_id    uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null references public.prayer_requests(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, request_id)
);

create table if not exists public.post_encouragements (
  user_id    uuid not null references auth.users(id) on delete cascade,
  post_id    uuid not null references public.community_posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

alter table public.prayer_reactions enable row level security;
alter table public.post_encouragements enable row level security;

drop policy if exists "own prayer reactions" on public.prayer_reactions;
create policy "own prayer reactions" on public.prayer_reactions
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "insert own prayer reactions" on public.prayer_reactions;
create policy "insert own prayer reactions" on public.prayer_reactions
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "own post encouragements" on public.post_encouragements;
create policy "own post encouragements" on public.post_encouragements
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "insert own post encouragements" on public.post_encouragements;
create policy "insert own post encouragements" on public.post_encouragements
  for insert to authenticated with check (auth.uid() = user_id);

-- No anon access; authenticated gets own-row select/insert only (no
-- update/delete — reactions are permanent, matching the "prayed once" model).
revoke all on table public.prayer_reactions from anon;
revoke all on table public.prayer_reactions from authenticated;
grant select, insert on table public.prayer_reactions to authenticated;

revoke all on table public.post_encouragements from anon;
revoke all on table public.post_encouragements from authenticated;
grant select, insert on table public.post_encouragements to authenticated;

-- Rewrite the RPCs: insert-once into the backing table, then set the counter
-- to the real count(*) (never simply increment). Same names/signatures/
-- SECURITY DEFINER/search_path as 0004, so Swift callers (PrayForParams
-- {request_id}, EncouragePostParams {post_id}) keep working unchanged.
create or replace function public.pray_for(request_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_request_id uuid := request_id;
  v_count int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  insert into public.prayer_reactions (user_id, request_id)
  values (v_uid, v_request_id)
  on conflict (user_id, request_id) do nothing;

  update public.prayer_requests
     set prayed_count = (
       select count(*) from public.prayer_reactions
       where prayer_reactions.request_id = v_request_id
     )
   where id = v_request_id
  returning prayed_count into v_count;

  return v_count;
end;
$$;

create or replace function public.encourage_post(post_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_post_id uuid := post_id;
  v_count int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  insert into public.post_encouragements (user_id, post_id)
  values (v_uid, v_post_id)
  on conflict (user_id, post_id) do nothing;

  update public.community_posts
     set heart_count = (
       select count(*) from public.post_encouragements
       where post_encouragements.post_id = v_post_id
     )
   where id = v_post_id
  returning heart_count into v_count;

  return v_count;
end;
$$;

-- Preserve the effective post-0007 grants: authenticated only, no anon.
revoke all on function public.pray_for(uuid) from public;
revoke all on function public.pray_for(uuid) from anon;
grant execute on function public.pray_for(uuid) to authenticated;

revoke all on function public.encourage_post(uuid) from public;
revoke all on function public.encourage_post(uuid) from anon;
grant execute on function public.encourage_post(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- 3. create_circle: add the same active-account gate as create_micro (0030).
--    Signature/body otherwise unchanged from 0040_circles.sql.
-- ----------------------------------------------------------------------------
create or replace function public.create_circle(p_name text)
returns public.circles language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_circle public.circles;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if public.current_account_status() <> 'active' then
    raise exception 'account not active';
  end if;
  if coalesce(trim(p_name), '') = '' then raise exception 'name required'; end if;
  insert into public.circles (owner_user_id, name, join_code)
  values (v_uid, trim(p_name), public.co_gen_circle_code())
  returning * into v_circle;
  insert into public.circle_members (circle_id, user_id) values (v_circle.id, v_uid);
  return v_circle;
end; $$;

-- ----------------------------------------------------------------------------
-- 4. user_badges: no client insert. award_earned_badges() (0035) is
--    SECURITY DEFINER, so it is unaffected by this revoke.
-- ----------------------------------------------------------------------------
revoke insert on public.user_badges from authenticated;

-- ----------------------------------------------------------------------------
-- 5. user_notes: dedupe (keep the latest row per user/verse), then add a
--    unique index so the app can upsert on conflict (book,chapter,verse per
--    user) instead of risking duplicate rows / crashing on edit.
-- ----------------------------------------------------------------------------
delete from public.user_notes a
using public.user_notes b
where a.user_id = b.user_id
  and a.book = b.book
  and a.chapter = b.chapter
  and a.verse = b.verse
  and (
    a.created_at < b.created_at
    or (a.created_at = b.created_at and a.id < b.id)
  );

create unique index if not exists user_notes_user_verse_uniq
  on public.user_notes (user_id, book, chapter, verse);
