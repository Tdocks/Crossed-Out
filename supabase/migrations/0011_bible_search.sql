-- Full-text search over public.bible_verses (BSB, WEB, KJV — ~93k rows).
-- Additive & idempotent: safe to re-run against an already-migrated database.
--
-- 1. A generated tsvector column, backfilled automatically for existing
--    rows (Postgres computes STORED generated columns for all existing
--    rows as part of the ALTER TABLE — a one-time ~93k row backfill).
alter table public.bible_verses
  add column if not exists tsv tsvector generated always as (to_tsvector('english', text)) stored;

-- 2. GIN index for fast full-text lookups. The existing
--    idx_bible_lookup (translation, book, chapter) from 0003 is untouched
--    and still serves plain chapter reads.
create index if not exists idx_bible_tsv on public.bible_verses using gin (tsv);

-- 3. search_bible RPC — websearch-style full-text search over one
--    translation, ranked by ts_rank. A null/blank query intentionally
--    matches nothing (rather than erroring) so a UI can call this on every
--    keystroke without guarding client-side.
create or replace function public.search_bible(
  p_query text,
  p_translation text default 'BSB',
  p_limit int default 50
)
returns table (
  book text,
  chapter int,
  verse int,
  text text,
  rank real
)
language sql
stable
as $$
  select
    bv.book,
    bv.chapter,
    bv.verse,
    bv.text,
    ts_rank(bv.tsv, websearch_to_tsquery('english', p_query)) as rank
  from public.bible_verses bv
  where p_query is not null
    and btrim(p_query) <> ''
    and bv.translation = coalesce(nullif(p_translation, ''), 'BSB')
    and bv.tsv @@ websearch_to_tsquery('english', p_query)
  order by rank desc, bv.book, bv.chapter, bv.verse
  limit greatest(coalesce(p_limit, 50), 1);
$$;

-- 4. Grants — match 0007's convention: reference data stays readable, but
--    RPC execution is explicitly scoped to `authenticated` and revoked from
--    `anon`/`public` rather than relying on default grants.
revoke execute on function public.search_bible(text, text, int) from anon;
revoke execute on function public.search_bible(text, text, int) from public;
grant execute on function public.search_bible(text, text, int) to authenticated;
