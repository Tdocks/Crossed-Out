-- 0040_circles.sql
-- Private prayer/support CIRCLES, joined via a shareable code (no user
-- directory required). Membership powers the "My Circle" prayer filter.
-- All writes via SECURITY DEFINER RPCs.

create table if not exists public.circles (
  id            uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  name          text not null,
  join_code     text not null unique,
  created_at    timestamptz not null default now()
);

create table if not exists public.circle_members (
  circle_id uuid not null references public.circles(id) on delete cascade,
  user_id   uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);

alter table public.circles enable row level security;
alter table public.circle_members enable row level security;

-- A member can read circles they belong to. (Subquery hits circle_members,
-- whose own policy restricts to the caller's rows — so no recursion.)
drop policy if exists "read my circles" on public.circles;
create policy "read my circles" on public.circles
  for select using (
    exists (select 1 from public.circle_members m
            where m.circle_id = circles.id and m.user_id = auth.uid())
  );

-- Users read only their OWN membership rows directly (avoids self-referential
-- RLS recursion); co-member listing goes through the RPC below.
drop policy if exists "own circle membership" on public.circle_members;
create policy "own circle membership" on public.circle_members
  for select using (auth.uid() = user_id);

revoke all on table public.circles from anon;
revoke all on table public.circle_members from anon;
grant select on table public.circles to authenticated;
grant select on table public.circle_members to authenticated;
revoke insert, update, delete on public.circles from authenticated;
revoke insert, update, delete on public.circle_members from authenticated;

-- Unique 6-char join code generator.
create or replace function public.co_gen_circle_code()
returns text language plpgsql as $$
declare code text; ok boolean := false;
begin
  while not ok loop
    code := upper(substr(md5(gen_random_uuid()::text), 1, 6));
    ok := not exists (select 1 from public.circles where join_code = code);
  end loop;
  return code;
end; $$;

create or replace function public.create_circle(p_name text)
returns public.circles language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_circle public.circles;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if coalesce(trim(p_name), '') = '' then raise exception 'name required'; end if;
  insert into public.circles (owner_user_id, name, join_code)
  values (v_uid, trim(p_name), public.co_gen_circle_code())
  returning * into v_circle;
  insert into public.circle_members (circle_id, user_id) values (v_circle.id, v_uid);
  return v_circle;
end; $$;

create or replace function public.join_circle_by_code(p_code text)
returns public.circles language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_circle public.circles;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  select * into v_circle from public.circles where join_code = upper(trim(p_code));
  if v_circle.id is null then raise exception 'circle not found'; end if;
  insert into public.circle_members (circle_id, user_id)
  values (v_circle.id, v_uid) on conflict do nothing;
  return v_circle;
end; $$;

create or replace function public.leave_circle(p_circle_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.circle_members where circle_id = p_circle_id and user_id = auth.uid();
end; $$;

-- Member count for a circle the caller belongs to (no PII, just a count).
create or replace function public.circle_member_count(p_circle_id uuid)
returns int language sql stable security definer set search_path = public as $$
  select case
    when exists (select 1 from public.circle_members me
                 where me.circle_id = p_circle_id and me.user_id = auth.uid())
    then (select count(*)::int from public.circle_members where circle_id = p_circle_id)
    else 0 end;
$$;

revoke all on function public.create_circle(text) from public;
revoke all on function public.join_circle_by_code(text) from public;
revoke all on function public.leave_circle(uuid) from public;
revoke all on function public.circle_member_count(uuid) from public;
grant execute on function public.create_circle(text) to authenticated;
grant execute on function public.join_circle_by_code(text) to authenticated;
grant execute on function public.leave_circle(uuid) to authenticated;
grant execute on function public.circle_member_count(uuid) to authenticated;
