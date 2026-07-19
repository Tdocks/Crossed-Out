-- ============================================================================
-- 0032 — Attend: online -> in-person visit-planning bridge.
--
-- Adds:
--   1. church_attendance — one row per real "watch" of a church's stream
--      (recorded from ServiceDetailView's startWatching(), never a page
--      view). Own-rows RLS. Repeat attendance (2+ watches of the same
--      church) unlocks the "Plan a Visit" affordance client-side.
--   2. church_visit_intents — a light, deterministic "I'm planning to
--      visit" signal from the Plan-a-Visit sheet's "Let them know you're
--      coming" action. Own-rows RLS. No marketing capture — just a row.
--   3. Practical visit-info columns on churches (address, service_times,
--      parking_info, kids_info, accessibility_info, newcomer_info),
--      publicly readable (existing "read published churches" policy),
--      writable only by the church's own admin (or a system_admin) via an
--      extended update_my_church RPC — never a direct table write.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. church_attendance
-- ----------------------------------------------------------------------------
create table if not exists public.church_attendance (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  church_id  uuid not null references public.churches(id) on delete cascade,
  watched_at timestamptz not null default now()
);

create index if not exists church_attendance_user_church_idx
  on public.church_attendance (user_id, church_id);

alter table public.church_attendance enable row level security;

drop policy if exists "own church attendance" on public.church_attendance;
create policy "own church attendance" on public.church_attendance
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

revoke all on table public.church_attendance from anon, authenticated;
grant select, insert on table public.church_attendance to authenticated;

-- ----------------------------------------------------------------------------
-- 2. church_visit_intents
-- ----------------------------------------------------------------------------
create table if not exists public.church_visit_intents (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  church_id  uuid not null references public.churches(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists church_visit_intents_user_church_idx
  on public.church_visit_intents (user_id, church_id);

alter table public.church_visit_intents enable row level security;

drop policy if exists "own church visit intents" on public.church_visit_intents;
create policy "own church visit intents" on public.church_visit_intents
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

revoke all on table public.church_visit_intents from anon, authenticated;
grant select, insert on table public.church_visit_intents to authenticated;

-- ----------------------------------------------------------------------------
-- 3. Practical visit-info columns on churches.
--    Readable by everyone the church itself is readable to (the existing
--    "read published churches" policy from 0021 already covers these new
--    columns — no policy change needed). All writes still go through
--    SECURITY DEFINER RPCs only (0021 revoked direct authenticated/anon
--    writes on this table).
-- ----------------------------------------------------------------------------
alter table public.churches add column if not exists address             text;
alter table public.churches add column if not exists service_times       text;
alter table public.churches add column if not exists parking_info        text;
alter table public.churches add column if not exists kids_info           text;
alter table public.churches add column if not exists accessibility_info  text;
alter table public.churches add column if not exists newcomer_info       text;

-- ----------------------------------------------------------------------------
-- 4. Extend update_my_church (0021) to cover the new visit-info fields, and
--    let a system_admin target an arbitrary church via p_church_id (still
--    gated by is_system_admin() — a plain church_admin passing p_church_id
--    is silently ignored and falls back to their own church, same as
--    before). The parameter list changes, so drop + recreate rather than
--    OR REPLACE.
-- ----------------------------------------------------------------------------
drop function if exists public.update_my_church(text,text,text,text,text,text,text);

create or replace function public.update_my_church(
  p_name               text default null,
  p_city               text default null,
  p_denomination       text default null,
  p_style              text default null,
  p_youtube_handle     text default null,
  p_website_url        text default null,
  p_contact_email      text default null,
  p_address            text default null,
  p_service_times      text default null,
  p_parking_info       text default null,
  p_kids_info          text default null,
  p_accessibility_info text default null,
  p_newcomer_info      text default null,
  p_church_id          uuid default null
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_church_id uuid;
begin
  if p_church_id is not null and public.is_system_admin() then
    v_church_id := p_church_id;
  else
    v_church_id := public.my_church_id();
  end if;

  if v_church_id is null then
    raise exception 'no church to manage';
  end if;

  update public.churches set
    name               = coalesce(nullif(trim(coalesce(p_name,'')),''), name),
    city               = coalesce(nullif(trim(coalesce(p_city,'')),''), city),
    denomination       = coalesce(p_denomination, denomination),
    style              = coalesce(nullif(trim(coalesce(p_style,'')),''), style),
    youtube_handle     = coalesce(p_youtube_handle, youtube_handle),
    website_url        = coalesce(p_website_url, website_url),
    contact_email      = coalesce(p_contact_email, contact_email),
    address            = coalesce(p_address, address),
    service_times      = coalesce(p_service_times, service_times),
    parking_info       = coalesce(p_parking_info, parking_info),
    kids_info          = coalesce(p_kids_info, kids_info),
    accessibility_info = coalesce(p_accessibility_info, accessibility_info),
    newcomer_info      = coalesce(p_newcomer_info, newcomer_info)
  where id = v_church_id;
end;
$$;

grant execute on function public.update_my_church(
  text,text,text,text,text,text,text,text,text,text,text,text,text,uuid
) to authenticated;
