# P0-1 — Deploy Auth Hardening (runbook)

**Status: code is 100% ready and pushed** (commits `b3c7e1f`, `87eb68e` on
`origin/main`). Verified this session: `0007_require_auth.sql` (anon lockdown +
`to authenticated` policies), `0008_kyra_usage.sql` (cap), anonymous sign-in
removed in Swift, Sign-in-with-Apple wired client-side, account deletion works
(`delete_own_account()` in `0006`, cascades, called from Settings). Only the
deploy actions below remain — all need your authenticated Mac / dashboard.

**Order matters:** migrations BEFORE the Kyra deploy (Kyra calls
`increment_kyra_usage` from `0008`).

## 1. Apply migrations 0007 + 0008 (idempotent — safe to re-run)
In the Supabase SQL editor. Copy each in turn:
```
cd ~/Projects/Crossed*/
pbcopy < supabase/migrations/0007_require_auth.sql   # paste → Run
pbcopy < supabase/migrations/0008_kyra_usage.sql     # paste → Run
```
Verify: `kyra_usage` table + `increment_kyra_usage` function exist; the
`anon` role has no grants on user tables.

## 2. Disable anonymous sign-ins (dashboard)
Authentication → Sign In / Providers → **turn OFF "Allow anonymous sign-ins."**

## 3. Enable Apple provider (dashboard)
Authentication → Providers → **Apple → enable** → add authorized client ID
**`com.tdocks.crossedout`**. (Native iOS SIWA uses the id_token flow, so only
the client ID is needed — no secret.)

## 4. Deploy the hardened Kyra function
```
cd ~/Projects/Crossed*/ && ./supabase/deploy_kyra.sh
# optional: supabase secrets set KYRA_DAILY_LIMIT=30 --project-ref wqumwxoiqsiwizlftojq
```
(Needs `supabase login` as the account that owns `wqumwxoiqsiwizlftojq`.)

## 5. Rotate the two leaked secrets (they passed through this session)
- **DB password:** dashboard → Settings → Database → reset. Then update the
  password inside `scripts/.env.run`.
- **OpenAI key:** platform.openai.com → rotate → update `supabase/.env.local` →
  **re-set the secret + redeploy all three functions** so they get the new key:
  ```
  ./supabase/deploy_kyra.sh
  ./supabase/deploy_semantic_search.sh
  ./supabase/deploy_devotional_suggest.sh
  ```

## 6. Smoke test
- Fresh email signup → onboarding → the auth gate is satisfied → Kyra replies.
- Sign in with Apple works (test on a real device / provisioned sim).
- Sign out → a signed-out user hits the full-screen auth gate (no anon path in).
- Settings → Delete Account → "Delete Everything" → account is gone (try signing
  back in → rejected).
- Hit the Kyra cap (send > limit) → 429 "daily limit" message.

## Done when
Anon is off in prod, Apple sign-in works, `0007`/`0008` applied, hardened Kyra
live and capped, secrets rotated, all smoke tests pass. Then P0-1 is closed and
the next blocker (P0-2 EULA / feature-flag Community) is up.
