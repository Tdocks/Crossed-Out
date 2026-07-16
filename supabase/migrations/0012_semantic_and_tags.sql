-- Semantic search (pgvector embeddings over bible_verses) + a generalized
-- verse tagging table that widens 0009's curated-only tagging to any
-- book/chapter/verse. Additive & idempotent: safe to re-run.
--
-- Scope note: this migration does NOT touch public.recommend_today_verse
-- (0009) — the live "Today" recommendation engine keeps scoring against
-- curated_verse_tags for now. Blending verse_tags into that RPC is a later
-- migration. verse_tags exists here so the AI tagging pipeline has one
-- table to write to/read from across curated + non-curated verses, and
-- verse_embeddings/match_verses exist so a future semantic-search feature
-- can query similarity without re-touching the recommendation engine.

-- ============================================================
-- 1. pgvector extension
-- ============================================================
create extension if not exists vector;

-- ============================================================
-- 2. verse_embeddings — translation-agnostic, keyed to a verse reference.
--    Embeddings are generated from the BSB text (see 0003/0011's default
--    app translation) but the vector itself represents the verse
--    reference, not any one translation's row.
-- ============================================================
create table if not exists public.verse_embeddings (
  book text not null,
  chapter int not null,
  verse int not null,
  embedding vector(1536),
  primary key (book, chapter, verse)
);

create index if not exists idx_verse_embeddings_hnsw
  on public.verse_embeddings using hnsw (embedding vector_cosine_ops);

-- ============================================================
-- 3. verse_tags — generalizes 0009's curated_verse_tags to ANY bible
--    verse, not just the curated_verses set. `source` distinguishes how a
--    tag was produced; `review_status` lets AI/rule-generated tags be
--    queued for human review before use.
-- ============================================================
create table if not exists public.verse_tags (
  id uuid primary key default gen_random_uuid(),
  book text not null,
  chapter int not null,
  verse int not null,
  focus_slug text not null references public.focus_areas(slug) on delete cascade,
  emotion text check (emotion in (
    'peaceful','anxious','discouraged','motivated','angry','lonely',
    'confused','grateful','tempted','overwhelmed','hopeful','grieving'
  )),
  tone text check (tone in ('comfort','instruction','challenge')),
  maturity text check (maturity in ('beginner','growing','mature')),
  theme text,
  source text not null default 'ai' check (source in ('curated','ai','rule')),
  confidence real not null default 0.5,
  review_status text not null default 'pending' check (review_status in ('approved','pending','rejected')),
  created_at timestamptz default now(),
  unique (book, chapter, verse, focus_slug, source)
);

create index if not exists idx_verse_tags_focus on public.verse_tags (focus_slug);
create index if not exists idx_verse_tags_review_status on public.verse_tags (review_status);

-- ============================================================
-- 4. Backfill — migrate existing curated tags into verse_tags so the
--    tagging engine can eventually read from one table. Idempotent via the
--    (book,chapter,verse,focus_slug,source) unique constraint.
-- ============================================================
insert into public.verse_tags (book, chapter, verse, focus_slug, emotion, tone, maturity, source, confidence, review_status)
select cv.book, cv.chapter, cv.verse_start, t.focus_slug, t.emotion, t.tone, t.maturity, 'curated', 1.0, 'approved'
from public.curated_verses cv
join public.curated_verse_tags t on t.curated_verse_id = cv.id
on conflict (book, chapter, verse, focus_slug, source) do nothing;

-- ============================================================
-- 5. RLS + grants — match 0007/0009's conventions.
-- ============================================================
alter table public.verse_tags enable row level security;
alter table public.verse_embeddings enable row level security;

-- verse_tags: readable by authenticated (needed for scoring), not anon.
drop policy if exists "read verse tags" on public.verse_tags;
create policy "read verse tags" on public.verse_tags
  for select to authenticated using (true);

revoke all on table public.verse_tags from anon;

-- verse_embeddings: RLS enabled, but no select policy for anon or
-- authenticated — raw embedding vectors are only exposed via the
-- security-definer match_verses RPC below.
revoke all on table public.verse_embeddings from anon;
revoke all on table public.verse_embeddings from authenticated;

-- ============================================================
-- 6. match_verses RPC — cosine-similarity search over verse_embeddings,
--    joined back to bible_verses for the requested translation's text.
--    security definer so authenticated callers can query similarity
--    without needing direct table privileges on verse_embeddings.
-- ============================================================
create or replace function public.match_verses(
  p_query_embedding vector(1536),
  p_translation text default 'BSB',
  p_limit int default 20
)
returns table (
  book text,
  chapter int,
  verse int,
  text text,
  similarity real
)
language sql
stable
security definer
set search_path = public
as $$
  select
    ve.book,
    ve.chapter,
    ve.verse,
    bv.text,
    1 - (ve.embedding <=> p_query_embedding) as similarity
  from public.verse_embeddings ve
  join public.bible_verses bv
    on (bv.book, bv.chapter, bv.verse) = (ve.book, ve.chapter, ve.verse)
   and bv.translation = coalesce(nullif(p_translation, ''), 'BSB')
  order by ve.embedding <=> p_query_embedding asc
  limit greatest(coalesce(p_limit, 20), 1);
$$;

revoke all on function public.match_verses(vector(1536), text, int) from public;
revoke all on function public.match_verses(vector(1536), text, int) from anon;
grant execute on function public.match_verses(vector(1536), text, int) to authenticated;
