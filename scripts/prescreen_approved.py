#!/usr/bin/env python3
"""prescreen_approved.py — tightened re-screen of ALREADY-APPROVED AI tags.

Purpose: the strict reviewer (review_tags.py) is excellent at rejecting the
harmful misfires (villain speech, bare narration, covenant-misapplication),
but a small number of *loose approves* survive in the high-volume /
low-rejection categories — verses whose tie to the focus rests on a shared
word or a doctrinal statement mislabeled as practical instruction (e.g.
James 2:24 'justified by works, not faith alone' tagged as 'discipline').

This script re-judges ONLY currently-approved source='ai' tags in the target
focus areas, applying the normal reviewer rules PLUS one added rule 9
(topic-mismatch / doctrine-as-practice). It is READ-ONLY against the DB: it
never changes review_status. Instead it writes:
  - /tmp/co_prescreen_flagged.csv  — the tags it thinks should flip to
    'rejected', with verse text + old note + the new reason, for you to
    hand-review.
  - /tmp/co_prescreen_reject.sql   — a ready-to-run UPDATE that rejects
    exactly those flagged rows (apply all, or edit down after review).

Nothing goes live until you (or Claude, on your say-so) run that SQL.

USAGE
  .venv/bin/python scripts/prescreen_approved.py
  .venv/bin/python scripts/prescreen_approved.py --focus understanding_god discipline
  .venv/bin/python scripts/prescreen_approved.py --all-low-rejection
"""
from __future__ import annotations
import argparse, concurrent.futures, csv, itertools, json, os, pathlib, sys, time, random

try:
    import psycopg
    from psycopg.rows import dict_row
    from openai import OpenAI
except ImportError:
    sys.exit("Missing deps. Run ./scripts/run.sh review once first (it installs openai + psycopg).")

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent

def _load_kv(path: pathlib.Path, key: str) -> str | None:
    if not path.exists():
        return None
    for line in path.read_text().splitlines():
        line = line.strip()
        if line.startswith(key + "="):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    return None

DATABASE_URL = os.environ.get("DATABASE_URL") or _load_kv(HERE / ".env.run", "DATABASE_URL")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY") or _load_kv(REPO / "supabase" / ".env.local", "OPENAI_API_KEY")
REVIEW_MODEL = os.environ.get("REVIEW_MODEL") or _load_kv(HERE / ".env.run", "REVIEW_MODEL") or "gpt-5.2"
REASONING_EFFORT = os.environ.get("REASONING_EFFORT", "low")
if not DATABASE_URL:
    sys.exit("DATABASE_URL not found (env or scripts/.env.run).")
if not OPENAI_API_KEY:
    sys.exit("OPENAI_API_KEY not found (env or supabase/.env.local).")

TRANSLATION = "BSB"
BATCH_SIZE = 18
CONCURRENCY = int(os.environ.get("PRESCREEN_CONCURRENCY", "8"))
MAX_TOKENS = 4000
# Default targets = the high-volume / low-rejection categories where loose
# approves are most likely to hide (per the two-auditor sample audit).
DEFAULT_FOCUSES = ["understanding_god", "understanding_the_bible", "discipline"]
LOW_REJECTION_FOCUSES = DEFAULT_FOCUSES + ["rest_peace", "temptation", "confidence", "motivation"]

# Reuse the exact base reviewer rubric + helpers so we stay in sync with
# review_tags.py, then bolt on the one added rule this pre-screen targets.
from review_tags import (
    REVIEWER_SYSTEM_PROMPT as BASE_PROMPT,
    _model_is_reasoning,
    call_with_retries,
    chunked,
)

ADDED_RULE_9 = """

--- ADDED RULE 9 (this pre-screen only) — TOPIC MISMATCH / DOCTRINE-AS-PRACTICE ---
These tags were already approved once; you are re-checking specifically for
one leak: a verse whose real subject is a DIFFERENT topic than the focus,
where the match rests on shared vocabulary or surface theme rather than the
verse's actual point. REJECT in these cases even if the verse is sound
Scripture:

9a. DOCTRINE MISLABELED AS PRACTICE. A doctrinal/theological statement
    (justification, faith vs. works, election, the nature/finished work of
    Christ, eschatology) tagged onto a PRACTICAL, experiential focus such as
    discipline, motivation, confidence, or rest_peace. Example: James 2:24
    ("justified by works and not by faith alone") tagged 'discipline' — that
    is a soteriology statement, not self-control instruction. REJECT.

9b. INCIDENTAL-KEYWORD / SITUATION-BOUND. A verse whose real context is a
    narrow, situation-specific matter (food sacrificed to idols, a single
    quarrel, a legal statute) tagged as a broad focus like
    understanding_the_bible or understanding_god because of one incidental
    word. Example: 1 Corinthians 8:1 ("knowledge puffs up") tagged
    understanding_the_bible — its subject is idol-food and love, not Bible
    study. REJECT unless the transferable principle is genuinely the verse's
    own main point.

9c. PARTIAL-CONTEXT / DANGLING PROMISE. A verse read as comfort or a promise
    only because the actual condition, antecedent pronoun, or resolving
    clause lives in an adjacent verse not shown. If, read alone, the tag's
    claim isn't actually carried by THIS verse's words, REJECT.

THE CORE QUESTION for this pass: is the FOCUS the verse's own subject, or
just adjacent vocabulary? If adjacent, REJECT. Otherwise KEEP (approve).
When a tag is genuinely on-point, approve it — do not manufacture rejections.
"""

TIGHTENED_PROMPT = BASE_PROMPT + ADDED_RULE_9

def fetch_approved(conn, focuses: list[str]) -> list[dict]:
    sql = """
        SELECT vt.id, vt.book, vt.chapter, vt.verse, vt.focus_slug,
               vt.emotion, vt.tone, vt.review_note, bv.text
        FROM public.verse_tags vt
        JOIN public.bible_verses bv
          ON bv.translation=%s AND bv.book=vt.book
         AND bv.chapter=vt.chapter AND bv.verse=vt.verse
        WHERE vt.source='ai' AND vt.review_status='approved'
          AND vt.focus_slug = ANY(%s)
        ORDER BY vt.focus_slug, vt.book, vt.chapter, vt.verse
    """
    with conn.cursor() as cur:
        cur.execute(sql, [TRANSLATION, focuses])
        return cur.fetchall()

def judge_batch(client: OpenAI, batch: list[dict]) -> list[dict]:
    by_index = {i: row for i, row in enumerate(batch)}
    payload = [{"index": i, "ref": f'{r["book"]} {r["chapter"]}:{r["verse"]}',
                "verse_text": r["text"], "focus_slug": r["focus_slug"],
                "emotion": r["emotion"], "tone": r["tone"]} for i, r in by_index.items()]
    params = {"model": REVIEW_MODEL,
              "messages": [{"role": "system", "content": TIGHTENED_PROMPT},
                           {"role": "user", "content": json.dumps({"items": payload}, ensure_ascii=False)}],
              "response_format": {"type": "json_object"}}
    if _model_is_reasoning(REVIEW_MODEL):
        params["max_completion_tokens"] = MAX_TOKENS
        params["reasoning_effort"] = REASONING_EFFORT
    else:
        params["max_tokens"] = MAX_TOKENS
        params["temperature"] = 0
    resp = call_with_retries(lambda: client.chat.completions.create(**params), what="prescreen batch")
    results = json.loads(resp.choices[0].message.content).get("results", [])
    flags = []
    for e in results:
        try:
            idx = int(e["index"]); approve = bool(e["approve"])
        except (KeyError, TypeError, ValueError):
            continue
        if idx in by_index and not approve:
            row = dict(by_index[idx])
            row["prescreen_reason"] = str(e.get("reason") or "").strip()[:400]
            flags.append(row)
    return flags

def main() -> int:
    ap = argparse.ArgumentParser(description="Read-only tightened re-screen of approved AI tags.")
    ap.add_argument("--focus", nargs="+", help="focus_slugs to screen (default: 3 high-risk categories)")
    ap.add_argument("--all-low-rejection", action="store_true", help="screen the wider low-rejection set")
    ap.add_argument("--limit", type=int, default=None, help="cap rows (test run)")
    ap.add_argument("--apply", metavar="SQLFILE",
                    help="apply a reviewed reject SQL file to the DB and exit (no re-screen)")
    args = ap.parse_args()

    if args.apply:
        sql = pathlib.Path(args.apply).read_text()
        conn = psycopg.connect(DATABASE_URL, autocommit=True, connect_timeout=20)
        with conn.cursor() as cur:
            cur.execute(sql)
            cur.execute("select count(*) from public.verse_tags where source='ai' "
                        "and review_status='rejected' and review_note like '[prescreen]%'")
            total = cur.fetchone()[0]
        conn.close()
        print(f"Applied {args.apply}. Total prescreen-rejected tags now: {total}")
        return 0

    focuses = args.focus or (LOW_REJECTION_FOCUSES if args.all_low_rejection else DEFAULT_FOCUSES)

    client = OpenAI(api_key=OPENAI_API_KEY)
    conn = psycopg.connect(DATABASE_URL, row_factory=dict_row, connect_timeout=20)
    rows = fetch_approved(conn, focuses)
    if args.limit:
        rows = rows[:args.limit]
    print(f"Pre-screening {len(rows)} approved tags in: {', '.join(focuses)}  (model={REVIEW_MODEL})")
    if not rows:
        print("Nothing to screen."); return 0

    batches = list(chunked(rows, BATCH_SIZE))
    flagged: list[dict] = []
    done = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=CONCURRENCY) as ex:
        futs = {ex.submit(judge_batch, client, b): b for b in batches}
        for fut in concurrent.futures.as_completed(futs):
            try:
                flagged.extend(fut.result())
            except Exception as exc:
                print(f"  batch failed (skipped, its rows stay approved): {exc}", file=sys.stderr)
            done += len(futs[fut])
            print(f"  screened {done}/{len(rows)}  ({len(flagged)} flagged so far)")
    conn.close()

    csv_path = "/tmp/co_prescreen_flagged.csv"
    sql_path = "/tmp/co_prescreen_reject.sql"
    with open(csv_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["book", "chapter", "verse", "focus_slug", "emotion", "tone",
                    "verse_text", "old_review_note", "prescreen_reason"])
        for r in flagged:
            w.writerow([r["book"], r["chapter"], r["verse"], r["focus_slug"],
                        r.get("emotion"), r.get("tone"), (r["text"] or "")[:300],
                        (r.get("review_note") or "")[:300], r["prescreen_reason"]])
    with open(sql_path, "w") as f:
        f.write("-- Reject the flagged loose-approve tags. Review the CSV first;\n")
        f.write("-- delete any line you DISAGREE with before running.\n")
        f.write("begin;\n")
        for r in flagged:
            note = r["prescreen_reason"].replace("'", "''")
            f.write(
                "update public.verse_tags set review_status='rejected', "
                f"review_note='[prescreen] {note}' where id='{r['id']}' "
                "and source='ai' and review_status='approved';\n")
        f.write("commit;\n")

    by_focus: dict = {}
    for r in flagged:
        by_focus[r["focus_slug"]] = by_focus.get(r["focus_slug"], 0) + 1
    print("\n" + "=" * 60)
    print(f"FLAGGED {len(flagged)} / {len(rows)} approved tags for your review")
    for fslug in sorted(by_focus):
        print(f"   {fslug:<26} {by_focus[fslug]}")
    print(f"\n  CSV to review : {csv_path}")
    print(f"  SQL to apply  : {sql_path}  (only after you've reviewed the CSV)")
    print("=" * 60)
    return 0

if __name__ == "__main__":
    sys.exit(main())
