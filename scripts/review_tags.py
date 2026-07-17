#!/usr/bin/env python3
"""
review_tags.py — Second-pass reviewer for AI-generated verse_tags.

WHAT THIS DOES
--------------
tag_bible.py's tagging phase writes verse_tags rows with source='ai' and
review_status='pending' — the tagging model is known to make keyword-driven
mistakes (e.g. tagging a character's despair after judgment, or God's own
emotion, as personal "grief/comfort" for the reader; tagging tone='comfort'
onto confrontation, warning, or fear-depicting verses). This script is a
STRICT second opinion: it re-reads each pending AI tag against the verse
text and either promotes it to review_status='approved' (a sound,
reader-facing tag) or demotes it to review_status='rejected' (a
misapplication), recording why in the new review_note column (migration
0015_review_notes.sql).

Only rows where source='ai' AND review_status='pending' are ever selected.
source='curated' rows are never touched by this script — they were seeded
in migration 0012 already 'approved' and stay that way. source='rule' rows
are likewise untouched (out of scope for this pass).

This is a REVIEW pass, not a tagging pass: it does not invent new tags, add
new focus areas, or change focus_slug/emotion/tone/maturity/theme/confidence
— it only flips review_status and writes review_note.

RESUMABILITY
------------
Idempotent and safe to re-run at any time: the only rows ever selected are
WHERE source='ai' AND review_status='pending'. Once a row is
approved/rejected it is never selected again on a future run, so re-running
this script after a crash, Ctrl-C, or to catch newly-tagged verses from a
later tag_bible.py run is always safe — it just picks up wherever it left
off. A batch that fails (API error, malformed JSON, DB error) is logged and
skipped; those rows stay 'pending' and are retried on the next run.

USAGE
-----
  python3 scripts/review_tags.py                # full resumable review run
  python3 scripts/review_tags.py --limit 200     # cheap test run, first 200 tags

ENVIRONMENT VARIABLES
----------------------
  DATABASE_URL     required. Postgres connection string (Supabase session
                    pooler recommended — see scripts/README.md).
  OPENAI_API_KEY   required.
  OPENAI_BASE_URL  optional. Point at a self-hosted / alternate OpenAI-compatible
                    endpoint. Defaults to OpenAI's own API.
  REVIEW_MODEL     optional. Default: gpt-4o-mini. A stronger model (e.g.
                    gpt-4o, gpt-4.1) gives better theological judgment on
                    borderline cases at higher cost — consider using one for
                    the real review pass even if gpt-4o-mini was used for
                    initial tagging, since precision matters more here than
                    in the first pass. Must support response_format=
                    json_object.
  REVIEW_CONCURRENCY  optional. Default: 8. Number of review batches sent to
                    the OpenAI chat API concurrently via a
                    ThreadPoolExecutor. The review phase is API-latency-bound
                    (not CPU/DB-bound), so running N batches in flight at
                    once gives roughly an Nx wall-clock speedup. DB writes
                    stay single-threaded/safe — worker threads only do the
                    API call + JSON parse; all review_status/review_note
                    UPDATEs happen back on the main thread.

Review batches are dispatched to the OpenAI API concurrently
(ThreadPoolExecutor, REVIEW_CONCURRENCY workers, default 8) since the
bottleneck is the API round-trip latency, not CPU or the DB. Worker threads
do ONLY the API call + JSON parse — every DB write (the review_status +
review_note UPDATE) happens back on the main thread as results land via
concurrent.futures.as_completed(), so the single psycopg connection is
never touched from more than one thread.

See scripts/README.md for prerequisites (apply migration 0015 first), the
review workflow, and sample SQL to inspect results.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import itertools
import json
import logging
import os
import random
import sys
import time
from collections import defaultdict
from dataclasses import dataclass, field
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


TRANSLATION = "BSB"

# ============================================================================
# Config (env-driven, no hardcoded secrets)
# ============================================================================

DATABASE_URL = os.environ.get("DATABASE_URL", "")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_BASE_URL = os.environ.get("OPENAI_BASE_URL") or None
REVIEW_MODEL = os.environ.get("REVIEW_MODEL", "gpt-4o-mini")

REVIEW_BATCH_SIZE = 18  # ~15-20 tags per chat call, same convention as tag_bible.py

# The review phase is API-latency-bound, not CPU/DB-bound (each ~18-tag
# batch just waits on the OpenAI round-trip), so batches are dispatched to a
# ThreadPoolExecutor of this many workers. Each worker does ONLY the OpenAI
# call + JSON parse — no DB access happens on worker threads. All DB writes
# (the review_status/review_note UPDATE) happen back on the main thread as
# results come in via as_completed(), keeping the single psycopg connection
# single-threaded/safe. Override via env if you hit OpenAI rate limits, or
# raise it if your account tier allows more. Same pattern as tag_bible.py's
# TAG_CONCURRENCY.
REVIEW_CONCURRENCY = int(os.environ.get("REVIEW_CONCURRENCY", "8"))

MAX_RETRIES = 5
RETRY_BASE_DELAY = 1.5  # seconds, exponential backoff w/ jitter

# Published per-token prices (USD), as constants for a running cost estimate.
# Approximate and may drift — check https://openai.com/api/pricing for
# current numbers, especially if REVIEW_MODEL is overridden.
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
log = logging.getLogger("review_tags")


# ============================================================================
# The reviewer system prompt — this is the strict second-pass gate.
# ============================================================================

REVIEWER_SYSTEM_PROMPT = """You are a STRICT second-pass reviewer for a Bible study app's AI-generated
verse tags. A separate (less careful) model has already tagged verses with
a focus_slug, and optionally an emotion and tone, claiming the verse
ministers to a reader in that situation. Your job is to catch its mistakes
before real users ever see a tag. You are the last line of defense — treat
every incoming tag as guilty until the verse text proves it innocent.

You will be given a small batch of items, each with: the verse reference,
the verse text (BSB translation), and the proposed tag (focus_slug,
emotion, tone). For EACH item, decide APPROVE or REJECT.

THE CORE TEST — OFFERS VS. MENTIONS:
Approve a tag ONLY if the verse, read in its actual context, genuinely
ministers to, instructs, or speaks TO a reader who is in that situation —
not merely because the verse contains a matching keyword or describes
something that sounds similar. Ask: does this verse offer something to a
reader carrying this focus/emotion right now, or does it merely mention,
narrate, or depict something adjacent to it? Only the former is a pass.

REJECTION RULES — REJECT the tag if any of these apply:

1. CHARACTER-IN-JUDGMENT MISREAD AS COMFORT. The verse depicts a character
   under sin, judgment, or despair — and their words or state are being
   tagged as if they were personal comfort or grief-support for the
   reader. Example: Cain's "My punishment is greater than I can bear"
   (Genesis 4:13) tagged as grief/comfort — REJECT. This is an unrepentant
   person's anguish after judgment, not a verse ministering to a grieving
   reader.

2. GOD'S OWN EMOTION MISREAD AS PERSONAL COMFORT. The verse describes
   God's own feeling (His grief, anger, jealousy, compassion as a
   narrated fact about Him) — and that is being tagged as if it directly
   comforts or addresses the reader's own matching emotion. Example: "the
   LORD was grieved in His heart" (Genesis 6:6) tagged as grief/comfort —
   REJECT. That is narration about God's grief over sin, not comfort
   offered to a grieving reader. (A verse can still be legitimately tagged
   understanding_god or similar if that's what it's actually teaching —
   the rejection is specifically about mis-tagging it as personal
   emotional comfort it does not provide.)

3. TONE=COMFORT ON CONFRONTATION, WARNING, OR FEAR-DEPICTION. tone=comfort
   requires the verse to actually console, reassure, or promise hope/
   God's nearness/deliverance. REJECT tone=comfort when the verse is
   actually a confrontation, rebuke, warning of judgment, or a plain
   depiction/narration of fear, without an accompanying promise or
   consolation. Fear being named in the text is not the same as comfort
   being offered by the text.

4. EMOTION TAG DOESN'T MATCH THE VERSE'S READER-FACING MESSAGE. The
   emotion tag (anxious, grieving, lonely, overwhelmed, hopeful, etc.)
   should describe the emotional experience the verse actually speaks to
   FOR the reader. If the verse's real subject is someone else's emotion,
   a plot event, a legal statute, or a genealogy stretched to fit, and the
   emotion tag doesn't genuinely fit the verse's own reader-facing point,
   REJECT.

5. PROOF-TEXTING / KEYWORD MATCH ONLY. If the connection between the verse
   and the focus_slug depends on a shared word or surface similarity
   rather than the verse's actual meaning in context, REJECT.

WHEN BORDERLINE, REJECT. Precision over recall: a mis-served verse shown to
a real person in crisis is worse than a missing tag. If you are genuinely
torn between approve and reject, reject. Do not give the benefit of the
doubt to a tag just because it's plausible-sounding — it must be
genuinely, contextually sound.

APPROVE freely when the tag is actually right: do not become so strict that
sound, plainly-applicable tags get rejected too. Genesis 2:24 ("a man shall
leave his father and mother and be united to his wife") tagged marriage —
APPROVE, this is genuine instruction about marriage. The goal is precision,
not zero approvals.

OUTPUT FORMAT — STRICT JSON, NOTHING ELSE:
Return a single JSON object of the shape:
{
  "results": [
    {
      "index": <same integer index you were given for this item>,
      "approve": true or false,
      "reason": "<one concise sentence: why this tag is sound, or exactly
                  which rejection rule it violates and why>"
    }
  ]
}

You MUST include exactly one entry in "results" for every item you were
given, in the same set (order does not matter as long as "index" is
correct), matched by "index". Do not add commentary, markdown, or any text
outside the JSON object.
"""


# ============================================================================
# Stats / cost tracking
# ============================================================================

@dataclass
class Stats:
    tags_considered: int = 0
    tags_approved: int = 0
    tags_rejected: int = 0
    batches_failed: int = 0
    rows_failed: int = 0
    input_tokens: int = 0
    output_tokens: int = 0
    approved_by_focus: dict = field(default_factory=lambda: defaultdict(int))
    rejected_by_focus: dict = field(default_factory=lambda: defaultdict(int))

    def cost(self) -> float:
        in_price, out_price = CHAT_PRICE_PER_1M_TOKENS.get(REVIEW_MODEL, (0.15, 0.60))
        return (self.input_tokens / 1_000_000) * in_price + (
            self.output_tokens / 1_000_000
        ) * out_price


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


def fetch_pending_ai_tags(conn, limit: int | None) -> list[dict]:
    """Only source='ai' AND review_status='pending' rows are ever selected.
    curated/rule rows and already-reviewed rows are never touched."""
    sql = """
        SELECT vt.id, vt.book, vt.chapter, vt.verse, vt.focus_slug,
               vt.emotion, vt.tone, vt.maturity, vt.theme, vt.confidence,
               bv.text
        FROM public.verse_tags vt
        JOIN public.bible_verses bv
          ON bv.translation = %s
         AND bv.book = vt.book AND bv.chapter = vt.chapter AND bv.verse = vt.verse
        WHERE vt.source = 'ai' AND vt.review_status = 'pending'
        ORDER BY vt.created_at, vt.id
    """
    params: list = [TRANSLATION]
    if limit is not None:
        sql += " LIMIT %s"
        params.append(limit)
    with conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()


def update_review(conn, tag_id: str, approve: bool, reason: str) -> None:
    status = "approved" if approve else "rejected"
    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE public.verse_tags
            SET review_status = %s, review_note = %s
            WHERE id = %s AND source = 'ai' AND review_status = 'pending'
            """,
            (status, reason, tag_id),
        )


# ============================================================================
# Review phase
# ============================================================================

def _row_ref_key(row: dict) -> str:
    return f'{row["book"]} {row["chapter"]}:{row["verse"]}'


@dataclass
class ReviewBatchResult:
    """Everything the main thread needs to write one reviewed batch to the
    DB. Produced entirely on a worker thread — no DB access involved in
    building one of these."""
    batch: list[dict]
    by_index: dict
    results: list[dict] | None  # None iff error is set
    input_tokens: int
    output_tokens: int
    error: str | None = None


def _review_one_batch(client: OpenAI, batch: list[dict]) -> ReviewBatchResult:
    """Worker function: runs on a ThreadPoolExecutor thread. Does ONLY the
    OpenAI chat call and JSON parsing — it never opens a DB cursor or
    touches `conn`. All DB writes happen back on the main thread in
    run_review_phase() once this result comes back through
    concurrent.futures.as_completed(), so the single psycopg connection is
    only ever used from one thread at a time."""
    by_index = {i: row for i, row in enumerate(batch)}
    payload = [
        {
            "index": i,
            "ref": _row_ref_key(row),
            "verse_text": row["text"],
            "focus_slug": row["focus_slug"],
            "emotion": row["emotion"],
            "tone": row["tone"],
        }
        for i, row in by_index.items()
    ]
    messages = [
        {"role": "system", "content": REVIEWER_SYSTEM_PROMPT},
        {"role": "user", "content": json.dumps({"items": payload}, ensure_ascii=False)},
    ]

    try:
        resp = call_with_retries(
            lambda: client.chat.completions.create(
                model=REVIEW_MODEL,
                messages=messages,
                response_format={"type": "json_object"},
                temperature=0,
            ),
            what=f"chat.completions.create (review batch of {len(batch)})",
        )
    except Exception as exc:  # noqa: BLE001
        return ReviewBatchResult(
            batch=batch, by_index=by_index, results=None,
            input_tokens=0, output_tokens=0,
            error=f"API call failed after retries: {exc}",
        )

    input_tokens = 0
    output_tokens = 0
    if getattr(resp, "usage", None):
        input_tokens = resp.usage.prompt_tokens or 0
        output_tokens = resp.usage.completion_tokens or 0

    raw_content = resp.choices[0].message.content
    try:
        parsed = json.loads(raw_content)
        results = parsed.get("results", [])
        if not isinstance(results, list):
            raise ValueError("'results' is not a list")
    except Exception as exc:  # noqa: BLE001
        return ReviewBatchResult(
            batch=batch, by_index=by_index, results=None,
            input_tokens=input_tokens, output_tokens=output_tokens,
            error=f"could not parse model JSON: {exc}",
        )

    return ReviewBatchResult(
        batch=batch, by_index=by_index, results=results,
        input_tokens=input_tokens, output_tokens=output_tokens,
        error=None,
    )


def run_review_phase(conn, client: OpenAI, limit: int | None, stats: Stats) -> None:
    rows = fetch_pending_ai_tags(conn, limit)
    total = len(rows)
    if total == 0:
        log.info("REVIEW: nothing to do — no pending source='ai' verse_tags rows.")
        return
    log.info("REVIEW: %d pending AI tag(s) to review (model=%s).", total, REVIEW_MODEL)

    batches = list(chunked(rows, REVIEW_BATCH_SIZE))
    log.info(
        "REVIEW: %d batch(es) queued, concurrency=%d (REVIEW_CONCURRENCY).",
        len(batches), REVIEW_CONCURRENCY,
    )

    # Workers ONLY do the OpenAI call + JSON parse (no DB access — see
    # _review_one_batch). We consume completed batches here on the main
    # thread via as_completed() and do every DB write (the review_status +
    # review_note UPDATE, commits) single-threaded, so the one psycopg
    # connection is never shared across threads. The running cost counter
    # (stats) is likewise only ever mutated here on the main thread.
    done = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=REVIEW_CONCURRENCY) as executor:
        future_to_batch = {
            executor.submit(_review_one_batch, client, batch): batch for batch in batches
        }
        for future in concurrent.futures.as_completed(future_to_batch):
            batch = future_to_batch[future]
            try:
                result = future.result()
            except Exception as exc:  # noqa: BLE001 - defensive: worker should not raise
                stats.batches_failed += 1
                log.error(
                    "REVIEW: worker crashed for batch of %d tags, skipping "
                    "(rows stay 'pending', will retry on next run): %s",
                    len(batch), exc,
                )
                continue

            stats.input_tokens += result.input_tokens
            stats.output_tokens += result.output_tokens

            if result.error is not None:
                stats.batches_failed += 1
                log.error(
                    "REVIEW: batch of %d tags failed, skipping "
                    "(rows stay 'pending', will retry on next run): %s",
                    len(result.batch), result.error,
                )
                continue

            by_index = result.by_index
            seen_indices: set = set()
            batch_approved = 0
            batch_rejected = 0
            for entry in result.results:
                try:
                    idx = int(entry["index"])
                    approve = bool(entry["approve"])
                    reason = str(entry.get("reason") or "").strip()[:500]
                except (KeyError, TypeError, ValueError):
                    log.warning("REVIEW: dropping malformed result entry: %r", entry)
                    continue
                if idx not in by_index:
                    log.warning("REVIEW: model returned unrequested index %r, ignoring.", idx)
                    continue
                if idx in seen_indices:
                    log.warning("REVIEW: model returned duplicate index %r, ignoring repeat.", idx)
                    continue
                seen_indices.add(idx)

                row = by_index[idx]
                if not reason:
                    reason = "(model gave no reason)"
                try:
                    update_review(conn, row["id"], approve, reason)
                    conn.commit()
                except Exception as exc:  # noqa: BLE001
                    conn.rollback()
                    stats.rows_failed += 1
                    log.error(
                        "REVIEW: DB update failed for %s (%s), skipping: %s",
                        _row_ref_key(row), row["focus_slug"], exc,
                    )
                    continue

                stats.tags_considered += 1
                focus = row["focus_slug"]
                if approve:
                    stats.tags_approved += 1
                    stats.approved_by_focus[focus] += 1
                    batch_approved += 1
                else:
                    stats.tags_rejected += 1
                    stats.rejected_by_focus[focus] += 1
                    batch_rejected += 1

            missing = set(by_index) - seen_indices
            if missing:
                log.warning(
                    "REVIEW: model omitted %d/%d items from this batch's response; "
                    "they stay 'pending' and will be retried on the next run: %s",
                    len(missing), len(result.batch),
                    sorted(_row_ref_key(by_index[i]) for i in missing),
                )

            done += len(seen_indices)
            log.info(
                "reviewed %d/%d tags considered (%d approved, %d rejected this "
                "batch; running cost ~$%.4f)",
                done, total, batch_approved, batch_rejected, stats.cost(),
            )


# ============================================================================
# Entry point
# ============================================================================

def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Strict second-pass reviewer for AI-generated verse_tags "
                    "(Crossed Out). Promotes sound pending tags to 'approved' "
                    "and rejects misapplications to 'rejected'.",
    )
    p.add_argument(
        "--limit", type=int, default=None,
        help="Only review the first N pending source='ai' tags (cheap test "
             "run, e.g. --limit 200).",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_arg_parser().parse_args(argv)

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
        run_review_phase(conn, client, args.limit, stats)
    finally:
        conn.close()

    elapsed = time.time() - start
    log.info("=" * 72)
    log.info("SUMMARY")
    log.info("  tags considered            : %d", stats.tags_considered)
    log.info("  tags approved              : %d", stats.tags_approved)
    log.info("  tags rejected              : %d", stats.tags_rejected)
    log.info("  batches failed             : %d", stats.batches_failed)
    log.info("  individual row DB failures : %d", stats.rows_failed)
    log.info("  approx review cost         : $%.4f", stats.cost())
    log.info("  elapsed time               : %.1fs", elapsed)
    log.info("-" * 72)
    log.info("  per focus_slug (approved / rejected):")
    all_focuses = sorted(set(stats.approved_by_focus) | set(stats.rejected_by_focus))
    for focus in all_focuses:
        a = stats.approved_by_focus.get(focus, 0)
        r = stats.rejected_by_focus.get(focus, 0)
        total_f = a + r
        pct_rejected = (r / total_f * 100) if total_f else 0.0
        log.info(
            "    %-24s %4d / %4d   (%.0f%% rejected)",
            focus, a, r, pct_rejected,
        )
    log.info("=" * 72)
    return 0


if __name__ == "__main__":
    sys.exit(main())
