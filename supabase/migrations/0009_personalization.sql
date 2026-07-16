-- Deterministic personalization engine: curated verse taxonomy, tagging,
-- per-user impression/feedback history, and the recommend/feedback RPCs
-- that power the "Today" verse recommendation.
--
-- Conventions follow 0006/0007/0008: RLS enabled on every table, public
-- reference tables (focus_areas, curated_verses, curated_verse_tags) are
-- readable by `authenticated` only (explicitly revoked from anon, unlike
-- the fully-open bible_verses/passages tables per 0007's comment), and
-- user-owned tables (verse_impressions, verse_feedback) use
-- `to authenticated using (auth.uid() = user_id) with check
-- (auth.uid() = user_id)` policies with anon table privileges revoked.
--
-- `book` values in curated_verses must match the bible_verses/passages
-- convention: full English title-case book names, e.g. "Genesis",
-- "Psalms" (plural), "1 Corinthians", "Song of Solomon", "John" — see
-- BibleReaderView.swift's BibleBooks.all/chapterCounts (the definitive
-- list) and SupabaseService.swift's `.eq("book", value: book)` queries
-- against public.bible_verses, which join directly against this same
-- literal book text (0003_bible_verses.sql's passages rebuild joins
-- bv.book = p2.book with no translation table in between).

-- ============================================================
-- 1. Taxonomy
-- ============================================================
create table if not exists public.focus_areas (
  slug text primary key,
  label text not null,
  sort int not null default 0
);

insert into public.focus_areas (slug, label, sort) values
  ('anxiety', 'Anxiety', 1),
  ('purpose', 'Purpose', 2),
  ('relationships', 'Relationships', 3),
  ('financial_wisdom', 'Financial Wisdom', 4),
  ('forgiveness', 'Forgiveness', 5),
  ('grief', 'Grief', 6),
  ('discipline', 'Discipline', 7),
  ('loneliness', 'Loneliness', 8),
  ('marriage', 'Marriage', 9),
  ('parenting', 'Parenting', 10),
  ('temptation', 'Temptation', 11),
  ('career', 'Career', 12),
  ('confidence', 'Confidence', 13),
  ('understanding_god', 'Understanding God', 14),
  ('returning_to_faith', 'Returning to Faith', 15),
  ('learning_to_pray', 'Learning to Pray', 16),
  ('depression_hope', 'Depression & Hope', 17),
  ('motivation', 'Motivation', 18),
  ('addiction', 'Addiction', 19),
  ('anger', 'Anger', 20),
  ('leadership', 'Leadership', 21),
  ('new_to_christianity', 'New to Christianity', 22),
  ('understanding_the_bible', 'Understanding the Bible', 23),
  ('rest_peace', 'Rest & Peace', 24)
on conflict (slug) do update set label = excluded.label, sort = excluded.sort;

-- ============================================================
-- 2. Curated verses + tags
-- ============================================================
create table if not exists public.curated_verses (
  id uuid primary key default gen_random_uuid(),
  book text not null,
  chapter int not null,
  verse_start int not null,
  verse_end int not null default 0,
  theme_summary text,
  why_template text,
  created_at timestamptz default now()
);
-- verse_end = 0 means a single-verse reference (verse_start only).

create table if not exists public.curated_verse_tags (
  curated_verse_id uuid not null references public.curated_verses(id) on delete cascade,
  focus_slug text not null references public.focus_areas(slug) on delete cascade,
  emotion text check (emotion in (
    'peaceful','anxious','discouraged','motivated','angry','lonely',
    'confused','grateful','tempted','overwhelmed','hopeful','grieving'
  )),
  tone text check (tone in ('comfort','instruction','challenge')),
  maturity text check (maturity in ('beginner','growing','mature')),
  weight int not null default 10,
  primary key (curated_verse_id, focus_slug)
);
create index if not exists idx_curated_verse_tags_focus on public.curated_verse_tags (focus_slug);

-- ============================================================
-- 3. Per-user history
-- ============================================================
create table if not exists public.verse_impressions (
  user_id uuid not null references auth.users(id) on delete cascade,
  curated_verse_id uuid not null references public.curated_verses(id) on delete cascade,
  shown_on date not null default (now() at time zone 'utc')::date,
  primary key (user_id, curated_verse_id, shown_on)
);
create index if not exists idx_verse_impressions_user_date on public.verse_impressions (user_id, shown_on);

create table if not exists public.verse_feedback (
  user_id uuid not null references auth.users(id) on delete cascade,
  curated_verse_id uuid not null references public.curated_verses(id) on delete cascade,
  signal text not null,
  created_at timestamptz default now(),
  primary key (user_id, curated_verse_id, created_at)
);
create index if not exists idx_verse_feedback_user_verse on public.verse_feedback (user_id, curated_verse_id);

-- ============================================================
-- 4. RLS
-- ============================================================
alter table public.focus_areas enable row level security;
alter table public.curated_verses enable row level security;
alter table public.curated_verse_tags enable row level security;
alter table public.verse_impressions enable row level security;
alter table public.verse_feedback enable row level security;

-- Public reference tables: readable by authenticated only.
drop policy if exists "read focus areas" on public.focus_areas;
create policy "read focus areas" on public.focus_areas
  for select to authenticated using (true);

drop policy if exists "read curated verses" on public.curated_verses;
create policy "read curated verses" on public.curated_verses
  for select to authenticated using (true);

drop policy if exists "read curated verse tags" on public.curated_verse_tags;
create policy "read curated verse tags" on public.curated_verse_tags
  for select to authenticated using (true);

revoke all on table public.focus_areas from anon;
revoke all on table public.curated_verses from anon;
revoke all on table public.curated_verse_tags from anon;

-- Per-user tables.
drop policy if exists "own verse impressions" on public.verse_impressions;
create policy "own verse impressions" on public.verse_impressions
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own verse feedback" on public.verse_feedback;
create policy "own verse feedback" on public.verse_feedback
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

revoke all on table public.verse_impressions from anon;
revoke all on table public.verse_feedback from anon;

-- ============================================================
-- 5. RPCs
-- ============================================================

-- Returns today's (UTC) recommended verse for the current user, scored
-- against p_focus_slugs/p_mood/p_tone. Stable within a day: if a verse
-- was already shown to this user today, that same verse is returned again
-- (score 0) instead of re-scoring. p_maturity is accepted for API
-- symmetry/future filtering but does not factor into the score formula
-- below (not specified in the scoring contract).
create or replace function public.recommend_today_verse(
  p_focus_slugs text[],
  p_mood text,
  p_tone text,
  p_maturity text
)
returns table (
  curated_verse_id uuid,
  book text,
  chapter int,
  verse_start int,
  verse_end int,
  matched_focus text,
  why_template text,
  theme_summary text,
  score int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := (now() at time zone 'utc')::date;
  v_existing uuid;
  v_chosen uuid;
  v_score int;
begin
  if v_uid is null then
    return;
  end if;

  -- Already shown today: return the same verse (stable within the day).
  select vi.curated_verse_id into v_existing
  from public.verse_impressions vi
  where vi.user_id = v_uid
    and vi.shown_on = v_today
  limit 1;

  if v_existing is not null then
    return query
    select
      cv.id,
      cv.book,
      cv.chapter,
      cv.verse_start,
      cv.verse_end,
      coalesce(
        (select t.focus_slug from public.curated_verse_tags t
          where t.curated_verse_id = cv.id
            and t.focus_slug = any(p_focus_slugs)
          limit 1),
        (select t.focus_slug from public.curated_verse_tags t
          where t.curated_verse_id = cv.id
          limit 1)
      ) as matched_focus,
      cv.why_template,
      cv.theme_summary,
      0 as score
    from public.curated_verses cv
    where cv.id = v_existing;
    return;
  end if;

  -- Score every relevant candidate (relevance gate: at least one tag whose
  -- focus_slug is in p_focus_slugs; if p_focus_slugs is empty/null, every
  -- curated verse is a candidate).
  with candidates as (
    select cv.id
    from public.curated_verses cv
    where exists (
      select 1 from public.curated_verse_tags t
      where t.curated_verse_id = cv.id
        and (
          p_focus_slugs is null
          or array_length(p_focus_slugs, 1) is null
          or t.focus_slug = any(p_focus_slugs)
        )
    )
  ),
  scored as (
    select
      c.id,
      cv.created_at,
      coalesce(
        (select max(t.weight) from public.curated_verse_tags t where t.curated_verse_id = c.id),
        0
      )
      + 30 * (exists (
          select 1 from public.curated_verse_tags t
          where t.curated_verse_id = c.id and t.focus_slug = any(p_focus_slugs)
        ))::int
      + 25 * (exists (
          select 1 from public.curated_verse_tags t
          where t.curated_verse_id = c.id and t.emotion = p_mood
        ))::int
      + 20 * (exists (
          select 1 from public.curated_verse_tags t
          where t.curated_verse_id = c.id and t.tone = p_tone
        ))::int
      + 15 * (not exists (
          select 1 from public.verse_impressions vi
          where vi.user_id = v_uid
            and vi.curated_verse_id = c.id
            and vi.shown_on >= v_today - interval '30 days'
        ))::int
      - 20 * (exists (
          select 1 from public.verse_impressions vi
          where vi.user_id = v_uid
            and vi.curated_verse_id = c.id
            and vi.shown_on >= v_today - interval '30 days'
        ))::int
      - 30 * (exists (
          select 1 from public.verse_feedback vf
          where vf.user_id = v_uid
            and vf.curated_verse_id = c.id
            and vf.signal in ('not_today', 'less_like_this')
        ))::int
      as calc_score
    from candidates c
    join public.curated_verses cv on cv.id = c.id
  )
  select id, calc_score into v_chosen, v_score
  from scored
  order by calc_score desc, created_at asc, id asc
  limit 1;

  if v_chosen is null then
    return;
  end if;

  insert into public.verse_impressions (user_id, curated_verse_id, shown_on)
  values (v_uid, v_chosen, v_today)
  on conflict (user_id, curated_verse_id, shown_on) do nothing;

  return query
  select
    cv.id,
    cv.book,
    cv.chapter,
    cv.verse_start,
    cv.verse_end,
    coalesce(
      (select t.focus_slug from public.curated_verse_tags t
        where t.curated_verse_id = cv.id
          and t.focus_slug = any(p_focus_slugs)
        limit 1),
      (select t.focus_slug from public.curated_verse_tags t
        where t.curated_verse_id = cv.id
        limit 1)
    ) as matched_focus,
    cv.why_template,
    cv.theme_summary,
    v_score as score
  from public.curated_verses cv
  where cv.id = v_chosen;
end;
$$;

revoke all on function public.recommend_today_verse(text[], text, text, text) from public;
revoke all on function public.recommend_today_verse(text[], text, text, text) from anon;
grant execute on function public.recommend_today_verse(text[], text, text, text) to authenticated;

-- Records a feedback signal (e.g. 'not_today', 'less_like_this') from the
-- current user against a curated verse.
create or replace function public.record_verse_feedback(
  p_curated_verse_id uuid,
  p_signal text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.verse_feedback (user_id, curated_verse_id, signal)
  values (auth.uid(), p_curated_verse_id, p_signal);
end;
$$;

revoke all on function public.record_verse_feedback(uuid, text) from public;
revoke all on function public.record_verse_feedback(uuid, text) from anon;
grant execute on function public.record_verse_feedback(uuid, text) to authenticated;
