-- 0030: Micros — local micro-site groups who watch streamed church together
-- and coordinate in a small shared space (announcements + member updates).
-- Replaces the redundant "Local" segment in the Community tab.
--
-- Security model:
--   * Discovery is public to signed-in users: micros, members, and posts
--     are readable by `authenticated` (no anon access anywhere).
--   * Creating a micro goes through a SECURITY DEFINER RPC that enforces
--     the active-account gate, case-insensitive name uniqueness (friendly
--     'name_taken' error), and atomically creates the owner membership.
--   * Membership: own-row insert as 'member' only (no self-escalation to
--     owner), own-row delete for members only (an owner can't leave —
--     they delete the micro instead; the RLS delete policy enforces it).
--   * Posts: members only; announcements (pinned, with expiry) are
--     OWNER-only — both enforced in the insert policy. Author or the
--     micro's owner may delete a post.
--   * Pinned state is computed SERVER-SIDE (micro_feed RPC compares
--     expires_at to now()); expired announcements simply fall into the
--     chronological feed.

-- ============================================================
-- 1. Tables
-- ============================================================
create table if not exists public.micros (
  id            uuid primary key default gen_random_uuid(),
  name          text not null check (char_length(trim(name)) between 3 and 60),
  description   text not null default '' check (char_length(description) <= 400),
  city          text,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  created_at    timestamptz not null default now()
);

-- Case-insensitive unique names ("Viera Micro" == "viera micro").
create unique index if not exists micros_name_lower_uq
  on public.micros (lower(trim(name)));

create table if not exists public.micro_members (
  micro_id  uuid not null references public.micros(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  role      text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (micro_id, user_id)
);

create table if not exists public.micro_posts (
  id              uuid primary key default gen_random_uuid(),
  micro_id        uuid not null references public.micros(id) on delete cascade,
  author_user_id  uuid not null references auth.users(id) on delete cascade,
  author_name     text not null,
  body            text not null check (char_length(body) between 1 and 2000),
  is_announcement boolean not null default false,
  expires_at      timestamptz,          -- announcements only; null = permanent pin
  created_at      timestamptz not null default now()
);

create index if not exists micro_posts_micro_created_idx
  on public.micro_posts (micro_id, created_at desc);

-- ============================================================
-- 2. RLS
-- ============================================================
alter table public.micros enable row level security;
alter table public.micro_members enable row level security;
alter table public.micro_posts enable row level security;

-- micros: read for discovery; delete by owner only; insert ONLY via RPC.
drop policy if exists "read micros" on public.micros;
create policy "read micros" on public.micros
  for select to authenticated using (true);

drop policy if exists "owner delete micro" on public.micros;
create policy "owner delete micro" on public.micros
  for delete to authenticated using (owner_user_id = auth.uid());

-- micro_members: read for member lists/joined checks; join as member only
-- (active accounts); members may leave, owners may not (delete the micro).
drop policy if exists "read micro_members" on public.micro_members;
create policy "read micro_members" on public.micro_members
  for select to authenticated using (true);

drop policy if exists "join micro" on public.micro_members;
create policy "join micro" on public.micro_members
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and role = 'member'
    and public.current_account_status() = 'active'
  );

drop policy if exists "leave micro" on public.micro_members;
create policy "leave micro" on public.micro_members
  for delete to authenticated
  using (auth.uid() = user_id and role = 'member');

-- micro_posts: read for all signed-in; insert by members (announcements by
-- the owner only); delete by the author or the micro's owner.
drop policy if exists "read micro_posts" on public.micro_posts;
create policy "read micro_posts" on public.micro_posts
  for select to authenticated using (true);

drop policy if exists "insert micro_posts" on public.micro_posts;
create policy "insert micro_posts" on public.micro_posts
  for insert to authenticated
  with check (
    auth.uid() = author_user_id
    and public.current_account_status() = 'active'
    and exists (
      select 1 from public.micro_members m
      where m.micro_id = micro_posts.micro_id and m.user_id = auth.uid()
    )
    and (
      not is_announcement
      or exists (
        select 1 from public.micros mi
        where mi.id = micro_posts.micro_id and mi.owner_user_id = auth.uid()
      )
    )
  );

drop policy if exists "delete micro_posts" on public.micro_posts;
create policy "delete micro_posts" on public.micro_posts
  for delete to authenticated
  using (
    auth.uid() = author_user_id
    or exists (
      select 1 from public.micros mi
      where mi.id = micro_posts.micro_id and mi.owner_user_id = auth.uid()
    )
  );

revoke all on table public.micros from anon;
revoke all on table public.micro_members from anon;
revoke all on table public.micro_posts from anon;
grant select, delete on table public.micros to authenticated;
grant select, insert, delete on table public.micro_members to authenticated;
grant select, insert, delete on table public.micro_posts to authenticated;

-- ============================================================
-- 3. RPCs
-- ============================================================

-- Creates a micro atomically: active-account gate, case-insensitive unique
-- name (friendly 'name_taken'), owner membership row. Returns the new id.
create or replace function public.create_micro(
  p_name text,
  p_description text default '',
  p_city text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if public.current_account_status() <> 'active' then
    raise exception 'account not active';
  end if;
  if char_length(trim(coalesce(p_name, ''))) < 3 then
    raise exception 'name too short';
  end if;

  begin
    insert into public.micros (name, description, city, owner_user_id)
    values (trim(p_name), coalesce(trim(p_description), ''),
            nullif(trim(coalesce(p_city, '')), ''), v_uid)
    returning id into v_id;
  exception when unique_violation then
    raise exception 'name_taken';
  end;

  insert into public.micro_members (micro_id, user_id, role)
  values (v_id, v_uid, 'owner');

  return v_id;
end;
$$;

revoke all on function public.create_micro(text, text, text) from public;
revoke all on function public.create_micro(text, text, text) from anon;
grant execute on function public.create_micro(text, text, text) to authenticated;

-- The micro's feed with pinned state computed server-side: an announcement
-- is pinned while expires_at is null (permanent) or still in the future.
-- SECURITY INVOKER — normal RLS applies.
create or replace function public.micro_feed(p_micro_id uuid)
returns table (
  id uuid, micro_id uuid, author_user_id uuid, author_name text,
  body text, is_announcement boolean, expires_at timestamptz,
  created_at timestamptz, pinned boolean
)
language sql
stable
set search_path = public
as $$
  select
    p.id, p.micro_id, p.author_user_id, p.author_name,
    p.body, p.is_announcement, p.expires_at, p.created_at,
    (p.is_announcement and (p.expires_at is null or p.expires_at > now())) as pinned
  from public.micro_posts p
  where p.micro_id = p_micro_id
  order by p.created_at desc
  limit 200
$$;

revoke all on function public.micro_feed(uuid) from public;
revoke all on function public.micro_feed(uuid) from anon;
grant execute on function public.micro_feed(uuid) to authenticated;
