-- ============================================================================
-- 0021 — Roles, account verification, church admins, and the church portal.
--
-- Adds a three-tier role system (user / church_admin / system_admin) and an
-- account_status gate (active / pending_verification / suspended), links
-- church_admins to the church they manage, and adds an invite-token flow that
-- lets a system_admin hand a church rep a link that auto-approves their
-- church_admin account.
--
-- Security model:
--   * Regular users self-sign-up and are 'active' immediately.
--   * Churches that self-sign-up IN THE APP become 'pending_verification' and
--     have NO app access until a system_admin verifies them.
--   * Churches that sign up via a valid INVITE LINK are auto-approved 'active'.
--   * role / account_status / church_id are NOT user-writable — they can only
--     be changed through the SECURITY DEFINER RPCs below. This closes the
--     self-escalation hole in the existing "own profile" (FOR ALL) policy.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Profile columns: role, status, church linkage.
-- ----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists role text not null default 'user'
    check (role in ('user','church_admin','system_admin'));

alter table public.profiles
  add column if not exists account_status text not null default 'active'
    check (account_status in ('active','pending_verification','suspended'));

alter table public.profiles
  add column if not exists church_id uuid references public.churches(id) on delete set null;

-- ----------------------------------------------------------------------------
-- 2. Church columns: contact + provenance + publish gate.
--    is_published=false hides a church (and its live services) from the app
--    until a system_admin verifies it. Existing seeded churches default to
--    published so nothing already live disappears.
-- ----------------------------------------------------------------------------
alter table public.churches add column if not exists contact_email text;
alter table public.churches add column if not exists website_url text;
alter table public.churches add column if not exists youtube_handle text;
-- Defensive: these normally arrive in 0018/0020, re-declared idempotently so
-- this migration's RPCs compile regardless of prior migration ordering.
alter table public.churches add column if not exists platform text;
alter table public.churches add column if not exists denomination text;
alter table public.churches add column if not exists submitted_by uuid references auth.users(id) on delete set null;
alter table public.churches add column if not exists is_published boolean not null default true;
alter table public.churches add column if not exists created_at timestamptz not null default now();

-- ----------------------------------------------------------------------------
-- 3. System-admin allow-list + auto-promotion trigger.
--    Any profile whose auth email is in system_admin_emails is promoted to
--    system_admin on insert. Seeded with Tyler's email; add rows to grant
--    more system admins later. Also backfilled below for existing accounts.
-- ----------------------------------------------------------------------------
create table if not exists public.system_admin_emails (
  email text primary key
);
insert into public.system_admin_emails(email)
  values ('tdoxwell@icloud.com')
  on conflict (email) do nothing;

alter table public.system_admin_emails enable row level security;
-- No policies => only SECURITY DEFINER functions / service role can read it.

create or replace function public.co_promote_admin_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if exists (
    select 1
    from auth.users u
    join public.system_admin_emails a on lower(a.email) = lower(u.email)
    where u.id = new.id
  ) then
    new.role := 'system_admin';
    new.account_status := 'active';
  end if;
  return new;
end;
$$;

drop trigger if exists co_promote_admin_on_insert on public.profiles;
create trigger co_promote_admin_on_insert
  before insert on public.profiles
  for each row execute function public.co_promote_admin_on_insert();

-- ----------------------------------------------------------------------------
-- 4. SECURITY DEFINER identity helpers.
--    These read the caller's own profile row as the function owner (bypassing
--    RLS) so they can be used INSIDE profiles/churches policies without the
--    infinite-recursion that a direct sub-select on profiles would cause.
-- ----------------------------------------------------------------------------
create or replace function public.is_system_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists(
    select 1 from public.profiles
    where id = auth.uid() and role = 'system_admin'
  );
$$;

create or replace function public.current_account_status()
returns text
language sql stable security definer set search_path = public
as $$
  select coalesce(
    (select account_status from public.profiles where id = auth.uid()),
    'active'
  );
$$;

create or replace function public.my_church_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select church_id from public.profiles where id = auth.uid();
$$;

grant execute on function public.is_system_admin() to authenticated;
grant execute on function public.current_account_status() to authenticated;
grant execute on function public.my_church_id() to authenticated;

-- ----------------------------------------------------------------------------
-- 5. Invite tokens. Minted by a system_admin, redeemed once by the church rep
--    who receives the link. Direct table access is admin-only; the anon
--    validate + authenticated redeem RPCs below are the supported path.
-- ----------------------------------------------------------------------------
create table if not exists public.church_invites (
  id uuid primary key default gen_random_uuid(),
  token text not null unique,
  church_name text,
  contact_email text,
  created_by uuid references auth.users(id) on delete set null,
  expires_at timestamptz not null default (now() + interval '30 days'),
  used_at timestamptz,
  used_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.church_invites enable row level security;

-- Only system admins may look at the raw invite table.
drop policy if exists "admin read invites" on public.church_invites;
create policy "admin read invites" on public.church_invites
  for select to authenticated using (public.is_system_admin());

-- ----------------------------------------------------------------------------
-- 6. Self-escalation lockdown.
--    The existing "own profile" policy is FOR ALL, so a user could otherwise
--    INSERT or UPDATE their own row with role='system_admin'. A COLUMN-level
--    revoke is NOT enough: Postgres lets a table-level INSERT/UPDATE grant
--    (which Supabase gives `authenticated` by default) write every column,
--    overriding any per-column revoke. So we DROP the table-level grants and
--    re-GRANT only the profile fields the client is allowed to touch. role /
--    account_status / church_id then fall to their defaults on insert and are
--    writable ONLY through the SECURITY DEFINER RPCs (which run as owner). The
--    BEFORE-INSERT admin trigger can still set role because trigger-assigned
--    NEW values are not checked against the invoker's column privileges.
-- ----------------------------------------------------------------------------
revoke insert, update on public.profiles from authenticated;
grant insert (id, first_name, need, translation, day_number, focus_areas)
  on public.profiles to authenticated;
grant update (first_name, need, translation, day_number, focus_areas)
  on public.profiles to authenticated;

-- The admin allow-list is never client-readable (RLS on + no policy, and no
-- grants). Only SECURITY DEFINER functions / service role can see it.
revoke all on public.system_admin_emails from anon, authenticated;

-- Let system admins read every profile (needed to list pending churches and
-- to resolve a church_admin's account). Kept separate from "own profile".
drop policy if exists "admin read profiles" on public.profiles;
create policy "admin read profiles" on public.profiles
  for select to authenticated using (public.is_system_admin());

-- ----------------------------------------------------------------------------
-- 7. Churches RLS — publish-gated reads; ALL writes go through SECURITY
--    DEFINER RPCs (submit_church_application / redeem_church_invite /
--    update_my_church / admin_verify|reject) or the service role (the live
--    stream pipeline + add_church). App users get NO direct table writes, so
--    a church_admin cannot self-publish or forge ownership, and the
--    column-grant gotcha from section 6 cannot bite us here.
-- ----------------------------------------------------------------------------
revoke insert, update, delete on public.churches from authenticated;
revoke insert, update, delete on public.churches from anon;

drop policy if exists "read churches" on public.churches;
drop policy if exists "read published churches" on public.churches;
create policy "read published churches" on public.churches
  for select using (
    is_published
    or id = public.my_church_id()
    or public.is_system_admin()
  );

-- These older/earlier-draft write policies are intentionally removed: with the
-- grants above revoked, all writes are RPC/service-role only.
drop policy if exists "church admin updates own church" on public.churches;
drop policy if exists "system admin writes churches" on public.churches;

-- ----------------------------------------------------------------------------
-- 8. Live services follow their church's publish gate (hide pending churches
--    from the Attend feed), with a system_admin override.
-- ----------------------------------------------------------------------------
drop policy if exists "read services" on public.live_services;
create policy "read services" on public.live_services
  for select using (
    exists (
      select 1 from public.churches c
      where c.id = live_services.church_id
        and (c.is_published or public.is_system_admin())
    )
  );

-- ----------------------------------------------------------------------------
-- 9. Community defense-in-depth: only 'active' accounts may post. Pending
--    church accounts have no client access anyway, but this enforces it at
--    the database layer too.
-- ----------------------------------------------------------------------------
drop policy if exists "insert prayers" on public.prayer_requests;
create policy "insert prayers" on public.prayer_requests
  for insert to authenticated
  with check (auth.uid() = user_id and public.current_account_status() = 'active');

drop policy if exists "insert posts" on public.community_posts;
create policy "insert posts" on public.community_posts
  for insert to authenticated
  with check (auth.uid() = user_id and public.current_account_status() = 'active');

-- ----------------------------------------------------------------------------
-- 10. RPCs
-- ----------------------------------------------------------------------------

-- Ensures a profile row exists for the caller (church reps may redeem/apply
-- before ever completing consumer onboarding). Does not touch role/status.
create or replace function public.co_ensure_profile(p_first_name text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, first_name)
  values (auth.uid(), coalesce(nullif(trim(p_first_name), ''), ''))
  on conflict (id) do nothing;
end;
$$;

-- IN-APP church self-signup. Creates an UNPUBLISHED church and puts the
-- caller's account into pending_verification — no app access until a system
-- admin verifies. Returns the new church id.
create or replace function public.submit_church_application(
  p_contact_name text,
  p_church_name text,
  p_city text,
  p_denomination text default null,
  p_style text default 'Contemporary',
  p_youtube_handle text default null,
  p_website_url text default null,
  p_contact_email text default null
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_church_id uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if coalesce(trim(p_church_name),'') = '' or coalesce(trim(p_city),'') = '' then
    raise exception 'church name and city are required';
  end if;

  perform public.co_ensure_profile(p_contact_name);

  insert into public.churches
    (name, city, style, denomination, platform, youtube_handle,
     website_url, contact_email, submitted_by, is_published)
  values
    (trim(p_church_name), trim(p_city), coalesce(p_style,'Contemporary'),
     p_denomination, 'youtube', p_youtube_handle, p_website_url,
     coalesce(p_contact_email, (select email from auth.users where id = v_uid)),
     v_uid, false)
  returning id into v_church_id;

  update public.profiles
     set role = 'church_admin',
         account_status = 'pending_verification',
         church_id = v_church_id
   where id = v_uid;

  return v_church_id;
end;
$$;

grant execute on function public.co_ensure_profile(text) to authenticated;
grant execute on function public.submit_church_application(text,text,text,text,text,text,text,text) to authenticated;

-- Anon-callable: lets the portal show the invited church's name and confirm a
-- link is still good BEFORE the rep creates an account. Never exposes the
-- token list; only answers about the one token supplied.
create or replace function public.validate_church_invite(p_token text)
returns json
language sql stable security definer set search_path = public
as $$
  select case
    when i.id is null then json_build_object('valid', false, 'reason', 'not_found')
    when i.used_at is not null then json_build_object('valid', false, 'reason', 'used')
    when i.expires_at < now() then json_build_object('valid', false, 'reason', 'expired')
    else json_build_object(
      'valid', true,
      'church_name', i.church_name,
      'contact_email', i.contact_email
    )
  end
  from (select * from public.church_invites where token = p_token) i
  right join (select 1) _ on true;
$$;

-- Redeemed by the freshly-signed-up rep (they have a session). Auto-approves:
-- role=church_admin, status=ACTIVE, publishes the church. Atomic + single-use.
create or replace function public.redeem_church_invite(
  p_token text,
  p_contact_name text,
  p_church_name text,
  p_city text,
  p_denomination text default null,
  p_style text default 'Contemporary',
  p_youtube_handle text default null,
  p_website_url text default null,
  p_contact_email text default null
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_church_id uuid;
  v_invite public.church_invites%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_invite from public.church_invites where token = p_token for update;
  if v_invite.id is null then raise exception 'invite not found'; end if;
  if v_invite.used_at is not null then raise exception 'invite already used'; end if;
  if v_invite.expires_at < now() then raise exception 'invite expired'; end if;
  if coalesce(trim(p_church_name),'') = '' or coalesce(trim(p_city),'') = '' then
    raise exception 'church name and city are required';
  end if;

  perform public.co_ensure_profile(p_contact_name);

  insert into public.churches
    (name, city, style, denomination, platform, youtube_handle,
     website_url, contact_email, submitted_by, is_published)
  values
    (trim(p_church_name), trim(p_city), coalesce(p_style,'Contemporary'),
     coalesce(p_denomination, v_invite.church_name), 'youtube', p_youtube_handle,
     p_website_url, coalesce(p_contact_email, v_invite.contact_email,
       (select email from auth.users where id = v_uid)),
     v_uid, true)
  returning id into v_church_id;

  update public.profiles
     set role = 'church_admin',
         account_status = 'active',
         church_id = v_church_id
   where id = v_uid;

  update public.church_invites
     set used_at = now(), used_by = v_uid
   where id = v_invite.id;

  return v_church_id;
end;
$$;

grant execute on function public.validate_church_invite(text) to anon, authenticated;
grant execute on function public.redeem_church_invite(text,text,text,text,text,text,text,text,text) to authenticated;

-- system_admin: mint an invite link token. Returns the token string; the
-- portal wraps it into a full URL. Guarded internally (not just by grant).
create or replace function public.create_church_invite(
  p_church_name text default null,
  p_contact_email text default null,
  p_expires_days int default 30
)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_token text;
begin
  if not public.is_system_admin() then
    raise exception 'system_admin only';
  end if;
  v_token := encode(gen_random_bytes(18), 'hex');
  insert into public.church_invites (token, church_name, contact_email, created_by, expires_at)
  values (v_token, nullif(trim(coalesce(p_church_name,'')),''),
          nullif(trim(coalesce(p_contact_email,'')),''),
          auth.uid(), now() + make_interval(days => greatest(1, coalesce(p_expires_days,30))));
  return v_token;
end;
$$;

-- system_admin: list church accounts awaiting verification (in-app signups).
create or replace function public.admin_list_pending_churches()
returns table (
  user_id uuid,
  contact_email text,
  church_id uuid,
  church_name text,
  city text,
  youtube_handle text,
  submitted_at timestamptz
)
language sql stable security definer set search_path = public, auth
as $$
  select p.id, u.email, c.id, c.name, c.city, c.youtube_handle, c.created_at
  from public.profiles p
  join auth.users u on u.id = p.id
  left join public.churches c on c.id = p.church_id
  where public.is_system_admin()
    and p.role = 'church_admin'
    and p.account_status = 'pending_verification'
  order by c.created_at desc nulls last;
$$;

-- system_admin: approve a pending church account + publish its church.
create or replace function public.admin_verify_church_account(p_user_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_system_admin() then
    raise exception 'system_admin only';
  end if;
  update public.profiles set account_status = 'active'
    where id = p_user_id and role = 'church_admin';
  update public.churches set is_published = true
    where id = (select church_id from public.profiles where id = p_user_id);
end;
$$;

-- system_admin: reject/suspend a pending church account (keeps the record).
create or replace function public.admin_reject_church_account(p_user_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_system_admin() then
    raise exception 'system_admin only';
  end if;
  update public.profiles set account_status = 'suspended'
    where id = p_user_id and role = 'church_admin';
  update public.churches set is_published = false
    where id = (select church_id from public.profiles where id = p_user_id);
end;
$$;

-- church_admin: edit the church they manage. Only their own church; publish
-- gate is untouched here (that's a system_admin decision).
create or replace function public.update_my_church(
  p_name text default null,
  p_city text default null,
  p_denomination text default null,
  p_style text default null,
  p_youtube_handle text default null,
  p_website_url text default null,
  p_contact_email text default null
)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_church_id uuid := public.my_church_id();
begin
  if v_church_id is null then
    raise exception 'no church to manage';
  end if;
  update public.churches set
    name          = coalesce(nullif(trim(coalesce(p_name,'')),''), name),
    city          = coalesce(nullif(trim(coalesce(p_city,'')),''), city),
    denomination  = coalesce(p_denomination, denomination),
    style         = coalesce(nullif(trim(coalesce(p_style,'')),''), style),
    youtube_handle= coalesce(p_youtube_handle, youtube_handle),
    website_url   = coalesce(p_website_url, website_url),
    contact_email = coalesce(p_contact_email, contact_email)
  where id = v_church_id;
end;
$$;

grant execute on function public.create_church_invite(text,text,int) to authenticated;
grant execute on function public.admin_list_pending_churches() to authenticated;
grant execute on function public.admin_verify_church_account(uuid) to authenticated;
grant execute on function public.admin_reject_church_account(uuid) to authenticated;
grant execute on function public.update_my_church(text,text,text,text,text,text,text) to authenticated;

-- ----------------------------------------------------------------------------
-- 11. Backfill: promote any EXISTING account whose email is in the allow-list
--     (the insert trigger only fires for new rows). This makes Tyler a
--     system_admin immediately if his profile already exists.
-- ----------------------------------------------------------------------------
update public.profiles p
   set role = 'system_admin', account_status = 'active'
  from auth.users u
  join public.system_admin_emails a on lower(a.email) = lower(u.email)
 where u.id = p.id
   and p.role <> 'system_admin';
