-- 0041_prayer_scope.sql
-- Scope prayer requests for the filter (Everyone / My Church / Mine / My Circle).
--   Everyone, Mine  -> existing columns (no change).
--   My Church       -> new church_id, set server-side from the author's primary
--                      church membership (0039) at posting time.
--   My Circle       -> RPC returning co-circle-members' requests (0040).

alter table public.prayer_requests
  add column if not exists church_id uuid references public.churches(id) on delete set null;

-- Stamp church_id from the author's primary (or earliest) church membership.
create or replace function public.co_set_prayer_church()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.church_id := (
    select church_id from public.church_members
    where user_id = new.user_id
    order by is_primary desc, joined_at asc
    limit 1
  );
  return new;
end; $$;

drop trigger if exists co_set_prayer_church_ins on public.prayer_requests;
create trigger co_set_prayer_church_ins
  before insert on public.prayer_requests
  for each row execute function public.co_set_prayer_church();

-- "My Circle": visible prayer requests from users who share a circle with me.
create or replace function public.circle_prayer_requests()
returns setof public.prayer_requests
language sql stable security definer set search_path = public as $$
  select pr.* from public.prayer_requests pr
  where coalesce(pr.status, 'visible') = 'visible'
    and pr.user_id in (
      select distinct cm2.user_id
      from public.circle_members cm1
      join public.circle_members cm2 on cm1.circle_id = cm2.circle_id
      where cm1.user_id = auth.uid()
    )
  order by pr.created_at desc;
$$;

revoke all on function public.circle_prayer_requests() from public;
grant execute on function public.circle_prayer_requests() to authenticated;
