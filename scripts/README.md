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
   pip3 install openai "psycopg[binary]"
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
- **`TAG_CONCURRENCY`** (optional, default `8`) — the tagging phase is
  bottlenecked on the OpenAI API round-trip (~9-10s per ~18-verse batch),
  not CPU or the DB, so tagging batches now run concurrently on a
  `ThreadPoolExecutor` with this many workers. Each worker does only the
  API call + JSON parse + controlled-vocab validation; every DB write
  (`verse_tags` upserts, `ai_tag_progress` bookkeeping) still happens
  serialized on the main thread, so this is safe to raise without risking
  concurrent writes on the single DB connection. Lower it if you hit
  OpenAI rate limits; raise it if your account tier has headroom.

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
python3 scripts/tag_bible.py --limit 200
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
python3 scripts/tag_bible.py
```

This processes all remaining un-embedded and un-tagged BSB verses (skipping
anything Step 1 already did). You can also run the phases separately:

```bash
python3 scripts/tag_bible.py --embed-only
python3 scripts/tag_bible.py --tag-only
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

Embeddings finish fast (32 batches of ≤1000). Tagging is the long pole
(~1,730 batches of ~18 verses), and each batch call takes roughly ~9-10s of
API round-trip time — that's the bottleneck, not CPU or the DB. Tagging
batches now run concurrently via a `ThreadPoolExecutor` (`TAG_CONCURRENCY`
workers, default 8), so wall-clock time for the tagging phase drops
roughly `TAG_CONCURRENCY`-fold versus running batches one at a time — at
the default of 8 workers, expect the full Bible to finish in on the order
of **30-45 minutes** rather than several hours, depending on API latency,
rate limits, and how many batches need retries. Raise `TAG_CONCURRENCY` for
more speedup if your OpenAI account tier has the rate-limit headroom; lower
it if you start seeing 429s.

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

## Review pass

`review_tags.py` is a strict second-pass reviewer over the AI tags
`tag_bible.py` writes. Tagging always writes `review_status='pending'` —
this script re-reads each pending tag against the actual verse text and
either promotes it to `'approved'` (only `'approved'` tags are ever used by
the recommendation engine — see `recommend_today_verse` / 0013's blend
engine) or demotes it to `'rejected'`, recording why in the `review_note`
column. It never touches `source='curated'` rows — those were seeded
already-`'approved'` in migration `0012` and stay that way.

The tagging model has a known lean toward keyword-driven mistakes — e.g.
tagging a character's judgment/despair (Cain's "my punishment is greater
than I can bear") or God's own emotion ("the LORD was grieved in His
heart") as personal grief/comfort, or tagging `tone=comfort` onto
confrontation, warning, or fear-depicting verses just because they mention
a matching feeling. The reviewer prompt is built specifically to catch
these — see `REVIEWER_SYSTEM_PROMPT` in `review_tags.py` for the full rule
set. When a case is genuinely borderline, the reviewer is instructed to
reject: a mis-served verse is worse than a missing one.

### Prerequisites

1. **Migration `0015_review_notes.sql` must be applied first** — it adds
   the `review_note text` column to `verse_tags` that this script writes
   to. Apply it the same way you apply the rest of `supabase/migrations/`.
2. A tagging run (`tag_bible.py`) should already have written the
   `source='ai'`, `review_status='pending'` rows this script reviews —
   there's nothing to do until those exist.
3. Same Python dependencies as `tag_bible.py` (`pip3 install openai
   "psycopg[binary]"`) — already installed if you've run the tagging
   script.

### Environment variables

- **`DATABASE_URL`** — same Supabase session pooler connection string used
  for `tag_bible.py`.
- **`OPENAI_API_KEY`** — same key as `tag_bible.py`.
- **`OPENAI_BASE_URL`** (optional) — same meaning as `tag_bible.py`.
- **`REVIEW_MODEL`** (optional, default `gpt-4o-mini`) — the chat model used
  for review. **A stronger model (e.g. `gpt-4o`, `gpt-4.1`) gives better
  theological judgment on borderline cases** and is worth the extra cost
  for this pass even if `gpt-4o-mini` was used for the original tagging —
  precision matters more here, since this is the last check before a tag
  reaches a real user. If you change it, update `CHAT_PRICE_PER_1M_TOKENS`
  in `review_tags.py` for an accurate running cost estimate.

### Running it

Cheap test pass first — look at what gets approved/rejected and why before
trusting a full run:

```bash
cd "/Users/tylerdockswell/Projects/Crossed Out /"
export DATABASE_URL="postgresql://postgres.xxxx:PASSWORD@aws-0-region.pooler.supabase.com:5432/postgres"
export OPENAI_API_KEY="sk-...copied-from-supabase/.env.local..."
# optional: export REVIEW_MODEL="gpt-4o"
python3 scripts/review_tags.py --limit 200
```

Then the full pass over every remaining pending AI tag:

```bash
python3 scripts/review_tags.py
```

It's resumable and idempotent: only `source='ai' AND review_status='pending'`
rows are ever selected, so re-running after a crash/Ctrl-C, or after a later
`tag_bible.py` run adds more pending tags, is always safe — already-reviewed
rows are never re-touched. A batch that errors (API failure, malformed
JSON) is logged and skipped rather than crashing the run; those rows stay
`'pending'` and are retried on the next run.

The script prints progress and a running `$` cost estimate as it goes, and
a final summary of approved/rejected counts overall **and per
`focus_slug`**, so a systematically over-rejected or problem focus area is
visible immediately rather than buried in aggregate numbers.

### Inspecting results in SQL

```sql
-- overall breakdown
select review_status, count(*)
from verse_tags
where source = 'ai'
group by review_status;

-- per-focus breakdown, to spot a focus area with unusually high rejection
select focus_slug, review_status, count(*)
from verse_tags
where source = 'ai'
group by focus_slug, review_status
order by focus_slug, review_status;

-- read a sample of rejections and why
select book, chapter, verse, focus_slug, emotion, tone, review_note
from verse_tags
where source = 'ai' and review_status = 'rejected'
order by book, chapter, verse
limit 50;

-- read a sample of approvals and why
select book, chapter, verse, focus_slug, emotion, tone, review_note
from verse_tags
where source = 'ai' and review_status = 'approved'
order by book, chapter, verse
limit 50;
```

**Only `review_status='approved'` tags are used by the recommendation
engine.** `'pending'` tags (not yet reviewed) and `'rejected'` tags
(reviewed and declined) are never surfaced to users — this review pass is
what promotes a tag from "the tagging model's guess" to "vetted for
production."

## Files

- `scripts/tag_bible.py` — the AI embedding + tagging pipeline.
- `scripts/review_tags.py` — the strict second-pass reviewer.
- `scripts/README.md` — this file.
