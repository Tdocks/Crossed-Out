-- Highlights + reaction RPCs
create table if not exists public.user_highlights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  book text not null,
  chapter int not null,
  verse int not null,
  created_at timestamptz not null default now(),
  unique (user_id, book, chapter, verse)
);
alter table public.user_highlights enable row level security;
create policy "own highlights" on public.user_highlights
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Atomic reaction counters (security definer so counts update without row ownership)
create or replace function public.pray_for(request_id uuid)
returns int language sql security definer set search_path = public as $$
  update public.prayer_requests
     set prayed_count = prayed_count + 1
   where id = request_id
  returning prayed_count;
$$;

create or replace function public.encourage_post(post_id uuid)
returns int language sql security definer set search_path = public as $$
  update public.community_posts
     set heart_count = heart_count + 1
   where id = post_id
  returning heart_count;
$$;

revoke all on function public.pray_for(uuid) from public;
revoke all on function public.encourage_post(uuid) from public;
grant execute on function public.pray_for(uuid) to authenticated, anon;
grant execute on function public.encourage_post(uuid) to authenticated, anon;
