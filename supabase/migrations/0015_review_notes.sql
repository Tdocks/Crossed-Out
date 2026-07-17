-- Adds an audit trail column for the second-pass AI tag reviewer
-- (scripts/review_tags.py). Additive & idempotent: safe to re-run.
--
-- review_note records WHY a pending verse_tags row (source='ai') was
-- promoted to 'approved' or demoted to 'rejected' by the reviewer model,
-- so a human can later audit the review pass without re-running it.
-- Nullable: rows untouched by the reviewer (still 'pending', or
-- source='curated'/'rule' rows the reviewer never writes to) simply have
-- no note.

alter table public.verse_tags add column if not exists review_note text;
