-- 0017_devotional_reroll_and_ai.sql — G19 Tier 2 (deterministic re-roll) +
-- Tier 3 (AI-suggestion usage cap). See GAP_ANALYSIS_AND_ROADMAP.md §9.

-- Tier 2a: another built-in devotional, deterministic, excluding ids already
-- seen this session. Falls back to the same rotation when the exclude list
-- covers everything (returns nothing → UI keeps current).
create or replace function public.next_devotional(p_exclude uuid[] default '{}')
returns setof public.devotionals
language sql stable security definer set search_path = public
as $$
  select d.* from public.devotionals d
  where d.is_published
    and not (d.id = any(coalesce(p_exclude, '{}'::uuid[])))
  order by md5(d.id::text || current_date::text)
  limit 1;
$$;
grant execute on function public.next_devotional(uuid[]) to authenticated;

-- Tier 2b: prepare a daily-verse re-roll WITHOUT duplicating the scoring
-- engine. Penalizes today's shown verse (records 'not_today', worth -30 in
-- recommend_today_verse) and clears today's impression so the day-stability
-- short-circuit no longer returns the same verse. The app then simply calls
-- recommend_today_verse again, which now returns the next-best candidate.
create or replace function public.reroll_prepare_today_verse()
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  r record;
begin
  if v_uid is null then return; end if;
  for r in
    select book, chapter, verse from public.verse_impressions
    where user_id = v_uid and shown_on = v_today
  loop
    perform public.record_verse_feedback(r.book, r.chapter, r.verse, 'not_today');
  end loop;
  delete from public.verse_impressions
  where user_id = v_uid and shown_on = v_today;
end;
$$;
grant execute on function public.reroll_prepare_today_verse() to authenticated;

-- Tier 3: per-user daily cap for AI devotional suggestions (mirrors 0008's
-- kyra_usage). Protects OpenAI spend; the AI layer only fires on an explicit
-- user tap and only while under this cap.
create table if not exists public.devotional_ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null default (now() at time zone 'utc')::date,
  count int not null default 0,
  primary key (user_id, usage_date)
);
alter table public.devotional_ai_usage enable row level security;
drop policy if exists "read own devotional ai usage" on public.devotional_ai_usage;
create policy "read own devotional ai usage" on public.devotional_ai_usage
  for select using (auth.uid() = user_id);

-- Atomically checks + increments today's AI-suggestion count. Returns true
-- (and increments) while under p_limit; false (untouched) once at/over it.
create or replace function public.increment_devotional_ai_usage(p_limit int)
returns boolean
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_count int;
begin
  if v_uid is null then return false; end if;
  insert into public.devotional_ai_usage (user_id, usage_date, count)
  values (v_uid, (now() at time zone 'utc')::date, 0)
  on conflict (user_id, usage_date) do nothing;
  select count into v_count from public.devotional_ai_usage
  where user_id = v_uid and usage_date = (now() at time zone 'utc')::date
  for update;
  if v_count >= p_limit then return false; end if;
  update public.devotional_ai_usage set count = count + 1
  where user_id = v_uid and usage_date = (now() at time zone 'utc')::date;
  return true;
end;
$$;
revoke all on function public.increment_devotional_ai_usage(int) from public;
revoke all on function public.increment_devotional_ai_usage(int) from anon;
grant execute on function public.increment_devotional_ai_usage(int) to authenticated;
