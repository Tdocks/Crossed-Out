-- 0043_micro_moderation.sql
-- Audit BLOCKER: reported micro posts could not be moderated — micro_posts
-- had no status column, content_reports rejected content_kind='micro_post',
-- and neither admin RPC nor the micro read policy knew about micros at all.
-- Mirrors the community_posts / prayer_requests moderation model shipped in
-- 0029_community_moderation.sql.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. micro_posts: visibility state, same three values as prayer_requests /
--    community_posts.
-- ----------------------------------------------------------------------------
alter table public.micro_posts
  add column if not exists status text not null default 'visible'
  check (status in ('visible','hidden','removed'));

-- ----------------------------------------------------------------------------
-- 2. content_reports.content_kind: allow 'micro_post' (this migration) and
--    'kyra_message' (Kyra report path, added by another agent). Drop and
--    recreate the inline check constraint with the existing allowed values
--    plus these two.
-- ----------------------------------------------------------------------------
alter table public.content_reports
  drop constraint if exists content_reports_content_kind_check;

alter table public.content_reports
  add constraint content_reports_content_kind_check
  check (content_kind in (
    'prayer_request','community_post','other','micro_post','kyra_message'
  ));

-- ----------------------------------------------------------------------------
-- 3 & 4. Admin RPCs: surface + resolve micro_post reports.
--    Same signatures/guards as 0029_community_moderation.sql, with a
--    micro_posts LEFT JOIN added to admin_list_open_reports() and a
--    micro_post branch added to admin_resolve_report() alongside the
--    existing prayer_request / community_post branches.
-- ----------------------------------------------------------------------------
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
    coalesce(pr.author_name, cp.author_name, mp.author_name) as author_name,
    coalesce(pr.body, cp.body, mp.body)                      as content_text,
    coalesce(pr.status, cp.status, mp.status)                as content_status
  from public.content_reports r
  left join public.prayer_requests pr
    on r.content_kind = 'prayer_request' and pr.id = r.content_id
  left join public.community_posts cp
    on r.content_kind = 'community_post' and cp.id = r.content_id
  left join public.micro_posts mp
    on r.content_kind = 'micro_post' and mp.id = r.content_id
  where r.status = 'open'
    and public.is_system_admin()
  order by r.created_at desc
$$;

revoke all on function public.admin_list_open_reports() from public;
revoke all on function public.admin_list_open_reports() from anon;
grant execute on function public.admin_list_open_reports() to authenticated;

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
  elsif v_report.content_kind = 'micro_post' then
    update public.micro_posts
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

-- ----------------------------------------------------------------------------
-- 5. micro_posts read RLS: exclude blocked authors and hide non-visible rows,
--    mirroring the 0029 prayer_requests / community_posts pattern, with an
--    added exception for the micro's owner (moderation visibility) alongside
--    the post's own author.
-- ----------------------------------------------------------------------------
drop policy if exists "read micro_posts" on public.micro_posts;
create policy "read micro_posts" on public.micro_posts
  for select to authenticated
  using (
    (
      status = 'visible'
      and not exists (
        select 1 from public.user_blocks b
        where b.blocker_id = auth.uid()
          and (
            b.blocked_author_name = micro_posts.author_name
            or (b.blocked_user_id is not null
                and b.blocked_user_id = micro_posts.author_user_id)
          )
      )
    )
    or author_user_id = auth.uid()
    or exists (
      select 1 from public.micros mi
      where mi.id = micro_posts.micro_id and mi.owner_user_id = auth.uid()
    )
  );
