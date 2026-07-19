-- Frontier Journey / Progress (Phase A–D)
-- Grace engine that actually applies, path enrollments, rest/church rhythm,
-- working-item focus tags, and two more seeded paths.

-- ============================================================
-- 1. daily_completions: rest + church
-- ============================================================
alter table public.daily_completions
  drop constraint if exists daily_completions_kind_check;
alter table public.daily_completions
  add constraint daily_completions_kind_check
  check (kind in (
    'scripture','prayer','reflection','community',
    'encouragement','devotional','action','rest','church'
  ));

-- ============================================================
-- 2. Streaks: month bucket for grace reset + grace log
-- ============================================================
alter table public.streaks
  add column if not exists grace_month text;

create table if not exists public.streak_grace_log (
  user_id    uuid not null references auth.users(id) on delete cascade,
  day        date not null,
  source     text not null check (source in ('auto','manual')),
  created_at timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.streak_grace_log enable row level security;
drop policy if exists "own grace log" on public.streak_grace_log;
create policy "own grace log" on public.streak_grace_log
  for select using (auth.uid() = user_id);

revoke all on table public.streak_grace_log from anon;
grant select on table public.streak_grace_log to authenticated;

-- ============================================================
-- 3. Working items: optional focus slug for Today personalization
-- ============================================================
alter table public.working_items
  add column if not exists focus_slug text;

-- ============================================================
-- 4. Path enrollments + day completions
-- ============================================================
create table if not exists public.user_journey_enrollments (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users(id) on delete cascade,
  journey_id         uuid not null references public.journeys(id) on delete cascade,
  started_at         timestamptz not null default now(),
  current_day        int not null default 1 check (current_day between 1 and 31),
  completed_at       timestamptz,
  companion_name     text,
  companion_user_id  uuid references auth.users(id) on delete set null,
  bridge_token       text,
  unique (user_id, journey_id)
);

create table if not exists public.user_journey_day_completions (
  enrollment_id uuid not null references public.user_journey_enrollments(id) on delete cascade,
  day           int not null check (day between 1 and 31),
  completed_at  timestamptz not null default now(),
  primary key (enrollment_id, day)
);

alter table public.user_journey_enrollments enable row level security;
alter table public.user_journey_day_completions enable row level security;

drop policy if exists "own enrollments" on public.user_journey_enrollments;
create policy "own enrollments" on public.user_journey_enrollments
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own journey day completions" on public.user_journey_day_completions;
create policy "own journey day completions" on public.user_journey_day_completions
  for all using (
    exists (
      select 1 from public.user_journey_enrollments e
      where e.id = enrollment_id and e.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.user_journey_enrollments e
      where e.id = enrollment_id and e.user_id = auth.uid()
    )
  );

-- Companions can read a peer's enrollment progress (cooperative, not ranked).
drop policy if exists "companion read enrollments" on public.user_journey_enrollments;
create policy "companion read enrollments" on public.user_journey_enrollments
  for select using (auth.uid() = companion_user_id);

revoke all on table public.user_journey_enrollments from anon;
revoke all on table public.user_journey_day_completions from anon;
grant select, insert, update, delete on table public.user_journey_enrollments to authenticated;
grant select, insert, update, delete on table public.user_journey_day_completions to authenticated;

-- ============================================================
-- 5. Grace RPCs
-- ============================================================

create or replace function public.apply_grace_if_needed()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v public.streaks%rowtype;
  today date := (timezone('utc', now()))::date;
  yesterday date := today - 1;
  month_key text := to_char(today, 'YYYY-MM');
  applied boolean := false;
begin
  if uid is null then
    return json_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  select * into v from public.streaks where user_id = uid;
  if v.user_id is null then
    return json_build_object(
      'ok', true, 'applied', false,
      'grace_used', 0, 'grace_total', 3, 'current', 0,
      'grace_held_day', null
    );
  end if;

  -- Monthly grace reset
  if v.grace_month is distinct from month_key then
    update public.streaks
       set grace_used = 0, grace_month = month_key, updated_at = now()
     where user_id = uid;
    v.grace_used := 0;
    v.grace_month := month_key;
  end if;

  -- No gap (active yesterday or today) — nothing to heal
  if v.last_active is null or v.last_active >= yesterday then
    return json_build_object(
      'ok', true, 'applied', false,
      'grace_used', v.grace_used, 'grace_total', v.grace_total,
      'current', v.current,
      'grace_held_day', (
        select day::text from public.streak_grace_log
         where user_id = uid and day = yesterday
         limit 1
      )
    );
  end if;

  -- Already logged grace for yesterday (idempotent).
  if exists (select 1 from public.streak_grace_log where user_id = uid and day = yesterday) then
    update public.streaks
       set last_active = greatest(coalesce(last_active, yesterday), yesterday),
           updated_at = now()
     where user_id = uid;
    select * into v from public.streaks where user_id = uid;
    return json_build_object(
      'ok', true, 'applied', false,
      'grace_used', v.grace_used, 'grace_total', v.grace_total,
      'current', v.current, 'grace_held_day', yesterday::text
    );
  end if;

  -- Gap: last_active is before yesterday. Spend one grace to cover yesterday.
  if v.grace_used >= v.grace_total then
    return json_build_object(
      'ok', true, 'applied', false, 'reason', 'no_grace_left',
      'grace_used', v.grace_used, 'grace_total', v.grace_total,
      'current', v.current, 'grace_held_day', null
    );
  end if;

  insert into public.streak_grace_log (user_id, day, source)
  values (uid, yesterday, 'auto');

  update public.streaks
     set grace_used = grace_used + 1,
         grace_month = month_key,
         last_active = yesterday,
         updated_at = now()
   where user_id = uid;

  select * into v from public.streaks where user_id = uid;
  applied := true;

  return json_build_object(
    'ok', true,
    'applied', applied,
    'grace_used', v.grace_used,
    'grace_total', v.grace_total,
    'current', v.current,
    'grace_held_day', yesterday::text
  );
end;
$$;

revoke all on function public.apply_grace_if_needed() from public;
grant execute on function public.apply_grace_if_needed() to authenticated;

-- Explicit "I'm taking a grace day today" — preserves streak without activity.
create or replace function public.use_grace_day()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v public.streaks%rowtype;
  today date := (timezone('utc', now()))::date;
  month_key text := to_char(today, 'YYYY-MM');
begin
  if uid is null then
    return json_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  insert into public.streaks (user_id, current, longest, grace_used, grace_total, grace_month, last_active)
  values (uid, 0, 0, 0, 3, month_key, null)
  on conflict (user_id) do nothing;

  select * into v from public.streaks where user_id = uid;

  if v.grace_month is distinct from month_key then
    update public.streaks
       set grace_used = 0, grace_month = month_key, updated_at = now()
     where user_id = uid;
    v.grace_used := 0;
  end if;

  if exists (select 1 from public.streak_grace_log where user_id = uid and day = today) then
    return json_build_object(
      'ok', true, 'applied', false, 'reason', 'already_used_today',
      'grace_used', v.grace_used, 'grace_total', v.grace_total, 'current', v.current
    );
  end if;

  if v.grace_used >= v.grace_total then
    return json_build_object(
      'ok', false, 'reason', 'no_grace_left',
      'grace_used', v.grace_used, 'grace_total', v.grace_total, 'current', v.current
    );
  end if;

  insert into public.streak_grace_log (user_id, day, source) values (uid, today, 'manual');

  update public.streaks
     set grace_used = grace_used + 1,
         grace_month = month_key,
         last_active = today,
         updated_at = now()
   where user_id = uid;

  insert into public.daily_completions (user_id, day, kind)
  values (uid, today, 'rest')
  on conflict do nothing;

  select * into v from public.streaks where user_id = uid;

  return json_build_object(
    'ok', true, 'applied', true,
    'grace_used', v.grace_used, 'grace_total', v.grace_total,
    'current', v.current, 'grace_held_day', today::text
  );
end;
$$;

revoke all on function public.use_grace_day() from public;
grant execute on function public.use_grace_day() to authenticated;

-- Week trail: completions + grace marks for the last 7 days (Mon-start week optional; client maps).
create or replace function public.week_trail_marks()
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  start_day date := (timezone('utc', now()))::date - 6;
begin
  if uid is null then
    return '[]'::json;
  end if;

  return (
    select coalesce(json_agg(json_build_object(
      'day', d::text,
      'kind', kind
    ) order by d), '[]'::json)
    from (
      select c.day as d, 'completed'::text as kind
        from public.daily_completions c
       where c.user_id = uid and c.day >= start_day
         and c.kind not in ('rest')
       group by c.day
      union
      select c.day, 'rest'
        from public.daily_completions c
       where c.user_id = uid and c.day >= start_day and c.kind = 'rest'
      union
      select g.day, 'grace'
        from public.streak_grace_log g
       where g.user_id = uid and g.day >= start_day
    ) x
  );
end;
$$;

revoke all on function public.week_trail_marks() from public;
grant execute on function public.week_trail_marks() to authenticated;

-- ============================================================
-- 6. Path helpers
-- ============================================================

create or replace function public.enroll_journey(p_slug text, p_companion_name text default null)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  jid uuid;
  eid uuid;
  total int;
begin
  if uid is null then raise exception 'not signed in'; end if;

  select id into jid from public.journeys where slug = p_slug;
  if jid is null then raise exception 'unknown journey'; end if;

  insert into public.user_journey_enrollments (user_id, journey_id, companion_name)
  values (uid, jid, nullif(trim(p_companion_name), ''))
  on conflict (user_id, journey_id) do update
    set companion_name = coalesce(excluded.companion_name, user_journey_enrollments.companion_name),
        completed_at = null
  returning id into eid;

  select count(*)::int into total from public.journey_days where journey_id = jid;

  return json_build_object(
    'enrollment_id', eid,
    'journey_id', jid,
    'slug', p_slug,
    'current_day', 1,
    'total_days', total
  );
end;
$$;

revoke all on function public.enroll_journey(text, text) from public;
grant execute on function public.enroll_journey(text, text) to authenticated;

create or replace function public.complete_journey_day(p_enrollment_id uuid, p_day int)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  e public.user_journey_enrollments%rowtype;
  total int;
  next_day int;
begin
  if uid is null then raise exception 'not signed in'; end if;

  select * into e from public.user_journey_enrollments
   where id = p_enrollment_id and user_id = uid;
  if e.id is null then raise exception 'not found'; end if;

  select count(*)::int into total from public.journey_days where journey_id = e.journey_id;
  if p_day < 1 or p_day > total then raise exception 'invalid day'; end if;

  insert into public.user_journey_day_completions (enrollment_id, day)
  values (p_enrollment_id, p_day)
  on conflict do nothing;

  next_day := least(p_day + 1, total);
  update public.user_journey_enrollments
     set current_day = greatest(current_day, next_day),
         completed_at = case when p_day >= total then now() else completed_at end
   where id = p_enrollment_id;

  insert into public.daily_completions (user_id, day, kind)
  values (uid, (timezone('utc', now()))::date, 'devotional')
  on conflict do nothing;

  select * into e from public.user_journey_enrollments where id = p_enrollment_id;

  return json_build_object(
    'enrollment_id', e.id,
    'current_day', e.current_day,
    'completed', e.completed_at is not null,
    'total_days', total
  );
end;
$$;

revoke all on function public.complete_journey_day(uuid, int) from public;
grant execute on function public.complete_journey_day(uuid, int) to authenticated;

-- Attach a bridge token + companion name to an enrollment (Walk with someone).
create or replace function public.link_journey_companion(
  p_enrollment_id uuid,
  p_companion_name text,
  p_bridge_token text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  update public.user_journey_enrollments
     set companion_name = nullif(trim(p_companion_name), ''),
         bridge_token = nullif(trim(p_bridge_token), '')
   where id = p_enrollment_id and user_id = uid;
end;
$$;

revoke all on function public.link_journey_companion(uuid, text, text) from public;
grant execute on function public.link_journey_companion(uuid, text, text) to authenticated;

-- ============================================================
-- 7. Seed paths: Finding Peace + Returning to Faith
-- ============================================================
insert into public.journeys (slug, title, subtitle)
select 'finding-peace', 'Finding Peace',
       'Seven short readings for a restless mind. Sit with one each day — no rush.'
where not exists (select 1 from public.journeys where slug = 'finding-peace');

insert into public.journeys (slug, title, subtitle)
select 'returning-to-faith', 'Returning to Faith',
       'For anyone coming back — or wondering if they still can. Gentle, honest, day by day.'
where not exists (select 1 from public.journeys where slug = 'returning-to-faith');

with j as (select id from public.journeys where slug = 'finding-peace')
insert into public.journey_days (journey_id, day, title, book, chapter, verse_start, verse_end, body)
select j.id, v.day, v.title, v.book, v.chapter, v.verse_start, v.verse_end, v.body
from j, (values
  (1, 'Be still', 'Psalms', 46, 10, null,
   'Peace rarely starts with answers. It starts with stopping long enough to remember you are not the one holding everything up. Today, take two quiet minutes. No petition list. Just the words: be still.'),
  (2, 'Cast it', '1 Peter', 5, 7, null,
   'Anxiety loves to stay unnamed. This verse is permission to hand one specific worry to God — out loud if you can. Not every worry. One. Name it, cast it, and notice what remains.'),
  (3, 'Guarded', 'Philippians', 4, 6, 7,
   'Paul writes about peace from a cell. The practice is simple and hard: thanksgiving alongside the ask. Try it once today with a real anxiety. Watch for steadiness, not fireworks.'),
  (4, 'Not troubled', 'John', 14, 27, null,
   'Jesus distinguishes His peace from the world''s version — which usually means distraction or control. His offer is presence. Sit with the idea that peace can arrive without circumstances changing.'),
  (5, 'Tomorrow''s trouble', 'Matthew', 6, 34, null,
   'Most fear lives in a day that hasn''t started. Grace, like manna, is portioned daily. Ask only for today''s strength. Leave tomorrow''s door closed until morning.'),
  (6, 'Kept in perfect peace', 'Isaiah', 26, 3, null,
   'Steadiness grows where attention stays. Not perfect focus — returned focus. When your mind wanders to the spiral, gently return it to the One who keeps you.'),
  (7, 'The Lord is near', 'Psalms', 34, 18, null,
   'Peace is not the absence of ache. Sometimes it is knowing you are accompanied inside it. End the week here: you are not alone in what still hurts.')
) as v(day, title, book, chapter, verse_start, verse_end, body)
where not exists (
  select 1 from public.journey_days d where d.journey_id = j.id and d.day = v.day
);

with j as (select id from public.journeys where slug = 'returning-to-faith')
insert into public.journey_days (journey_id, day, title, book, chapter, verse_start, verse_end, body)
select j.id, v.day, v.title, v.book, v.chapter, v.verse_start, v.verse_end, v.body
from j, (values
  (1, 'The door is open', 'Luke', 15, 20, null,
   'The father runs before the speech is finished. If you have been away — angry, ashamed, unsure — start here: the story assumes return is possible. You do not have to have the apology polished.'),
  (2, 'Come as you are', 'Matthew', 11, 28, null,
   'Jesus invites the weary, not the impressive. Returning is not re-earning a seat. It is accepting rest you stopped believing you deserved.'),
  (3, 'Nothing can separate', 'Romans', 8, 38, 39,
   'Paul stacks every threat he can name and says none of them cancel belonging. Your absence did not exile you from love. Sit with that without arguing it away today.'),
  (4, 'A new heart', 'Ezekiel', 36, 26, null,
   'Return is not white-knuckle willpower. It is God''s work in the deep places — softness where cynicism grew. Ask for that quietly. You do not need to feel it yet.'),
  (5, 'Abide', 'John', 15, 4, null,
   'Faith after distance often tries to sprint. Jesus says remain. One honest prayer. One verse. One Sunday in the back row. Remaining is enough for today.'),
  (6, 'Confessed and clean', '1 John', 1, 9, null,
   'Shame says hide. This verse says bring it into the light and find faithfulness waiting. If something needs naming, name it to God. He already knows; you need the relief of saying it.'),
  (7, 'Home', 'Psalms', 23, 6, null,
   'Goodness and mercy follow — even down roads that felt like leaving. End here: you can be found. You can belong again. Take the next small step without drama.')
) as v(day, title, book, chapter, verse_start, verse_end, body)
where not exists (
  select 1 from public.journey_days d where d.journey_id = j.id and d.day = v.day
);
