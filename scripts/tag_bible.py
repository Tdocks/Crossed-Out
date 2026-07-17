#!/usr/bin/env python3
"""
tag_bible.py — Embed and AI-tag the entire Bible (BSB translation) for Crossed Out.

WHAT THIS DOES
--------------
Runs three independent, resumable phases against the Supabase Postgres DB
defined by migrations 0012_semantic_and_tags.sql and 0013_blend_engine.sql:

  1. EMBEDDINGS — for every verse in bible_verses where translation='BSB' that
     does not yet have a row in verse_embeddings, calls the OpenAI embeddings
     API (default model: text-embedding-3-small, 1536 dims) in batches of up
     to 1000 inputs, and upserts (book, chapter, verse, embedding) into
     verse_embeddings.

  2. TAGGING — for every BSB verse that does not yet have an AI-sourced row in
     verse_tags, sends small batches (~15-20 verses) to a chat model (default:
     gpt-4o-mini) with a strict JSON response format. The model returns 0..N
     {focus_slug, emotion, tone, maturity, theme, confidence} entries per verse
     using ONLY the controlled vocabularies below, and an empty array for
     verses that are not genuinely devotional/applicable (e.g. genealogies,
     census lists, ceremonial-law measurements). Rows are validated against
     the controlled vocab and upserted into verse_tags with source='ai'.

  3. FOCUS AREA EMBEDDINGS — as part of the embed phase (step 1), also embeds
     the 24 focus_areas (migration 0013_blend_engine.sql's focus_embeddings
     table) that don't yet have a row: text-embedding-3-small over a rich
     "label + one-line life-situation description" string per focus area (see
     FOCUS_AREA_DESCRIPTIONS below), upserted on conflict. This is cheap (24
     rows, one API call) and powers recommend_today_verse's guarded semantic
     re-ranking term — it re-ranks already-tagged candidates by similarity to
     the user's selected focus areas, it never surfaces untagged verses.

CONTROLLED VOCABULARIES (the model must use ONLY these — anything else is
dropped before insert; see validate_tag() below)
--------------------------------------------------------------------------
focus_slug (24): anxiety, purpose, relationships, financial_wisdom,
  forgiveness, grief, discipline, loneliness, marriage, parenting,
  temptation, career, confidence, understanding_god, returning_to_faith,
  learning_to_pray, depression_hope, motivation, addiction, anger,
  leadership, new_to_christianity, understanding_the_bible, rest_peace.
  (These must match public.focus_areas.slug exactly — verse_tags.focus_slug
  has a foreign key to that table.)
emotion (12): peaceful, anxious, discouraged, motivated, angry, lonely,
  confused, grateful, tempted, overwhelmed, hopeful, grieving.
tone (3): comfort, instruction, challenge.
maturity (3): beginner, growing, mature.

RESUMABILITY
------------
All three phases are idempotent and safe to re-run at any time:
  - Embeddings: verses already present in verse_embeddings are never
    re-fetched or re-embedded (LEFT JOIN ... WHERE embedding row IS NULL).
  - Focus area embeddings: the 24 focus_areas rows already present in
    focus_embeddings are never re-fetched or re-embedded (same LEFT JOIN
    pattern), and the upsert is ON CONFLICT (focus_slug) DO UPDATE, so it's
    also safe to force a re-embed by deleting a row and re-running.
  - Tagging: verses that already have >=1 verse_tags row with source='ai'
    are skipped. Because a verse can legitimately produce ZERO tags (e.g. a
    genealogy), we also maintain a small bookkeeping table,
    ai_tag_progress(book, chapter, verse), created on first run with
    `CREATE TABLE IF NOT EXISTS`, that records every verse the tagging model
    has actually considered (even if it produced no tags). This is the only
    schema this script adds beyond the two contract tables; it is NOT part of
    migration 0012 and holds no theological data, just a "have we asked the
    model about this verse yet" marker. If the DB role lacks CREATE TABLE
    permission, the script logs a warning and continues without it — the run
    still works, but verses with zero applicable tags may be re-sent to the
    model on a future --resume run (extra cost, not a correctness issue).

USAGE
-----
  python scripts/tag_bible.py                  # full resumable run (embed + tag)
  python scripts/tag_bible.py --limit 200       # cheap test run, first 200 verses
  python scripts/tag_bible.py --embed-only
  python scripts/tag_bible.py --tag-only
  python scripts/tag_bible.py --resume          # no-op flag; resuming is always
                                                 # the default behavior. Present
                                                 # for explicit/documented invocations.

ENVIRONMENT VARIABLES
----------------------
  DATABASE_URL     required. Postgres connection string (Supabase session
                    pooler recommended), e.g.
                    postgresql://postgres.xxxx:PASSWORD@aws-0-region.pooler.supabase.com:5432/postgres
  OPENAI_API_KEY   required.
  OPENAI_BASE_URL  optional. Point at a self-hosted / alternate OpenAI-compatible
                    endpoint. Defaults to OpenAI's own API.
  EMBED_MODEL      optional. Default: text-embedding-3-small (1536 dims).
  TAG_MODEL        optional. Default: gpt-4o-mini. Can be overridden to any
                    chat-completions-compatible model, including your own
                    fine-tune, as long as it supports response_format=json_object.

See scripts/README.md for install steps, cost/runtime estimates, and how to
review a sample of tags in SQL before committing to the full run.
"""

from __future__ import annotations

import argparse
import itertools
import json
import logging
import os
import random
import sys
import time
from dataclasses import dataclass
from typing import Iterator

try:
    import psycopg
    from psycopg.rows import dict_row
except ImportError:  # pragma: no cover
    print(
        "Missing dependency 'psycopg'. Install with: pip install openai \"psycopg[binary]\"",
        file=sys.stderr,
    )
    raise

try:
    from openai import OpenAI
except ImportError:  # pragma: no cover
    print(
        "Missing dependency 'openai'. Install with: pip install openai \"psycopg[binary]\"",
        file=sys.stderr,
    )
    raise


# ============================================================================
# Controlled vocabularies
# ============================================================================

FOCUS_SLUGS = frozenset(
    [
        "anxiety", "purpose", "relationships", "financial_wisdom",
        "forgiveness", "grief", "discipline", "loneliness", "marriage",
        "parenting", "temptation", "career", "confidence",
        "understanding_god", "returning_to_faith", "learning_to_pray",
        "depression_hope", "motivation", "addiction", "anger",
        "leadership", "new_to_christianity", "understanding_the_bible",
        "rest_peace",
    ]
)

EMOTIONS = frozenset(
    [
        "peaceful", "anxious", "discouraged", "motivated", "angry",
        "lonely", "confused", "grateful", "tempted", "overwhelmed",
        "hopeful", "grieving",
    ]
)

TONES = frozenset(["comfort", "instruction", "challenge"])
MATURITIES = frozenset(["beginner", "growing", "mature"])

# Rich embedding input for migration 0013's focus_embeddings table: human
# label + a one-line description of the life situation, so cosine similarity
# against verse_embeddings reflects an actual devotional match rather than
# just matching on the bare slug/label string. Keys must match FOCUS_SLUGS
# exactly (focus_embeddings.focus_slug has an FK to focus_areas.slug).
FOCUS_AREA_DESCRIPTIONS: dict[str, str] = {
    "anxiety": "Anxiety: persistent worry, racing thoughts, or fear about what might happen next.",
    "purpose": "Purpose: searching for meaning, direction, or a sense of why you're here.",
    "relationships": "Relationships: navigating friendships, family ties, or other close connections.",
    "financial_wisdom": "Financial Wisdom: money stress, debt, generosity, work, and stewardship of resources.",
    "forgiveness": "Forgiveness: struggling to forgive someone who hurt you, or needing to be forgiven yourself.",
    "grief": "Grief: mourning the loss of a loved one, or grieving a loss of any kind.",
    "discipline": "Discipline: building consistency, self-control, and healthy habits.",
    "loneliness": "Loneliness: feeling isolated, unseen, or disconnected from others.",
    "marriage": "Marriage: the joys and struggles of married life and commitment to a spouse.",
    "parenting": "Parenting: raising children, guiding them, and the exhaustion and joy of family life.",
    "temptation": "Temptation: resisting sin, desire, or the pull toward something harmful.",
    "career": "Career: work stress, ambition, job transitions, and finding meaning in labor.",
    "confidence": "Confidence: self-doubt, insecurity, and needing courage to move forward.",
    "understanding_god": "Understanding God: wanting to know who God is and what He is like.",
    "returning_to_faith": "Returning to Faith: coming back to God after doubt, distance, or falling away.",
    "learning_to_pray": "Learning to Pray: wanting to grow in prayer and talking honestly with God.",
    "depression_hope": "Depression & Hope: heavy sadness, despair, and needing hope to keep going.",
    "motivation": "Motivation: feeling stuck, unmotivated, or needing encouragement to keep moving.",
    "addiction": "Addiction: struggling with a compulsive habit or substance and wanting freedom from it.",
    "anger": "Anger: frustration, resentment, or rage that needs to be brought honestly before God.",
    "leadership": "Leadership: leading others well, with humility, wisdom, and integrity.",
    "new_to_christianity": "New to Christianity: just beginning a relationship with Jesus and the basics of faith.",
    "understanding_the_bible": "Understanding the Bible: learning how to read, interpret, and apply Scripture.",
    "rest_peace": "Rest & Peace: needing calm, stillness, and relief from busyness or turmoil.",
}

TRANSLATION = "BSB"

# ============================================================================
# Config (env-driven, no hardcoded secrets)
# ============================================================================

DATABASE_URL = os.environ.get("DATABASE_URL", "")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_BASE_URL = os.environ.get("OPENAI_BASE_URL") or None
EMBED_MODEL = os.environ.get("EMBED_MODEL", "text-embedding-3-small")
TAG_MODEL = os.environ.get("TAG_MODEL", "gpt-4o-mini")

EMBED_DIMENSIONS = 1536
EMBED_BATCH_SIZE = 1000  # OpenAI embeddings API accepts up to 2048 inputs/call; 1000 is a safe margin
TAG_BATCH_SIZE = 18      # ~15-20 verses per chat call, per spec

MAX_RETRIES = 5
RETRY_BASE_DELAY = 1.5  # seconds, exponential backoff w/ jitter

# Published per-token prices (USD), as constants for a running cost estimate.
# These are approximate and may drift — check https://openai.com/api/pricing
# for current numbers, especially if TAG_MODEL is overridden.
EMBED_PRICE_PER_1M_TOKENS = {
    "text-embedding-3-small": 0.02,
    "text-embedding-3-large": 0.13,
}
CHAT_PRICE_PER_1M_TOKENS = {
    # model: (input $/1M tokens, output $/1M tokens)
    "gpt-4o-mini": (0.15, 0.60),
    "gpt-4o": (2.50, 10.00),
    "gpt-4.1-mini": (0.40, 1.60),
    "gpt-4.1": (2.00, 8.00),
}


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-7s %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("tag_bible")


# ============================================================================
# The tagging system prompt — theological guardrails live here.
# ============================================================================

TAGGING_SYSTEM_PROMPT = f"""You are a careful theological classifier for a Bible study app.
You will be given a small batch of Bible verses (BSB translation), each with its
book, chapter, verse number, and text. For EACH verse, decide whether it
genuinely supports zero, one, or more "focus areas" that a person could be
devotionally pointed to this verse for — and if so, tag it.

HARD RULES — READ CAREFULLY:

1. CONTROLLED VOCABULARY ONLY. You may ONLY use these exact string values.
   Never invent, pluralize, translate, or paraphrase a value. If nothing in a
   list genuinely fits, do not force one.

   focus_slug (choose only from this exact list of 24):
   {sorted(FOCUS_SLUGS)}

   emotion (choose only from this exact list of 12, or omit the field):
   {sorted(EMOTIONS)}

   tone (choose only from this exact list of 3, or omit the field):
   {sorted(TONES)}

   maturity (choose only from this exact list of 3, or omit the field):
   {sorted(MATURITIES)}

2. NO PROOF-TEXTING. Only assign a focus_slug when the verse, read in its
   actual literary and historical context, truly addresses that topic. Do not
   yank a phrase out of context to make it fit a theme it was never about.
   When in doubt, leave it untagged rather than force a connection.

3. NO INVENTED MEANINGS. Do not allegorize, spiritualize, or read modern
   therapeutic concepts into text that isn't about them. A verse about
   agricultural law is not secretly about "financial_wisdom" unless it is
   genuinely, contextually about stewardship, work, or provision.

4. OFFERS VS. MENTIONS — TAG WHAT THE VERSE OFFERS, NOT WHAT IT MERELY
   MENTIONS. Assign a focus_slug/emotion ONLY if the verse, in its own
   context, genuinely ministers to or addresses a reader who is in that
   situation right now — never because it merely contains a matching
   keyword. A verse describing GOD's OWN emotion (His grief, anger, or
   jealousy), a character's sin, judgment, or punishment, or a plot event
   is NOT a personal devotional verse for that feeling, even if it contains
   words like "grief," "grieved," "bear," or "afraid." Ask yourself: does
   this verse speak TO a struggling reader, or does it merely DESCRIBE
   something that sounds similar to their struggle? Only the former earns a
   tag.

5. THE COMFORT BAR. Only apply an emotion tag with tone="comfort" (e.g.
   grief, anxious, lonely, or overwhelmed used in a comforting sense) when
   the verse actually offers the reader hope, a promise, God's nearness, or
   consolation. Do NOT apply a comfort-tone emotional tag merely because the
   verse depicts or names a negative emotion or a negative event — someone
   else's despair, sin, or suffering in the text is not automatically
   comfort for a reader carrying that same feeling.

6. EMPTY IS CORRECT AND EXPECTED — NARRATIVE, GENEALOGY, AND LAW. Many
   verses are not devotionally "applicable" in isolation: genealogies,
   census counts, tribal boundary lists, dimensions of the tabernacle,
   ritual/ceremonial procedural detail, itineraries, pure narrative plot
   events, or legal/ceremonial statutes that carry no transferable promise
   or instruction for today's reader. For these, return an empty tags
   array. Do not stretch to find a lesson that isn't really there. When
   genuinely torn between tagging and not tagging, do not tag —
   under-tagging is strongly preferred to misapplying a tag. A healthy
   batch will often have many empty results — that is success, not
   failure.

7. MULTIPLE TAGS ARE ALLOWED BUT SHOULD BE RARE. Most applicable verses get
   1 tag. Occasionally 2-3 is honest (e.g. a verse that is both about
   "grief" and "hopeful"/comfort). Do not tag every plausible focus area you
   can think of — only the ones a thoughtful reader would agree the verse is
   really about.

8. theme is FREE TEXT (not controlled vocabulary): a short (3-8 word) plain
   description of the specific devotional point of this verse for this tag,
   e.g. "God's presence in exile" or "confessing sin honestly". Keep it
   grounded in what the verse actually says.

9. confidence is a float from 0.0 to 1.0 reflecting how clearly and
   uncontroversially the verse (in context) supports this tag. Reserve
   >=0.85 for verses that are unambiguously and directly about the topic.
   Use 0.5-0.74 for tags that are reasonable but more interpretive or
   context-dependent. If you are not at least moderately confident, omit
   the tag rather than include it at low confidence. Confidence reflects
   how clear the match is — it is NOT a substitute for rules 4-6; a
   keyword-driven mistake can still be stated at high confidence, so those
   rules must be applied before confidence is even considered.

10. THEOLOGICAL SOUNDNESS. Favor the plain, historic, mainstream Christian
    reading of a text. Do not introduce sectarian, fringe, or speculative
    theological claims. When a verse is genuinely ambiguous or disputed,
    prefer fewer/safer tags over a confident-sounding but contestable one.

11. GOOD VS. BAD EXAMPLES — anchor your judgment to these:
    - GOOD: Genesis 2:24, "a man shall leave his father and mother and be
      united to his wife" -> tag focus_slug="marriage". The verse itself
      offers instruction about marriage to the reader.
    - BAD: Genesis 6:6, "the LORD was grieved in His heart" -> do NOT tag
      grief/comfort. This is GOD's own grief over human sin, not comfort
      offered to a grieving reader.
    - BAD: Genesis 4:13, Cain's "My punishment is greater than I can bear"
      -> do NOT tag grief/comfort. This is an unrepentant character's
      despair after judgment, not a verse ministering to the reader.
    - BAD: Genesis 2:16, "you may eat freely from every tree" -> do NOT tag
      temptation/anxious. This verse offers God's generous provision, not
      a warning about temptation.

OUTPUT FORMAT — STRICT JSON, NOTHING ELSE:
Return a single JSON object of the shape:
{{
  "results": [
    {{
      "book": "<same book string you were given>",
      "chapter": <same chapter int>,
      "verse": <same verse int>,
      "tags": [
        {{
          "focus_slug": "...",
          "emotion": "...",
          "tone": "...",
          "maturity": "...",
          "theme": "...",
          "confidence": 0.0
        }}
      ]
    }}
  ]
}}

You MUST include exactly one entry in "results" for every verse you were
given, in any order, using "tags": [] for verses with no applicable tag.
Do not add commentary, markdown, or any text outside the JSON object.
"""


# ============================================================================
# Stats / cost tracking
# ============================================================================

@dataclass
class Stats:
    verses_embedded: int = 0
    focus_areas_embedded: int = 0
    embed_tokens: int = 0
    verses_considered_for_tagging: int = 0
    tags_written: int = 0
    tags_dropped_invalid: int = 0
    tag_input_tokens: int = 0
    tag_output_tokens: int = 0
    embed_batches_failed: int = 0
    tag_batches_failed: int = 0

    def embed_cost(self) -> float:
        price = EMBED_PRICE_PER_1M_TOKENS.get(EMBED_MODEL, 0.02)
        return (self.embed_tokens / 1_000_000) * price

    def tag_cost(self) -> float:
        in_price, out_price = CHAT_PRICE_PER_1M_TOKENS.get(TAG_MODEL, (0.15, 0.60))
        return (self.tag_input_tokens / 1_000_000) * in_price + (
            self.tag_output_tokens / 1_000_000
        ) * out_price

    def total_cost(self) -> float:
        return self.embed_cost() + self.tag_cost()


def chunked(seq: list, size: int) -> Iterator[list]:
    it = iter(seq)
    while True:
        batch = list(itertools.islice(it, size))
        if not batch:
            return
        yield batch


def call_with_retries(fn, what: str, max_retries: int = MAX_RETRIES):
    """Call fn() with exponential backoff + jitter. Raises the last exception
    if all retries are exhausted, so the caller can log-and-continue."""
    last_exc: Exception | None = None
    for attempt in range(1, max_retries + 1):
        try:
            return fn()
        except Exception as exc:  # noqa: BLE001 - intentionally broad, API can raise many types
            last_exc = exc
            if attempt == max_retries:
                break
            wait = RETRY_BASE_DELAY * (2 ** (attempt - 1)) + random.uniform(0, 0.5)
            log.warning(
                "%s failed (attempt %d/%d): %s — retrying in %.1fs",
                what, attempt, max_retries, exc, wait,
            )
            time.sleep(wait)
    assert last_exc is not None
    raise last_exc


# ============================================================================
# Database layer
# ============================================================================

def get_connection():
    if not DATABASE_URL:
        log.error("DATABASE_URL is not set. See scripts/README.md for how to get it.")
        sys.exit(1)
    return psycopg.connect(DATABASE_URL, row_factory=dict_row, autocommit=False)


def ensure_progress_table(conn) -> bool:
    """Create the internal ai_tag_progress bookkeeping table if missing.
    Returns True if the table is usable, False if we should degrade gracefully
    (e.g. the DB role lacks CREATE TABLE privileges)."""
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS ai_tag_progress (
                    book text NOT NULL,
                    chapter int NOT NULL,
                    verse int NOT NULL,
                    tag_count int NOT NULL DEFAULT 0,
                    checked_at timestamptz DEFAULT now(),
                    PRIMARY KEY (book, chapter, verse)
                )
                """
            )
        conn.commit()
        return True
    except Exception as exc:  # noqa: BLE001
        conn.rollback()
        log.warning(
            "Could not create ai_tag_progress bookkeeping table (%s). "
            "Continuing without it — verses with zero applicable tags may be "
            "re-sent to the model on future --resume runs.",
            exc,
        )
        return False


def fetch_verses_needing_embedding(conn, limit: int | None) -> list[dict]:
    sql = """
        SELECT b.book, b.chapter, b.verse, b.text
        FROM bible_verses b
        LEFT JOIN verse_embeddings e
          ON e.book = b.book AND e.chapter = b.chapter AND e.verse = b.verse
        WHERE b.translation = %s AND e.book IS NULL
        ORDER BY b.id
    """
    params: list = [TRANSLATION]
    if limit is not None:
        sql += " LIMIT %s"
        params.append(limit)
    with conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()


def fetch_verses_needing_tags(conn, limit: int | None, has_progress_table: bool) -> list[dict]:
    sql = """
        SELECT b.book, b.chapter, b.verse, b.text
        FROM bible_verses b
        WHERE b.translation = %s
          AND NOT EXISTS (
            SELECT 1 FROM verse_tags t
            WHERE t.book = b.book AND t.chapter = b.chapter AND t.verse = b.verse
              AND t.source = 'ai'
          )
    """
    params: list = [TRANSLATION]
    if has_progress_table:
        sql += """
          AND NOT EXISTS (
            SELECT 1 FROM ai_tag_progress p
            WHERE p.book = b.book AND p.chapter = b.chapter AND p.verse = b.verse
          )
        """
    sql += " ORDER BY b.id"
    if limit is not None:
        sql += " LIMIT %s"
        params.append(limit)
    with conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()


def upsert_embeddings(conn, verses: list[dict], vectors: list[list[float]]) -> None:
    rows = []
    for v, vec in zip(verses, vectors):
        vec_literal = "[" + ",".join(repr(float(x)) for x in vec) + "]"
        rows.append((v["book"], v["chapter"], v["verse"], vec_literal))
    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO verse_embeddings (book, chapter, verse, embedding)
            VALUES (%s, %s, %s, %s::vector)
            ON CONFLICT (book, chapter, verse) DO UPDATE SET embedding = EXCLUDED.embedding
            """,
            rows,
        )
    conn.commit()


def fetch_focus_areas_needing_embedding(conn) -> list[dict]:
    """The 24 focus_areas rows that don't yet have a focus_embeddings row
    (migration 0013_blend_engine.sql). LEFT JOIN filter makes this
    idempotent/resumable, same pattern as fetch_verses_needing_embedding."""
    sql = """
        SELECT fa.slug, fa.label
        FROM focus_areas fa
        LEFT JOIN focus_embeddings fe ON fe.focus_slug = fa.slug
        WHERE fe.focus_slug IS NULL
        ORDER BY fa.sort
    """
    with conn.cursor() as cur:
        cur.execute(sql)
        return cur.fetchall()


def upsert_focus_embeddings(conn, slugs: list[str], vectors: list[list[float]]) -> None:
    rows = []
    for slug, vec in zip(slugs, vectors):
        vec_literal = "[" + ",".join(repr(float(x)) for x in vec) + "]"
        rows.append((slug, vec_literal))
    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO focus_embeddings (focus_slug, embedding)
            VALUES (%s, %s::vector)
            ON CONFLICT (focus_slug) DO UPDATE SET embedding = EXCLUDED.embedding
            """,
            rows,
        )
    conn.commit()


def upsert_tags(conn, book: str, chapter: int, verse: int, tags: list[dict]) -> int:
    """Insert validated tag rows for one verse. Returns count written.

    review_status is ALWAYS 'pending' for AI-sourced tags, regardless of the
    model's stated confidence. Confidence is stored for reference/sorting,
    but it is not a reliable signal of theological correctness (see the
    keyword-driven mis-tagging cases in TAGGING_SYSTEM_PROMPT's GOOD VS. BAD
    examples — those were all reported at confidence=0.85). Promotion from
    'pending' to 'approved' happens only through a separate human/editorial
    review pass, never automatically here.
    """
    if not tags:
        return 0
    rows = [
        (
            book, chapter, verse,
            t["focus_slug"], t.get("emotion"), t.get("tone"), t.get("maturity"),
            t.get("theme"), t["confidence"],
            "pending",  # never auto-approve; see docstring above
        )
        for t in tags
    ]
    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO verse_tags
                (book, chapter, verse, focus_slug, emotion, tone, maturity,
                 theme, source, confidence, review_status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'ai', %s, %s)
            ON CONFLICT (book, chapter, verse, focus_slug, source) DO UPDATE SET
                emotion = EXCLUDED.emotion,
                tone = EXCLUDED.tone,
                maturity = EXCLUDED.maturity,
                theme = EXCLUDED.theme,
                confidence = EXCLUDED.confidence,
                review_status = EXCLUDED.review_status
            """,
            rows,
        )
    return len(rows)


def mark_progress(conn, book: str, chapter: int, verse: int, tag_count: int) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO ai_tag_progress (book, chapter, verse, tag_count)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (book, chapter, verse)
            DO UPDATE SET tag_count = EXCLUDED.tag_count, checked_at = now()
            """,
            (book, chapter, verse, tag_count),
        )


# ============================================================================
# Validation — the model MUST only use the controlled vocab; anything else
# is dropped here rather than trusted.
# ============================================================================

def validate_tag(raw: dict) -> dict | None:
    focus_slug = raw.get("focus_slug")
    if focus_slug not in FOCUS_SLUGS:
        return None
    emotion = raw.get("emotion")
    if emotion is not None and emotion not in EMOTIONS:
        emotion = None
    tone = raw.get("tone")
    if tone is not None and tone not in TONES:
        tone = None
    maturity = raw.get("maturity")
    if maturity is not None and maturity not in MATURITIES:
        maturity = None
    try:
        confidence = float(raw.get("confidence", 0.5))
    except (TypeError, ValueError):
        confidence = 0.5
    confidence = max(0.0, min(1.0, confidence))
    theme = raw.get("theme")
    if theme is not None:
        theme = str(theme)[:200]
    return {
        "focus_slug": focus_slug,
        "emotion": emotion,
        "tone": tone,
        "maturity": maturity,
        "theme": theme,
        "confidence": confidence,
    }


# ============================================================================
# Phase 1: Embeddings
# ============================================================================

def run_focus_embedding_phase(conn, client: OpenAI, stats: Stats) -> None:
    """Embed the 24 focus_areas into focus_embeddings (migration 0013). Cheap
    (24 rows, a single API call) and always run as part of the embed phase;
    resumable via fetch_focus_areas_needing_embedding's LEFT JOIN filter, so
    re-running the script never re-embeds a focus area that already has a
    row."""
    rows = fetch_focus_areas_needing_embedding(conn)
    if not rows:
        log.info("FOCUS EMBEDDINGS: nothing to do — all 24 focus areas already embedded.")
        return
    log.info("FOCUS EMBEDDINGS: %d focus area(s) need embedding (model=%s).", len(rows), EMBED_MODEL)

    slugs = [r["slug"] for r in rows]
    texts = [FOCUS_AREA_DESCRIPTIONS.get(r["slug"], r["label"]) for r in rows]

    try:
        resp = call_with_retries(
            lambda: client.embeddings.create(model=EMBED_MODEL, input=texts),
            what=f"embeddings.create (focus areas, batch of {len(texts)})",
        )
    except Exception as exc:  # noqa: BLE001
        stats.embed_batches_failed += 1
        log.error("FOCUS EMBEDDINGS: batch failed after retries, skipping: %s", exc)
        return

    vectors = [d.embedding for d in resp.data]
    try:
        upsert_focus_embeddings(conn, slugs, vectors)
    except Exception as exc:  # noqa: BLE001
        conn.rollback()
        stats.embed_batches_failed += 1
        log.error("FOCUS EMBEDDINGS: DB upsert failed, skipping: %s", exc)
        return

    if getattr(resp, "usage", None):
        stats.embed_tokens += resp.usage.total_tokens
    stats.focus_areas_embedded += len(rows)
    log.info("FOCUS EMBEDDINGS: embedded %d focus area(s).", len(rows))


def run_embedding_phase(conn, client: OpenAI, limit: int | None, stats: Stats) -> None:
    run_focus_embedding_phase(conn, client, stats)

    verses = fetch_verses_needing_embedding(conn, limit)
    total = len(verses)
    if total == 0:
        log.info("EMBEDDINGS: nothing to do — all %s BSB verses already embedded.", TRANSLATION)
        return
    log.info("EMBEDDINGS: %d verses need embedding (model=%s).", total, EMBED_MODEL)

    done = 0
    for batch in chunked(verses, EMBED_BATCH_SIZE):
        texts = [v["text"] for v in batch]
        try:
            resp = call_with_retries(
                lambda: client.embeddings.create(model=EMBED_MODEL, input=texts),
                what=f"embeddings.create (batch of {len(texts)})",
            )
        except Exception as exc:  # noqa: BLE001
            stats.embed_batches_failed += 1
            log.error(
                "EMBEDDINGS: batch of %d verses failed after retries, skipping: %s",
                len(batch), exc,
            )
            continue

        vectors = [d.embedding for d in resp.data]
        try:
            upsert_embeddings(conn, batch, vectors)
        except Exception as exc:  # noqa: BLE001
            conn.rollback()
            stats.embed_batches_failed += 1
            log.error("EMBEDDINGS: DB upsert failed for batch, skipping: %s", exc)
            continue

        if getattr(resp, "usage", None):
            stats.embed_tokens += resp.usage.total_tokens
        stats.verses_embedded += len(batch)
        done += len(batch)
        log.info(
            "embedded %d/%d (running embed cost ~$%.4f)",
            done, total, stats.embed_cost(),
        )


# ============================================================================
# Phase 2: Tagging
# ============================================================================

def _verse_ref_key(book: str, chapter: int, verse: int) -> tuple:
    return (book, int(chapter), int(verse))


def run_tagging_phase(conn, client: OpenAI, limit: int | None, stats: Stats) -> None:
    has_progress_table = ensure_progress_table(conn)
    verses = fetch_verses_needing_tags(conn, limit, has_progress_table)
    total = len(verses)
    if total == 0:
        log.info("TAGGING: nothing to do — all %s BSB verses already AI-tagged.", TRANSLATION)
        return
    log.info("TAGGING: %d verses need tagging (model=%s).", total, TAG_MODEL)

    done = 0
    for batch in chunked(verses, TAG_BATCH_SIZE):
        by_key = {_verse_ref_key(v["book"], v["chapter"], v["verse"]): v for v in batch}
        payload = [
            {"ref": f'{v["book"]} {v["chapter"]}:{v["verse"]}',
             "book": v["book"], "chapter": v["chapter"], "verse": v["verse"],
             "text": v["text"]}
            for v in batch
        ]
        messages = [
            {"role": "system", "content": TAGGING_SYSTEM_PROMPT},
            {"role": "user", "content": json.dumps({"verses": payload}, ensure_ascii=False)},
        ]

        try:
            resp = call_with_retries(
                lambda: client.chat.completions.create(
                    model=TAG_MODEL,
                    messages=messages,
                    response_format={"type": "json_object"},
                    temperature=0,
                ),
                what=f"chat.completions.create (batch of {len(batch)})",
            )
        except Exception as exc:  # noqa: BLE001
            stats.tag_batches_failed += 1
            log.error(
                "TAGGING: batch of %d verses failed after retries, skipping "
                "(will retry on next --resume run): %s",
                len(batch), exc,
            )
            continue

        if getattr(resp, "usage", None):
            stats.tag_input_tokens += resp.usage.prompt_tokens or 0
            stats.tag_output_tokens += resp.usage.completion_tokens or 0

        raw_content = resp.choices[0].message.content
        try:
            parsed = json.loads(raw_content)
            results = parsed.get("results", [])
            if not isinstance(results, list):
                raise ValueError("'results' is not a list")
        except Exception as exc:  # noqa: BLE001
            stats.tag_batches_failed += 1
            log.error(
                "TAGGING: could not parse model JSON for batch of %d verses, "
                "skipping (will retry on next --resume run): %s",
                len(batch), exc,
            )
            continue

        seen_keys: set = set()
        batch_tags_written = 0
        for entry in results:
            try:
                key = _verse_ref_key(entry["book"], entry["chapter"], entry["verse"])
            except (KeyError, TypeError, ValueError):
                log.warning("TAGGING: dropping malformed result entry: %r", entry)
                continue
            if key not in by_key:
                log.warning("TAGGING: model returned unrequested verse %s, ignoring.", key)
                continue
            seen_keys.add(key)

            raw_tags = entry.get("tags") or []
            valid_tags = []
            for raw_tag in raw_tags:
                validated = validate_tag(raw_tag)
                if validated is None:
                    stats.tags_dropped_invalid += 1
                    log.debug("TAGGING: dropped invalid tag %r for %s", raw_tag, key)
                    continue
                valid_tags.append(validated)

            book, chapter, verse = key
            try:
                written = upsert_tags(conn, book, chapter, verse, valid_tags)
                if has_progress_table:
                    mark_progress(conn, book, chapter, verse, len(valid_tags))
                conn.commit()
            except Exception as exc:  # noqa: BLE001
                conn.rollback()
                log.error("TAGGING: DB write failed for %s, skipping: %s", key, exc)
                continue
            batch_tags_written += written
            stats.tags_written += written
            stats.verses_considered_for_tagging += 1

        missing = set(by_key) - seen_keys
        if missing:
            log.warning(
                "TAGGING: model omitted %d/%d verses from this batch's response; "
                "they will be retried on the next --resume run: %s",
                len(missing), len(batch), sorted(missing),
            )

        done += len(seen_keys)
        log.info(
            "tagged %d/%d verses considered, %d tags written this batch "
            "(running tag cost ~$%.4f)",
            done, total, batch_tags_written, stats.tag_cost(),
        )


# ============================================================================
# Entry point
# ============================================================================

def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Embed and AI-tag the whole Bible (BSB) for Crossed Out.",
    )
    p.add_argument(
        "--limit", type=int, default=None,
        help="Only process the first N not-yet-processed verses per phase "
             "(cheap test run, e.g. --limit 200).",
    )
    p.add_argument(
        "--embed-only", action="store_true",
        help="Run only the embeddings phase.",
    )
    p.add_argument(
        "--tag-only", action="store_true",
        help="Run only the tagging phase.",
    )
    p.add_argument(
        "--resume", action="store_true",
        help="No-op flag: resuming from prior progress is always the default "
             "behavior (idempotent upserts + NOT EXISTS filtering on both "
             "phases). Present so invocations can be explicit about intent.",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_arg_parser().parse_args(argv)

    if args.embed_only and args.tag_only:
        log.error("--embed-only and --tag-only are mutually exclusive.")
        return 2

    if not OPENAI_API_KEY:
        log.error("OPENAI_API_KEY is not set. See scripts/README.md.")
        return 2

    client_kwargs = {"api_key": OPENAI_API_KEY}
    if OPENAI_BASE_URL:
        client_kwargs["base_url"] = OPENAI_BASE_URL
    client = OpenAI(**client_kwargs)

    stats = Stats()
    start = time.time()

    conn = get_connection()
    try:
        if not args.tag_only:
            run_embedding_phase(conn, client, args.limit, stats)
        if not args.embed_only:
            run_tagging_phase(conn, client, args.limit, stats)
    finally:
        conn.close()

    elapsed = time.time() - start
    log.info("=" * 72)
    log.info("SUMMARY")
    log.info("  verses embedded this run   : %d", stats.verses_embedded)
    log.info("  focus areas embedded       : %d", stats.focus_areas_embedded)
    log.info("  verses tagged this run     : %d", stats.verses_considered_for_tagging)
    log.info("  tag rows written/updated   : %d", stats.tags_written)
    log.info("  invalid tags dropped       : %d", stats.tags_dropped_invalid)
    log.info("  embed batches failed       : %d", stats.embed_batches_failed)
    log.info("  tag batches failed         : %d", stats.tag_batches_failed)
    log.info("  approx embedding cost      : $%.4f", stats.embed_cost())
    log.info("  approx tagging cost        : $%.4f", stats.tag_cost())
    log.info("  approx total cost this run : $%.4f", stats.total_cost())
    log.info("  elapsed time               : %.1fs", elapsed)
    log.info("=" * 72)
    return 0


if __name__ == "__main__":
    sys.exit(main())
