# G19 — Devotional system (slice 1) — apply & build

_Built Jul 18, 2026. Foundation + independent-study + "was this helpful?" feedback._
_See GAP_ANALYSIS_AND_ROADMAP.md §7 for the full spec._

## What this slice adds
- **DB (migration `0016_devotionals.sql`):** three tables — `devotionals` (built-in
  catalog, world-readable when published), `user_devotionals` (a user's own
  "independent study" entries, RLS own-rows), `devotional_feedback` (helpful/not
  on either surface, RLS own-rows) — plus `submit_devotional_feedback()` (upsert)
  and `today_devotional()` (deterministic per-day pick), and 3 seed devotionals.
- **App:** a **Devotionals** hub (More → Devotionals) showing today's built-in
  devotional + your independent studies; a built-in **detail** view; an
  **independent-study composer** (verse + optional title + notes); and a reusable
  **"Did you find this helpful?"** control wired on BOTH surfaces.
- New files: `CrossedOut/Features/Devotionals/*` (4 files),
  `CrossedOut/Services/SupabaseService+Devotionals.swift`; edits to
  `CrossedOut/Models/Models.swift` and `CrossedOut/Features/Profile/MoreHubView.swift`.

## Apply & build
1. **Apply the migration.** It creates functions + RLS, so run it in the Supabase
   SQL editor (most reliable). Copy it to your clipboard:
   ```
   cd ~/Projects/Crossed*/ && pbcopy < supabase/migrations/0016_devotionals.sql
   ```
   Then: Supabase dashboard → SQL Editor → paste → Run. Confirm: 3 new tables and
   the 3 seed rows in `devotionals`.
2. **Regenerate the Xcode project** (new Swift files need to be added to the target):
   ```
   cd ~/Projects/Crossed*/ && xcodegen generate
   ```
3. **Build & run** `CrossedOut.xcodeproj` in Xcode (iPhone 17 sim).

## Smoke test
- More → **Devotionals**: a "Today" card renders with a real devotional.
- Tap it → read the body + Reflect prompt → tap **Helpful** / **Not for me** (should
  select + show the thank-you line, no crash).
- **Add** (or the empty-state card) → enter a verse (e.g. `Romans 8:28`) + notes →
  **Save Devotional** → it appears under **Your Studies**.
- Tap your saved study → notes render → the helpful control works there too.
- (Optional) In SQL editor: `select source, helpful, count(*) from devotional_feedback group by 1,2;`
  should show your taps.

## Not in this slice (next)
- Built-in **catalog authoring** (the seed is 3 devotionals — decide curated vs.
  AI-assisted) and a real **style taxonomy**.
- The **preference recommender**: turn `devotional_feedback` into per-user style/topic
  affinities and make `today_devotional()` / suggestions preference-aware.
- Promoting today's devotional onto the **Today tab** (currently reachable via More).
