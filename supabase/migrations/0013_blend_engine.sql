-- 0013_blend_engine.sql
-- Blends 0009's curated-only recommendation engine with 0012's generalized
-- verse_tags (curated + AI, once tagged) and semantic (pgvector) signal.
--
-- CANDIDATE-SET EQUIVALENCE CHECK (verifying the reasoning requested for
-- this migration): 0012's backfill step inserted exactly one verse_tags row
-- per existing curated_verse_tags row (same focus_slug/emotion/tone/
-- maturity), with source='curated', confidence=1.0, review_status=
-- 'approved', unconditionally. As of this migration, scripts/tag_bible.py
-- has not necessarily been run yet, so verse_tags may contain ONLY those
-- curated-derived rows and nothing with source='ai'. In that state, "verse_
-- tags where review_status='approved' and focus_slug = any(p_focus_slugs)"
-- selects exactly the same (book,chapter,verse) identities that 0009's
-- "curated_verse_tags where focus_slug = any(p_focus_slugs)" selected
-- (every curated_verse_tags row maps 1:1 to an approved verse_tags row with
-- the same focus_slug). So the candidate set — and therefore the chosen
-- verse for any given user/day — is unchanged until AI tags are approved
-- into verse_tags, at which point the candidate set (and scoring) widens
-- automatically. This is a static proof from the 0010/0012 migration SQL,
-- not a live-DB check (this session does not apply/deploy migrations).
--
-- SCHEMA TENSION FLAGGED + NOW RESOLVED (both sides): the Swift app used to
-- decode recommend_today_verse's curated_verse_id as a NON-OPTIONAL UUID
-- (SupabaseService.swift's `RecommendTodayVerseRow.curated_verse_id: UUID`),
-- while this migration's contract allows curated_verse_id to be NULL for a
-- verse that only has AI-approved tags (no matching curated_verses row).
-- That would have made JSONDecoder throw on such a row; AppState's `try?`
-- around the call swallows the error, so the app would not crash — it
-- would just silently skip that day's recommendation, defeating the point
-- of scoring beyond the 135 curated verses. This pass fixes it on both
-- sides: `RecommendedVerse`/`RecommendTodayVerseRow` in
-- SupabaseService.swift now decode curated_verse_id as optional, and
-- verse_impressions/verse_feedback (below) were already moved off
-- curated_verse_id as their keying identity onto (book,chapter,verse) —
-- ADDITIVELY (backfilled from existing curated_verse_id rows, then NOT
-- NULL), with each primary key rebuilt around that identity and
-- curated_verse_id relaxed to nullable with ON DELETE SET NULL (was
-- CASCADE) so historical impressions/feedback survive even if a
-- curated_verses row is later removed. record_verse_feedback's
-- Swift-facing signature is ALSO changed in this migration (see section 6
-- below) from (p_curated_verse_id uuid, p_signal text) to (p_book text,
-- p_chapter int, p_verse int, p_signal text) — feedback identity is the
-- verse reference itself, so it works for AI-tagged verses that have no
-- curated_verses row at all, matching how recommend_today_verse's -30
-- feedback term already reads verse_feedback by (book,chapter,verse).

-- ============================================================
-- 1. focus_embeddings — one embedding per focus area, for the guarded
--    semantic re-ranking term below. RLS enabled, no select policy for
--    anon OR authenticated (mirrors 0012's verse_embeddings pattern):
--    only the security-definer recommend_today_verse RPC reads it.
-- ============================================================
create table if not exists public.focus_embeddings (
  focus_slug text primary key references public.focus_areas(slug) on delete cascade,
  embedding vector(1536)
);

alter table public.focus_embeddings enable row level security;

-- No select policy for anon or authenticated — same posture as
-- verse_embeddings (0012 section 5): raw embeddings are only ever exposed
-- indirectly, via the guarded arithmetic inside recommend_today_verse.
revoke all on table public.focus_embeddings from anon;
revoke all on table public.focus_embeddings from authenticated;

-- ============================================================
-- 2. verse_impressions — add a (book,chapter,verse) identity so day-
--    stability and 30-day recency scoring work for ANY scored verse, not
--    just ones with a curated_verses row. Backfill from the existing
--    curated_verse_id (every pre-existing row has one), then make the new
--    columns NOT NULL and rebuild the primary key around them.
-- ============================================================
alter table public.verse_impressions add column if not exists book text;
alter table public.verse_impressions add column if not exists chapter int;
alter table public.verse_impressions add column if not exists verse int;

update public.verse_impressions vi
set book = cv.book, chapter = cv.chapter, verse = cv.verse_start
from public.curated_verses cv
where cv.id = vi.curated_verse_id
  and vi.book is null;

alter table public.verse_impressions alter column book set not null;
alter table public.verse_impressions alter column chapter set not null;
alter table public.verse_impressions alter column verse set not null;

-- Drop the old curated_verse_id-based primary key so curated_verse_id can
-- become nullable (a PK column can never be null).
alter table public.verse_impressions drop constraint if exists verse_impressions_pkey;
alter table public.verse_impressions alter column curated_verse_id drop not null;

-- Re-point the FK to SET NULL on delete (was CASCADE) so a removed curated
-- verse doesn't erase impression history that's now identified by
-- (book,chapter,verse) regardless of curated status.
alter table public.verse_impressions
  drop constraint if exists verse_impressions_curated_verse_id_fkey;
alter table public.verse_impressions
  add constraint verse_impressions_curated_verse_id_fkey
  foreign key (curated_verse_id) references public.curated_verses(id) on delete set null;

alter table public.verse_impressions
  add primary key (user_id, book, chapter, verse, shown_on);
-- idx_verse_impressions_user_date (user_id, shown_on) from 0009 still
-- serves the "already shown today" lookup unchanged.

-- ============================================================
-- 3. verse_feedback — same treatment as verse_impressions, so the -30
--    feedback-signal scoring term below can match by verse identity.
-- ============================================================
alter table public.verse_feedback add column if not exists book text;
alter table public.verse_feedback add column if not exists chapter int;
alter table public.verse_feedback add column if not exists verse int;

update public.verse_feedback vf
set book = cv.book, chapter = cv.chapter, verse = cv.verse_start
from public.curated_verses cv
where cv.id = vf.curated_verse_id
  and vf.book is null;

alter table public.verse_feedback alter column book set not null;
alter table public.verse_feedback alter column chapter set not null;
alter table public.verse_feedback alter column verse set not null;

alter table public.verse_feedback drop constraint if exists verse_feedback_pkey;
alter table public.verse_feedback alter column curated_verse_id drop not null;

alter table public.verse_feedback
  drop constraint if exists verse_feedback_curated_verse_id_fkey;
alter table public.verse_feedback
  add constraint verse_feedback_curated_verse_id_fkey
  foreign key (curated_verse_id) references public.curated_verses(id) on delete set null;

alter table public.verse_feedback
  add primary key (user_id, book, chapter, verse, created_at);
-- idx_verse_feedback_user_verse (user_id, curated_verse_id) from 0009 is
-- still valid/harmless; the new PK's leading columns (user_id, book,
-- chapter, verse) cover the by-verse-identity lookups used below.

-- ============================================================
-- 4. Internal helper: given a chosen (book,chapter,verse) + score, resolve
--    the full recommend_today_verse row shape. Shared by both the
--    "already shown today" branch and the freshly-scored branch below so
--    the curated-match / matched_focus / why_template / theme_summary
--    logic exists in exactly one place. Not part of the Swift-facing API
--    surface (Swift only ever calls recommend_today_verse itself).
--
--    why_template's default keeps the SAME literal "{focus}" placeholder
--    convention as curated_verses.why_template (see 0010's seed rows) --
--    SupabaseService.swift substitutes it client-side via
--    `row.why_template.replacingOccurrences(of: "{focus}", with:
--    FocusAreaSlugMap.label(forSlug: row.matched_focus))`, so the SQL
--    default must NOT pre-resolve the label or that substitution becomes a
--    no-op. theme_summary has no such client-side substitution, so its
--    default is fully resolved here using focus_areas.label directly.
-- ============================================================
create or replace function public._verse_recommendation_row(
  p_book text,
  p_chapter int,
  p_verse int,
  p_focus_slugs text[],
  p_score int
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
language sql
stable
set search_path = public
as $$
  select
    cvm.id as curated_verse_id,
    p_book as book,
    p_chapter as chapter,
    p_verse as verse_start,
    coalesce(cvm.verse_end, 0) as verse_end,
    tagm.focus_slug as matched_focus,
    coalesce(cvm.why_template, 'for when you''re carrying {focus}') as why_template,
    coalesce(
      cvm.theme_summary,
      nullif(trim(both ': ' from concat_ws(': ', fa.label, tagm.theme)), ''),
      'a verse for today'
    ) as theme_summary,
    p_score as score
  from (select 1) as _one
  left join lateral (
    select cv.id, cv.verse_end, cv.why_template, cv.theme_summary
    from public.curated_verses cv
    where cv.book = p_book and cv.chapter = p_chapter and cv.verse_start = p_verse
    limit 1
  ) cvm on true
  left join lateral (
    select vt.focus_slug, vt.theme
    from public.verse_tags vt
    where vt.book = p_book and vt.chapter = p_chapter and vt.verse = p_verse
      and vt.review_status = 'approved'
    order by (vt.focus_slug = any(p_focus_slugs)) desc, vt.confidence desc nulls last, vt.created_at asc
    limit 1
  ) tagm on true
  left join public.focus_areas fa on fa.slug = tagm.focus_slug;
$$;

revoke all on function public._verse_recommendation_row(text, int, int, text[], int) from public;
revoke all on function public._verse_recommendation_row(text, int, int, text[], int) from anon;
grant execute on function public._verse_recommendation_row(text, int, int, text[], int) to authenticated;

-- ============================================================
-- 5. recommend_today_verse — SAME SIGNATURE AND RETURN SHAPE as 0009 (the
--    Swift app depends on this exactly: SupabaseService.swift's
--    RecommendTodayVerseRow decodes curated_verse_id/book/chapter/
--    verse_start/verse_end/matched_focus/why_template/theme_summary/score
--    in that order). Internals now score public.verse_tags (curated + any
--    approved AI tags) plus a guarded semantic term instead of scoring
--    curated_verse_tags directly.
-- ============================================================
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
  v_book text;
  v_chapter int;
  v_verse int;
  v_score int;
  v_cvid uuid;
begin
  if v_uid is null then
    return;
  end if;

  -- Already shown today: return the SAME verse (stable within the day),
  -- resolved by (book,chapter,verse) identity rather than curated_verse_id
  -- so this still works even for a verse with no curated_verses match.
  select vi.book, vi.chapter, vi.verse into v_book, v_chapter, v_verse
  from public.verse_impressions vi
  where vi.user_id = v_uid
    and vi.shown_on = v_today
  limit 1;

  if v_book is not null then
    return query
    select * from public._verse_recommendation_row(v_book, v_chapter, v_verse, p_focus_slugs, 0);
    return;
  end if;

  -- Score every candidate verse: one whose approved verse_tags include a
  -- focus_slug in p_focus_slugs (or, if p_focus_slugs is empty/null, every
  -- verse with at least one approved tag at all -- same relevance-gate
  -- convention as 0009). verse_tags now holds BOTH curated (source=
  -- 'curated') and approved AI tags (source='ai'), so this widens
  -- automatically as the AI pipeline lands rows, with no other change
  -- needed here.
  with candidates as (
    select distinct vt.book, vt.chapter, vt.verse
    from public.verse_tags vt
    where vt.review_status = 'approved'
      and (
        p_focus_slugs is null
        or array_length(p_focus_slugs, 1) is null
        or vt.focus_slug = any(p_focus_slugs)
      )
  ),
  scored as (
    select
      c.book,
      c.chapter,
      c.verse,
      (
        select min(vt.created_at) from public.verse_tags vt
        where vt.book = c.book and vt.chapter = c.chapter and vt.verse = c.verse
          and vt.review_status = 'approved'
      ) as first_tagged_at,
      -- base: verse_tags carries no per-tag weight (unlike 0009's
      -- curated_verse_tags.weight), so every approved-tagged candidate
      -- starts from the same flat base.
      10
      + 30 * (exists (
          select 1 from public.verse_tags vt
          where vt.book = c.book and vt.chapter = c.chapter and vt.verse = c.verse
            and vt.review_status = 'approved'
            and (
              p_focus_slugs is null
              or array_length(p_focus_slugs, 1) is null
              or vt.focus_slug = any(p_focus_slugs)
            )
        ))::int
      + 25 * (exists (
          select 1 from public.verse_tags vt
          where vt.book = c.book and vt.chapter = c.chapter and vt.verse = c.verse
            and vt.review_status = 'approved' and vt.emotion = p_mood
        ))::int
      + 20 * (exists (
          select 1 from public.verse_tags vt
          where vt.book = c.book and vt.chapter = c.chapter and vt.verse = c.verse
            and vt.review_status = 'approved' and vt.tone = p_tone
        ))::int
      + 15 * (not exists (
          select 1 from public.verse_impressions vi
          where vi.user_id = v_uid
            and vi.book = c.book and vi.chapter = c.chapter and vi.verse = c.verse
            and vi.shown_on >= v_today - interval '30 days'
        ))::int
      - 20 * (exists (
          select 1 from public.verse_impressions vi
          where vi.user_id = v_uid
            and vi.book = c.book and vi.chapter = c.chapter and vi.verse = c.verse
            and vi.shown_on >= v_today - interval '30 days'
        ))::int
      - 30 * (exists (
          select 1 from public.verse_feedback vf
          where vf.user_id = v_uid
            and vf.book = c.book and vf.chapter = c.chapter and vf.verse = c.verse
            and vf.signal in ('not_today', 'less_like_this')
        ))::int
      -- curated boost: curated tags stay authoritative even after AI tags
      -- start flowing in alongside them.
      + 15 * (exists (
          select 1 from public.verse_tags vt
          where vt.book = c.book and vt.chapter = c.chapter and vt.verse = c.verse
            and vt.review_status = 'approved' and vt.source = 'curated'
        ))::int
      -- guarded semantic term: 0 whenever focus_embeddings has no rows for
      -- p_focus_slugs, or this verse has no verse_embeddings row -- the
      -- correlated subquery below returns NULL in either case and coalesce
      -- floors it to 0, so missing embeddings never break scoring or
      -- exclude a candidate (candidates are still gated purely by having
      -- an approved matching tag, per the "don't surface untagged verses"
      -- requirement).
      + coalesce((
          select round((25 * greatest(0, max(1 - (ve.embedding <=> fe.embedding))))::numeric)::int
          from public.verse_embeddings ve, public.focus_embeddings fe
          where ve.book = c.book and ve.chapter = c.chapter and ve.verse = c.verse
            and fe.focus_slug = any(p_focus_slugs)
        ), 0) as calc_score
    from candidates c
  )
  select book, chapter, verse, calc_score into v_book, v_chapter, v_verse, v_score
  from scored
  order by calc_score desc, first_tagged_at asc nulls last, book asc, chapter asc, verse asc
  limit 1;

  if v_book is null then
    return;
  end if;

  select cv.id into v_cvid
  from public.curated_verses cv
  where cv.book = v_book and cv.chapter = v_chapter and cv.verse_start = v_verse
  limit 1;

  insert into public.verse_impressions (user_id, curated_verse_id, book, chapter, verse, shown_on)
  values (v_uid, v_cvid, v_book, v_chapter, v_verse, v_today)
  on conflict (user_id, book, chapter, verse, shown_on) do nothing;

  return query
  select * from public._verse_recommendation_row(v_book, v_chapter, v_verse, p_focus_slugs, v_score);
end;
$$;

revoke all on function public.recommend_today_verse(text[], text, text, text) from public;
revoke all on function public.recommend_today_verse(text[], text, text, text) from anon;
grant execute on function public.recommend_today_verse(text[], text, text, text) to authenticated;

-- ============================================================
-- 6. record_verse_feedback — signature CHANGED from 0009's
--    (p_curated_verse_id uuid, p_signal text) to (p_book text, p_chapter
--    int, p_verse int, p_signal text). Feedback identity is now the verse
--    reference itself, so a signal can be recorded for ANY scored verse —
--    curated or AI-tagged-only — with no dependency on a curated_verses
--    row existing. curated_verse_id is simply left null on the inserted
--    row (verse_feedback.curated_verse_id is nullable as of section 3
--    above). recommend_today_verse's -30 feedback term already reads
--    verse_feedback by (book,chapter,verse), so this closes the loop on
--    the write side to match. The old uuid-based overload is dropped so
--    exactly one record_verse_feedback signature exists after this
--    migration runs (Swift only ever calls the new one).
-- ============================================================
drop function if exists public.record_verse_feedback(uuid, text);

create or replace function public.record_verse_feedback(
  p_book text,
  p_chapter int,
  p_verse int,
  p_signal text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.verse_feedback (user_id, book, chapter, verse, signal)
  values (auth.uid(), p_book, p_chapter, p_verse, p_signal);
end;
$$;

revoke all on function public.record_verse_feedback(text, int, int, text) from public;
revoke all on function public.record_verse_feedback(text, int, int, text) from anon;
grant execute on function public.record_verse_feedback(text, int, int, text) to authenticated;
