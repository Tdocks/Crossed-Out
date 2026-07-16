# Crossed Out — Phase 1 Status & Next-Phase Plan
_Written Jul 16, 2026. Companion to HANDOFF.md._

## Phase 1 — DONE in code, NOT yet deployed
Committed locally as **`b3c7e1f`** (on top of `73758e3`, `ea1ed2d`). Build verified green (Xcode 26.5, iPhone 17 Pro sim).

What changed:
- **Anonymous auth removed entirely.** Deleted `signInAnonymouslyIfNeeded()` and the anon-linking path in `signUp`. A real account (Sign in with Apple **or** email/password) is now **required** to enter the app: onboarding ends in a mandatory auth step, and signed-out returning users hit a full-screen, non-dismissible auth gate. `CO_SCREEN` debug override still bypasses the gate for screenshots.
- **Kyra edge function hardened.** Verifies the caller's Supabase user JWT, rejects unauthenticated (`401`) and anonymous (`403`) callers, and enforces a per-user daily cap (`KYRA_DAILY_LIMIT`, default 30) returning `429`. The app's `askKyra` now forwards the user's session access token (was sending the static publishable key).
- **Migrations added (NOT applied):** `0007_require_auth.sql` (revokes all `anon` grants/policies, locks user-content tables to `authenticated`) and `0008_kyra_usage.sql` (`kyra_usage` table + atomic `increment_kyra_usage(p_limit)` RPC).

## RUNBOOK — steps only Tyler (or a computer-mode session) can run
The cloud session has no network on the device bridge and the Supabase MCP is a different account, so these are manual. **Order matters where noted.**

1. **Push to GitHub** (2 commits ahead): from the repo, `git push origin main`.
2. **Disable anonymous sign-ins** — Supabase dashboard -> Authentication -> Providers/Settings -> turn **off** "Allow anonymous sign-ins".
3. **Enable Apple provider** — Auth -> Providers -> Apple -> enable -> add authorized client ID `com.tdocks.crossedout`. (Native iOS SIWA uses the id_token flow, so only the client ID is needed — no secret.)
4. **Apply migrations BEFORE deploying the function** (0008's RPC is called by the function): `supabase db push --project-ref wqumwxoiqsiwizlftojq` (after `supabase login`), or run `0007` + `0008` via the psql session pooler. Verify `kyra_usage` and `increment_kyra_usage` exist.
5. **Deploy Kyra** — `./supabase/deploy_kyra.sh` (needs `supabase login` + `supabase/.env.local` with `OPENAI_API_KEY`). Optional: `supabase secrets set KYRA_DAILY_LIMIT=30 --project-ref wqumwxoiqsiwizlftojq`.
6. **Rotate the two leaked secrets** (both passed through chat): DB password (dashboard -> Settings -> Database -> reset) and the OpenAI key (platform.openai.com -> rotate -> update `supabase/.env.local` -> redeploy function).
7. **Smoke test:** fresh email signup -> gate works -> Kyra replies; confirm no anon path; verify a signed-out user hits the auth gate.

## Phase 2 — Review response & launch ops
- **App Review / UGC readiness (do before submitting).** Community posts + Kyra messages are the likely rejection point under Apple Guideline 1.2 (UGC). You already have report + block and no DMs, and now every author is a real authenticated account — that helps. Still recommended before submit: an **EULA / "no objectionable content" agreement accepted at the mandatory auth step**, plus a stated commitment to act on reports within 24h and eject abusers. Missing EULA acceptance is a common UGC rejection.
- **Monitoring + analytics.** Recommendation: **TelemetryDeck** (privacy-first product analytics, no PII — fits a faith app) for usage + **Sentry** Apple SDK for crash/error. Each is a few hours to wire. _Decision needed: confirm this stack or pick another (Firebase/Crashlytics is the heavier Google alternative)._

## Phase 3 — Monetization: Crossed Out Plus
- StoreKit 2 (iOS 17 native), paywall, entitlement gating.
- **Open decision — what's behind the wall.** Strongest candidates given current infra: (a) higher/unlimited Kyra daily limit — a natural upsell off the cap we just built; (b) premium ElevenLabs verse audio (see research); (c) advanced multi-day journeys. Recommend leading with (a)+(b).
- Server-side: validate via App Store Server Notifications v2 -> a Supabase edge function updates a `subscriptions` table; gate the Kyra limit off that entitlement.
- Pricing: monthly + annual; consider a founder's/lifetime tier at launch.

## Phase 4 — Engagement & retention
- **APNs push** (bundle already has Push enabled): server-side scheduler (Supabase cron / edge function) for daily verse nudge, streak reminders, and community replies — beyond today's local reminder.
- **Home-screen widget** (WidgetKit): verse of the day + streak, via a shared app group.
- **Kyra streaming responses** (SSE from the edge function -> progressive text) for perceived speed.
- **Journeys content engine**: structured multi-day devotional plans (data model + authoring pipeline).

## Phase 5 — Depth features
- **ElevenLabs premium audio** (full report delivered in chat — drop into `research/` to keep with the repo). TL;DR: the ~$11 Creator promo month buys ~134 min of top-quality narration; a **103-verse popular-verse starter set is ~16 min for ~$1.32–$2.90** — fits the $20 budget with huge headroom. A **full KJV ≈ 4.17M billable characters ≈ $690–$990** depending on plan/timeline. Plan: buy the pilot, **lock a voice first** (re-narrating after a voice change means repaying the full amount), narrate the starter set, expand later.
- **Attend live streaming** (full report delivered in chat). TL;DR: use **YouTubePlayerKit** for YouTube (never extract raw HLS — violates ToS/strips ads), **AVPlayer** for direct HLS (BoxCast/Resi/Subsplash/Church Online Platform), **link-out** for Facebook. Per-church record: `{ platform, channelId/streamURL, watchPageURL }`. Starter directory covers ~34 states; ~13 low-population states are gaps to fill.
- **Church claiming/verification + auto-ingestion engine**: YouTube Data API geo/keyword search + directory crawling -> Supabase, with a church-claim flow (domain/email verification + admin review).
- **NIV/ESV licensing** once the LLC exists (public-domain BSB/WEB/KJV until then).

## Suggested sequencing
Deploy Phase 1 (runbook) -> add the EULA + moderation bits and monitoring (Phase 2) -> **then** submit for review -> while in review, start Phase 3 (Plus) since it reuses the Kyra-limit infra. Phases 4–5 are post-launch, prioritized by retention impact.
