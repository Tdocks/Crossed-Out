# Bible embedding + AI tagging pipeline

`tag_bible.py` embeds every BSB verse (31,102 rows in `bible_verses` where
`translation='BSB'`) into `verse_embeddings`, AI-tags every BSB verse into
`verse_tags` (source `'ai'`), and embeds the 24 `focus_areas` into
`focus_embeddings` (migration `0013_blend_engine.sql` — see "Focus area
embeddings" below), using the controlled vocabularies baked into the script.
It is resumable: you can stop it (Ctrl-C, crash, laptop sleep) and re-run the
same command later — it only processes verses (and focus areas) it hasn't
already written.

## Prerequisites

1. **Migrations `0012_semantic_and_tags.sql` AND `0013_blend_engine.sql` must
   already be applied** to your Supabase project. 0012 creates the `vector`
   extension (`create extension if not exists vector`), the
   `verse_embeddings` table, and the `verse_tags` table (with its FK to
   `focus_areas.slug` and CHECK constraints on
   `emotion`/`tone`/`maturity`/`review_status`/`source`). 0013 adds the
   `focus_embeddings` table this script's embed phase now writes to, and
   blends `verse_tags` + `focus_embeddings` into `recommend_today_verse`.
   Apply them the same way you apply the rest of `supabase/migrations/`
   (Supabase CLI, dashboard SQL editor, or `mcp__Supabase__apply_migration`
   if you're doing this from an agent session) before running this script.
2. Python 3.10+ on your Mac.
3. Install dependencies:

   ```bash
   pip install openai "psycopg[binary]"
   ```

## Configure environment variables

The script reads everything from the environment — there are no secrets in
the code.

- **`OPENAI_API_KEY`** — already in `supabase/.env.local` in this repo. Copy
  the value of the `OPENAI_API_KEY=` line from that file.
- **`DATABASE_URL`** — the Supabase **session pooler** connection string
  (port 5432, not the transaction pooler on 6543 — this script holds a
  single long-lived connection and does interleaved reads/writes, which is
  what the session pooler is for). Get it from Supabase dashboard → Project
  Settings → Database → Connection string → "Session pooler", then swap in
  your actual database password. **URL-encode the password** if it has
  special characters (e.g. `@` → `%40`, `#` → `%23`) — you'll need to reset
  the DB password first if you don't already have it in a URL-safe form,
  since it's not stored in plaintext anywhere in this repo.

  It looks like:
  ```
  postgresql://postgres.<project-ref>:<URL-ENCODED-PASSWORD>@aws-0-<region>.pooler.supabase.com:5432/postgres
  ```

- **`OPENAI_BASE_URL`** (optional) — only set this if you're routing through
  a proxy or an OpenAI-compatible alternate endpoint. Leave unset to use
  OpenAI directly.
- **`EMBED_MODEL`** (optional, default `text-embedding-3-small`) — 1536
  dimensions, matching `verse_embeddings.embedding vector(1536)`. Don't
  change this unless you also change the column's dimension in a new
  migration — a different-dimension model will fail the `::vector` cast.
- **`TAG_MODEL`** (optional, default `gpt-4o-mini`) — the chat model used for
  tagging. You can override this to any chat-completions-compatible model,
  including a fine-tune of your own, as long as it supports
  `response_format={"type": "json_object"}`. If you change it, also update
  `CHAT_PRICE_PER_1M_TOKENS` in the script if you want accurate cost
  estimates for that model.

Set them for your shell session, e.g.:

```bash
export OPENAI_API_KEY="sk-...copied-from-supabase/.env.local..."
export DATABASE_URL="postgresql://postgres.xxxx:PASSWORD@aws-0-region.pooler.supabase.com:5432/postgres"
# optional:
# export TAG_MODEL="gpt-4o-mini"
# export EMBED_MODEL="text-embedding-3-small"
```

## Step 1 — cheap test run first

Before spending money on the full Bible, run a small batch and actually look
at what the model produces:

```bash
cd "/Users/tylerdockswell/Projects/Crossed Out /"
python scripts/tag_bible.py --limit 200
```

This embeds and tags the first ~200 not-yet-processed BSB verses (in
canonical order, so this will be Genesis 1 onward on a fresh DB). Cost is a
fraction of a cent to a few cents depending on `TAG_MODEL`.

### Review a sample in SQL before trusting the full run

Connect to the DB (`psql "$DATABASE_URL"`, the Supabase SQL editor, or any
Postgres client) and eyeball what got written:

```sql
-- see what the model actually tagged, verse by verse
select book, chapter, verse, focus_slug, emotion, tone, maturity, theme,
       confidence, review_status
from verse_tags
where source = 'ai'
order by book, chapter, verse
limit 50;

-- sanity-check: are there any values outside the controlled vocab?
-- (should always return 0 rows — the script validates before insert,
-- and the DB's own CHECK/FK constraints are a second line of defense)
select * from verse_tags
where source = 'ai'
  and (emotion is not null and emotion not in
       ('peaceful','anxious','discouraged','motivated','angry','lonely',
        'confused','grateful','tempted','overwhelmed','hopeful','grieving'));

-- spot-check embeddings landed
select count(*) from verse_embeddings;

-- eyeball which verses got NO tags at all (expected for genealogies, etc.)
select b.book, b.chapter, b.verse, b.text
from bible_verses b
where b.translation = 'BSB'
  and not exists (select 1 from verse_tags t where t.book=b.book and t.chapter=b.chapter and t.verse=b.verse and t.source='ai')
order by b.id
limit 20;
```

Read through 20-30 tagged verses and confirm: no proof-texting, no tags that
feel invented, `theme` text actually describes the verse, `confidence`
roughly matches how directly the verse addresses the topic. If something
looks off, adjust `TAGGING_SYSTEM_PROMPT` in `tag_bible.py` and re-run
`--limit 200` again (it's idempotent — re-running upserts over the same
rows) before committing to the full Bible.

## Focus area embeddings

As part of the embed phase (`--embed-only` or the default full run — not
`--tag-only`), the script also embeds the 24 `focus_areas` rows into the
`focus_embeddings` table added by migration `0013_blend_engine.sql`. This
powers `recommend_today_verse`'s guarded semantic re-ranking term: it never
surfaces an untagged verse, it only re-ranks verses that already have an
approved `verse_tags` match, by how semantically close their embedding is to
the user's selected focus areas.

Each focus area is embedded from a rich string — its human label plus a
one-line description of the life situation it represents (see
`FOCUS_AREA_DESCRIPTIONS` in `tag_bible.py`), not just the bare slug or
label — so the cosine similarity reflects an actual devotional match. This
step is cheap: 24 rows, one API call, well under a cent. It's resumable the
same way as verse embeddings (`focus_embeddings` rows already present are
never re-embedded — a `LEFT JOIN ... WHERE focus_embeddings.focus_slug IS
NULL` filter), and upserts on conflict (`ON CONFLICT (focus_slug) DO UPDATE
SET embedding = EXCLUDED.embedding`), so re-running after tweaking
`FOCUS_AREA_DESCRIPTIONS` and deleting the old rows (or just letting the
`DO UPDATE` overwrite them) is safe.

## Step 2 — the full run

```bash
python scripts/tag_bible.py
```

This processes all remaining un-embedded and un-tagged BSB verses (skipping
anything Step 1 already did). You can also run the phases separately:

```bash
python scripts/tag_bible.py --embed-only
python scripts/tag_bible.py --tag-only
```

### Expected cost (31,102 BSB verses)

- **Embeddings**: `text-embedding-3-small` at $0.02 / 1M tokens. BSB verses
  average roughly 20-25 tokens each, so total input is on the order of
  700K-800K tokens → **~$0.02-$0.05** for the whole Bible.
- **Tagging**: batches of ~18 verses per call (~1,730 calls total), each
  call's prompt includes the full system prompt (~600-700 tokens) plus batch
  verse text plus JSON output. Rough order of magnitude:
  - `gpt-4o-mini` (default): **~$3-$8** for the full Bible.
  - A larger/pricier model (e.g. `gpt-4o`, or a custom fine-tune with
    different pricing): **~$20-$60+** — check current pricing for whatever
    `TAG_MODEL` you set, and update `CHAT_PRICE_PER_1M_TOKENS` in the script
    so the running cost estimate stays meaningful.

  The script prints a running `$` estimate as it goes and a final summary,
  so you don't have to guess — watch the first few hundred verses of a real
  run and extrapolate if you want a tighter number before committing to the
  rest.

### Expected runtime

Sequential, batched, rate-limit-friendly (no aggressive concurrency): expect
roughly **1-3 hours** for the full Bible end to end, depending on API
latency and how many batches need retries. Embeddings finish much faster
than tagging (32 batches of ≤1000 vs. ~1,730 tagging batches of ~18).

## Re-running safely

Every phase is resumable by design:

- **Embeddings** — only verses missing from `verse_embeddings` are
  re-fetched from `bible_verses`; already-embedded verses are never
  re-sent to the API. Safe to Ctrl-C and re-run anytime.
- **Tagging** — only verses without an existing `verse_tags` row where
  `source='ai'` are re-considered. Because a verse can legitimately have
  zero applicable tags (e.g. a genealogy), the script also creates a small
  internal bookkeeping table, `ai_tag_progress(book, chapter, verse)`, on
  first run (via `CREATE TABLE IF NOT EXISTS` — not part of migration 0012,
  holds no theological data) so it correctly remembers "the model looked at
  this verse and found nothing to tag" instead of re-asking forever. If your
  DB role can't `CREATE TABLE`, the script logs a warning and keeps going —
  it'll just possibly re-send zero-tag verses to the model on a later
  `--resume` run (wasted API cost, not a correctness problem).
- **Focus area embeddings** — only `focus_areas` slugs without an existing
  `focus_embeddings` row are re-embedded; already-embedded focus areas are
  never re-sent to the API. Safe to Ctrl-C and re-run anytime, same as verse
  embeddings.
- A bad batch (API error, malformed JSON, a DB constraint violation) is
  logged and skipped — it never crashes the whole run, and it'll be retried
  automatically the next time you run the script.
- `--resume` is accepted as an explicit no-op flag if you want your
  invocations to say so; resuming is the default behavior either way.

To force a verse to be re-tagged (e.g. after tightening the prompt), delete
its existing rows first:

```sql
delete from verse_tags where source = 'ai' and book = 'Genesis' and chapter = 1 and verse = 1;
delete from ai_tag_progress where book = 'Genesis' and chapter = 1 and verse = 1;
```

## Files

- `scripts/tag_bible.py` — the pipeline.
- `scripts/README.md` — this file.
