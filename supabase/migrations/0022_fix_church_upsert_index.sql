-- Fix add_church upserts.
--
-- add_church upserts with ON CONFLICT (youtube_channel_id). Migration 0020
-- created a PARTIAL unique index (WHERE youtube_channel_id IS NOT NULL), which
-- Postgres cannot use as an ON CONFLICT arbiter — so every add_church call
-- failed with "no unique or exclusion constraint matching the ON CONFLICT
-- specification".
--
-- Replace it with a plain unique index. Postgres still treats NULLs as
-- distinct, so the many channel-less (generic/seeded) churches remain valid,
-- while non-null channel ids stay unique and usable as an ON CONFLICT arbiter.

drop index if exists public.churches_youtube_channel_id_key;

create unique index if not exists churches_youtube_channel_id_key
  on public.churches (youtube_channel_id);
