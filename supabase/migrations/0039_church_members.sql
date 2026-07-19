-- 0039_church_members.sql
-- Church MEMBERSHIP: a user can JOIN one or more churches (many-to-many).
-- Distinct from bookmarking (saved_churches) and from church_admin ownership
-- (profiles.church_id, which is admin-only). All writes go through
-- SECURITY DEFINER RPCs — mirrors the no-self-escalation model of 0021.

create table if not exists public.church_members (
  user_id    uuid not null references auth.users(id) on delete cascade,
  church_id  uuid not null references public.churches(id) on delete cascade,
  is_primary boolean not null default true,
  joined_at  timestamptz not null default now(),
  primary key (user_id, church_id)
);

alter table public.church_members enable row level security;

drop policy if exists "own memberships" on public.church_members;
create policy "own memberships" on public.church_members
  for select using (auth.uid() = user_id);

revoke all on table public.church_members from anon;
grant select on table public.church_members to authenticated;
-- No direct writes: mutation only via the RPCs below.
revoke insert, update, delete on public.church_members from authenticated;

create or replace function public.join_church(p_church_id uuid, p_primary boolean default true)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from public.churches where id = p_church_id and is_published) then
    raise exception 'church not found';
  end if;
  if p_primary then
    update public.church_members set is_primary = false
      where user_id = v_uid and church_id <> p_church_id;
  end if;
  insert into public.church_members (user_id, church_id, is_primary)
  values (v_uid, p_church_id, p_primary)
  on conflict (user_id, church_id) do update set is_primary = excluded.is_primary;
end; $$;

create or replace function public.leave_church(p_church_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.church_members where user_id = auth.uid() and church_id = p_church_id;
end; $$;

revoke all on function public.join_church(uuid, boolean) from public;
revoke all on function public.leave_church(uuid) from public;
grant execute on function public.join_church(uuid, boolean) to authenticated;
grant execute on function public.leave_church(uuid) to authenticated;
