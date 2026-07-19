-- 0035_action_badges.sql
-- Formation badges: earned marks for streak milestones and action kinds.
-- Cooperative / personal only — never public competitive ranks.

create table if not exists public.user_badges (
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_id text not null,
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

alter table public.user_badges enable row level security;

drop policy if exists "own badges" on public.user_badges;
create policy "own badges" on public.user_badges
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

revoke all on table public.user_badges from anon;
grant select, insert on table public.user_badges to authenticated;

-- Award any newly earned badges from streak + completion history.
-- Returns jsonb array of newly awarded badge_id strings.
create or replace function public.award_earned_badges()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  streak_cur int := 0;
  streak_long int := 0;
  grace_n int := 0;
  path_done int := 0;
  kinds text[];
  week_kinds text[];
  newly text[] := '{}';
  candidate text;
  candidates text[] := array[
    'first_flame',
    'streak_3',
    'streak_7',
    'streak_14',
    'streak_30',
    'streak_100',
    'scripture_seed',
    'prayer_voice',
    'reflecting_heart',
    'community_presence',
    'encouraging_hand',
    'daily_word',
    'practice_step',
    'sabbath_rest',
    'gathered',
    'path_walker',
    'grace_held',
    'full_rhythm_week'
  ];
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  select coalesce(s.current, 0), coalesce(s.longest, 0), coalesce(s.grace_used, 0)
    into streak_cur, streak_long, grace_n
  from public.streaks s
  where s.user_id = uid;

  select coalesce(array_agg(distinct kind), '{}')
    into kinds
  from public.daily_completions
  where user_id = uid;

  select coalesce(array_agg(distinct kind), '{}')
    into week_kinds
  from public.daily_completions
  where user_id = uid
    and day >= (current_date - 6)::text;

  select count(*)::int into path_done
  from public.user_journey_enrollments
  where user_id = uid and completed_at is not null;

  foreach candidate in array candidates loop
    if exists (
      select 1 from public.user_badges b
      where b.user_id = uid and b.badge_id = candidate
    ) then
      continue;
    end if;

    if (candidate = 'first_flame' and greatest(streak_cur, streak_long) >= 1)
       or (candidate = 'streak_3' and greatest(streak_cur, streak_long) >= 3)
       or (candidate = 'streak_7' and greatest(streak_cur, streak_long) >= 7)
       or (candidate = 'streak_14' and greatest(streak_cur, streak_long) >= 14)
       or (candidate = 'streak_30' and greatest(streak_cur, streak_long) >= 30)
       or (candidate = 'streak_100' and greatest(streak_cur, streak_long) >= 100)
       or (candidate = 'scripture_seed' and 'scripture' = any(kinds))
       or (candidate = 'prayer_voice' and 'prayer' = any(kinds))
       or (candidate = 'reflecting_heart' and 'reflection' = any(kinds))
       or (candidate = 'community_presence' and 'community' = any(kinds))
       or (candidate = 'encouraging_hand' and 'encouragement' = any(kinds))
       or (candidate = 'daily_word' and 'devotional' = any(kinds))
       or (candidate = 'practice_step' and 'action' = any(kinds))
       or (candidate = 'sabbath_rest' and 'rest' = any(kinds))
       or (candidate = 'gathered' and 'church' = any(kinds))
       or (candidate = 'path_walker' and path_done > 0)
       or (candidate = 'grace_held' and grace_n > 0)
       or (
         candidate = 'full_rhythm_week'
         and week_kinds @> array[
           'scripture','prayer','reflection','community','encouragement','devotional'
         ]::text[]
       )
    then
      insert into public.user_badges (user_id, badge_id)
      values (uid, candidate)
      on conflict do nothing;
      newly := array_append(newly, candidate);
    end if;
  end loop;

  return to_jsonb(newly);
end;
$$;

revoke all on function public.award_earned_badges() from public;
grant execute on function public.award_earned_badges() to authenticated;
