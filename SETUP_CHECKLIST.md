# Deploy checklist — run before going forward

All steps run on YOUR MAC (Terminal / browser / Xcode). Nothing in the cloud session.
Do the phases in order; the ordering matters (noted where it does).

## Phase 0 — Terminal setup
Where: **Terminal**
```
cd ~/Projects/Crossed*/
supabase login            # if not already logged in (needed for the deploy scripts)
```

## Phase 1 — Rotate secrets FIRST (so the deploys pick up the new key)
Where: **browser + a text editor**
1. OpenAI key — platform.openai.com → API keys → create a new key, then revoke the old one.
   Update the local env file:
   ```
   open -e supabase/.env.local        # set OPENAI_API_KEY=<new key>, save
   ```
2. DB password — Supabase dashboard → Settings → Database → **Reset database password**.
   Use an **alphanumeric-only** password (avoids URL-encoding issues in the connection string).
   Update the local env file:
   ```
   open -e scripts/.env.run           # put the new password into DATABASE_URL, save
   ```
   (Both files are git-ignored — nothing to commit.)

## Phase 2 — Apply migrations (Supabase SQL Editor)
Where: **Terminal** (to copy) + **Supabase dashboard → SQL Editor** (to paste + Run).
Run each `pbcopy` in Terminal, then paste into a new SQL Editor query and click Run.
Apply IN THIS ORDER (0016 before 0017; 0007/0008 are idempotent):
```
pbcopy < supabase/migrations/0007_require_auth.sql
pbcopy < supabase/migrations/0008_kyra_usage.sql
pbcopy < supabase/migrations/0016_devotionals.sql
pbcopy < supabase/migrations/0017_devotional_reroll_and_ai.sql
pbcopy < supabase/migrations/0018_church_streaming.sql
```
Verify (SQL Editor): tables `devotionals`, `user_devotionals`, `devotional_feedback`,
`devotional_ai_usage`, `kyra_usage` exist; `churches` has the new streaming columns
and ~6 seed rows; `devotionals` has 3 seed rows.

## Phase 3 — Deploy the edge functions (they pick up the rotated OpenAI key)
Where: **Terminal**
```
./supabase/deploy_devotional_suggest.sh
./supabase/deploy_kyra.sh
```
Optional caps:
```
supabase secrets set DEVO_DAILY_LIMIT=5 DEVO_MODEL=gpt-4o-mini --project-ref wqumwxoiqsiwizlftojq
supabase secrets set KYRA_DAILY_LIMIT=30 --project-ref wqumwxoiqsiwizlftojq
```

## Phase 4 — Finish P0-1 auth hardening (dashboard toggles)
Where: **Supabase dashboard → Authentication**
1. Turn OFF "Allow anonymous sign-ins."
2. Providers → Apple → enable → authorized client ID `com.tdocks.crossedout` (no secret needed).

## Phase 5 — Build the app
Where: **Terminal**, then **Xcode**
```
xcodegen generate          # pulls the new Swift files into the project
open CrossedOut.xcodeproj
```
Build & run on an iPhone simulator (or device for Sign in with Apple).

## Phase 6 — Smoke test
- Fresh email signup → onboarding → auth gate satisfied. Sign out → auth gate blocks. No anon path.
- Delete Account (Settings) works; signing back in is rejected.
- Kyra replies; exceed the cap → "daily limit" (429).
- Today: verse "Show me another verse" re-rolls; "Today's Devotional" card opens the hub;
  floating Kyra button opens chat; Reflect → Kyra → "Back" returns cleanly; swipe between tabs.
- Devotionals: today's devotional, "Show me another", "Ask AI for one" → suggestion → save;
  independent-study composer saves; "helpful?" works on both.
- Attend: Live Now shows real churches; tap → Watch Live opens the in-app YouTube player
  (Life.Church/Elevation) or links out (others); Save Church persists.

## Notes
- `.env.local` / `.env.run` are git-ignored — no commit needed after editing them.
- The YouTube embed reflects real live status: if a channel isn't actually live when you test,
  the player shows offline/upcoming — that's correct, not a bug.
