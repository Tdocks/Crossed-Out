#!/usr/bin/env python3
"""verify_review.py — read-only report on the state of the AI tag review.

Self-contained: reads DATABASE_URL from scripts/.env.run (same file run.sh
uses), connects read-only, and prints:
  1) counts by review_status (+ whether anything is still pending)
  2) 8 targeted flip checks (verses that SHOULD now be approved / rejected)
  3) per-focus approved/rejected rates
  4) a stratified sample of approved & rejected rows for eyeballing

No secrets are printed. Run AFTER ./scripts/run.sh review finishes:
    .venv/bin/python scripts/verify_review.py
"""
from __future__ import annotations
import os, sys, pathlib

def load_database_url() -> str:
    if os.environ.get("DATABASE_URL"):
        return os.environ["DATABASE_URL"]
    here = pathlib.Path(__file__).resolve().parent
    envf = here / ".env.run"
    if envf.exists():
        for line in envf.read_text().splitlines():
            line = line.strip()
            if line.startswith("DATABASE_URL="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    sys.exit("DATABASE_URL not found (env or scripts/.env.run)")

try:
    import psycopg
    from psycopg.rows import dict_row
except ImportError:
    sys.exit("psycopg missing — run ./scripts/run.sh review once first (it installs deps).")

TRANSLATION = "BSB"

# (book, chapter, verse, focus_slug, expected_after_review)
FLIP_CHECKS = [
    ("Matthew", 6, 30, "anxiety", "approved"),
    ("Acts", 17, 11, "understanding_the_bible", "approved"),
    ("Titus", 2, 2, "discipline", "approved"),
    ("Hebrews", 10, 36, "motivation", "approved"),
    ("Genesis", 35, 11, "purpose", "rejected"),
    ("Esther", 5, 13, "anger", "rejected"),
    ("Isaiah", 62, 5, "marriage", "rejected"),
    ("Genesis", 9, 1, "parenting", "rejected"),
]

def main() -> int:
    url = load_database_url()
    conn = psycopg.connect(url, row_factory=dict_row, connect_timeout=20)
    cur = conn.cursor()

    print("=" * 68)
    print("AI TAG REVIEW — STATE REPORT")
    print("=" * 68)

    cur.execute("""select review_status, count(*) n from public.verse_tags
                   where source='ai' group by 1 order by 1""")
    rows = cur.fetchall()
    tot = sum(r["n"] for r in rows) or 1
    print("\n1) AI tags by review_status:")
    pending = 0
    for r in rows:
        st = r["review_status"] or "NULL"
        if st == "pending":
            pending = r["n"]
        print(f"   {st:10} {r['n']:6}  ({r['n']/tot*100:5.1f}%)")
    print(f"   {'TOTAL':10} {tot:6}")
    if pending:
        print(f"\n   ** {pending} tags STILL PENDING — the review isn't finished.")
        print("      Re-run:  ./scripts/run.sh review   (it resumes where it left off)")
    else:
        print("\n   ** 0 pending — review is COMPLETE.")

    print("\n2) Targeted flip checks (does the reviewer now agree?):")
    ok = 0
    for book, ch, vs, focus, expected in FLIP_CHECKS:
        cur.execute("""select review_status, review_note from public.verse_tags
                       where source='ai' and book=%s and chapter=%s and verse=%s
                         and focus_slug=%s
                       order by created_at limit 1""",
                    (book, ch, vs, focus))
        row = cur.fetchone()
        got = (row["review_status"] if row else "MISSING")
        mark = "OK " if got == expected else "XX "
        if got == expected:
            ok += 1
        note = (row["review_note"][:70] if row and row.get("review_note") else "")
        print(f"   {mark} {book} {ch}:{vs:<3} {focus:<24} want={expected:<8} got={got:<8}")
        if note:
            print(f"        note: {note}")
    print(f"   --> {ok}/{len(FLIP_CHECKS)} flip checks match expectation")

    print("\n3) Per-focus approved / rejected (reviewed rows only):")
    cur.execute("""select focus_slug,
                     count(*) filter (where review_status='approved') a,
                     count(*) filter (where review_status='rejected') r
                   from public.verse_tags
                   where source='ai' and review_status in ('approved','rejected')
                   group by focus_slug order by focus_slug""")
    for r in cur.fetchall():
        tf = r["a"] + r["r"]
        pct = (r["r"] / tf * 100) if tf else 0
        print(f"   {r['focus_slug']:<26} {r['a']:5} / {r['r']:5}   ({pct:4.0f}% rejected)")

    for label, status in (("APPROVED", "approved"), ("REJECTED", "rejected")):
        print(f"\n4) Sample of 12 {label} tags (spot-check quality):")
        cur.execute("""select vt.book, vt.chapter, vt.verse, vt.focus_slug,
                              vt.emotion, vt.tone, vt.review_note, bv.text
                       from public.verse_tags vt
                       join public.bible_verses bv on bv.translation=%s
                         and bv.book=vt.book and bv.chapter=vt.chapter and bv.verse=vt.verse
                       where vt.source='ai' and vt.review_status=%s
                       order by md5(vt.id::text) limit 12""", (TRANSLATION, status))
        for r in cur.fetchall():
            ref = f"{r['book']} {r['chapter']}:{r['verse']}"
            txt = (r["text"] or "")[:80].replace("\n", " ")
            print(f"   [{r['focus_slug']}/{r['emotion']}/{r['tone']}] {ref}: {txt}")
            if r.get("review_note"):
                print(f"       -> {r['review_note'][:90]}")
    conn.close()
    return 0

if __name__ == "__main__":
    sys.exit(main())
