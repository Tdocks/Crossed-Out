-- Content reporting, user blocking, account deletion (App Review requirements)
create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  content_kind text not null check (content_kind in ('prayer_request','community_post','other')),
  content_id uuid,
  reason text not null,
  detail text,
  created_at timestamptz not null default now()
);
alter table public.content_reports enable row level security;
create policy "insert own reports" on public.content_reports
  for insert with check (auth.uid() = reporter_id);
create policy "read own reports" on public.content_reports
  for select using (auth.uid() = reporter_id);

create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid,
  blocked_author_name text not null,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_author_name)
);
alter table public.user_blocks enable row level security;
create policy "own blocks" on public.user_blocks
  for all using (auth.uid() = blocker_id) with check (auth.uid() = blocker_id);

-- Account deletion: removes the auth user; all app rows cascade via FKs.
create or replace function public.delete_own_account()
returns void language sql security definer set search_path = public, auth as $$
  delete from auth.users where id = auth.uid();
$$;
revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
