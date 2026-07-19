-- 0029: Community moderation — report→queue→action, effective blocking,
-- and content visibility states. (Apple UGC 1.2: reports must be actionable
-- within ~24h; EULA acceptance shipped in 0023.)
--
-- Design:
--   * prayer_requests / community_posts gain status
--     ('visible'|'hidden'|'removed'). The feed read policy shows ONLY
--     visible content — except authors always see their own rows (quiet
--     moderation, no retaliation surface). Admin review reads go through a
--     SECURITY DEFINER RPC, not a blanket table grant.
--   * Blocking now takes effect SERVER-SIDE: the read policies exclude any
--     author the caller has blocked (by user id when captured, by author
--     name as fallback) — not just client-side filtering.
--   * content_reports becomes a queue: status open|resolved|dismissed with
--     resolution metadata. Two admin RPCs (guarded by is_system_admin(),
--     never table grants): list open reports with the offending content
--     joined in, and resolve (dismiss / hide / remove). Hide/remove
--     resolves every open report against that content at once.
--   * No self-escalation: users keep only their existing insert/select-own
--     rights; all moderation power lives in the guarded RPCs.

-- ============================================================
-- 1. Content visibility states
-- ============================================================
alter table public.prayer_requests
  add column if not exists status text not null default 'visible'
  check (status in ('visible','hidden','removed'));

alter table public.community_posts
  add column if not exists status text not null default 'visible'
  check (status in ('visible','hidden','removed'));

-- ============================================================
-- 2. Feed read policies: visible-only + blocks enforced server-side
-- ============================================================
drop policy if exists "read prayers" on public.prayer_requests;
create policy "read prayers" on public.prayer_requests
  for select to authenticated
  using (
    (
      status = 'visible'
      and not exists (
        select 1 from public.user_blocks b
        where b.blocker_id = auth.uid()
          and (
            b.blocked_author_name = prayer_requests.author_name
            or (b.blocked_user_id is not null
                and b.blocked_user_id = prayer_requests.user_id)
          )
      )
    )
    or user_id = auth.uid()
  );

drop policy if exists "read posts" on public.community_posts;
create policy "read posts" on public.community_posts
  for select to authenticated
  using (
    (
      status = 'visible'
      and not exists (
        select 1 from public.user_blocks b
        where b.blocker_id = auth.uid()
          and (
            b.blocked_author_name = community_posts.author_name
            or (b.blocked_user_id is not null
                and b.blocked_user_id = community_posts.user_id)
          )
      )
    )
    or user_id = auth.uid()
  );

-- ============================================================
-- 3. Reports become a workable queue
-- ============================================================
alter table public.content_reports
  add column if not exists status text not null default 'open'
    check (status in ('open','resolved','dismissed')),
  add column if not exists resolution text,
  add column if not exists resolved_by uuid,
  add column if not exists resolved_at timestamptz;

create index if not exists content_reports_open_idx
  on public.content_reports (created_at desc) where status = 'open';

-- ============================================================
-- 4. Admin RPCs (system_admin only; SECURITY DEFINER)
-- ============================================================

-- Open reports with the offending content joined in. Returns nothing for
-- non-admins (guarded in the WHERE, and again by the resolve RPC).
create or replace function public.admin_list_open_reports()
returns table (
  report_id      uuid,
  created_at     timestamptz,
  content_kind   text,
  content_id     uuid,
  reason         text,
  detail         text,
  report_count   bigint,
  author_name    text,
  content_text   text,
  content_status text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    r.id, r.created_at, r.content_kind, r.content_id, r.reason, r.detail,
    (select count(*) from public.content_reports r2
      where r2.content_kind = r.content_kind
        and r2.content_id = r.content_id
        and r2.status = 'open') as report_count,
    coalesce(pr.author_name, cp.author_name) as author_name,
    coalesce(pr.body, cp.body)               as content_text,
    coalesce(pr.status, cp.status)           as content_status
  from public.content_reports r
  left join public.prayer_requests pr
    on r.content_kind = 'prayer_request' and pr.id = r.content_id
  left join public.community_posts cp
    on r.content_kind = 'community_post' and cp.id = r.content_id
  where r.status = 'open'
    and public.is_system_admin()
  order by r.created_at desc
$$;

revoke all on function public.admin_list_open_reports() from public;
revoke all on function public.admin_list_open_reports() from anon;
grant execute on function public.admin_list_open_reports() to authenticated;

-- Resolve one report: 'dismiss' closes just the report; 'hide' / 'remove'
-- change the content's status AND resolve every open report against it.
create or replace function public.admin_resolve_report(
  p_report_id uuid,
  p_action text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.content_reports%rowtype;
begin
  if not public.is_system_admin() then
    raise exception 'system_admin only';
  end if;
  if p_action not in ('dismiss','hide','remove') then
    raise exception 'invalid action: %', p_action;
  end if;

  select * into v_report from public.content_reports
  where id = p_report_id for update;
  if v_report.id is null then
    raise exception 'report not found';
  end if;

  if p_action = 'dismiss' then
    update public.content_reports
       set status = 'dismissed', resolution = 'dismiss',
           resolved_by = auth.uid(), resolved_at = now()
     where id = p_report_id;
    return;
  end if;

  if v_report.content_kind = 'prayer_request' then
    update public.prayer_requests
       set status = case p_action when 'hide' then 'hidden' else 'removed' end
     where id = v_report.content_id;
  elsif v_report.content_kind = 'community_post' then
    update public.community_posts
       set status = case p_action when 'hide' then 'hidden' else 'removed' end
     where id = v_report.content_id;
  end if;

  update public.content_reports
     set status = 'resolved', resolution = p_action,
         resolved_by = auth.uid(), resolved_at = now()
   where content_kind = v_report.content_kind
     and content_id = v_report.content_id
     and status = 'open';
end;
$$;

revoke all on function public.admin_resolve_report(uuid, text) from public;
revoke all on function public.admin_resolve_report(uuid, text) from anon;
grant execute on function public.admin_resolve_report(uuid, text) to authenticated;
