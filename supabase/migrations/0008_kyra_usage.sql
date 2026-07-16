-- Per-user daily rate limiting for the Kyra edge function (protects OpenAI spend).
create table if not exists public.kyra_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null default (now() at time zone 'utc')::date,
  count int not null default 0,
  primary key (user_id, usage_date)
);
alter table public.kyra_usage enable row level security;
drop policy if exists "read own kyra usage" on public.kyra_usage;
create policy "read own kyra usage" on public.kyra_usage
  for select using (auth.uid() = user_id);

-- Atomically checks + increments today's usage count for the calling user.
-- Returns true and increments when under p_limit; returns false and leaves
-- the row untouched (so it can never grow past the limit) when at/over it.
create or replace function public.increment_kyra_usage(p_limit int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_count int;
begin
  if v_user_id is null then
    return false;
  end if;

  insert into public.kyra_usage (user_id, usage_date, count)
  values (v_user_id, (now() at time zone 'utc')::date, 0)
  on conflict (user_id, usage_date) do nothing;

  select count into v_count
  from public.kyra_usage
  where user_id = v_user_id
    and usage_date = (now() at time zone 'utc')::date
  for update;

  if v_count >= p_limit then
    return false;
  end if;

  update public.kyra_usage
  set count = count + 1
  where user_id = v_user_id
    and usage_date = (now() at time zone 'utc')::date;

  return true;
end;
$$;

revoke all on function public.increment_kyra_usage(int) from public;
revoke all on function public.increment_kyra_usage(int) from anon;
grant execute on function public.increment_kyra_usage(int) to authenticated;
