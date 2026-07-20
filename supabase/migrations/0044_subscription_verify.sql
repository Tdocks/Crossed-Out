-- 0044_subscription_verify.sql
-- Closes the self-grant hole in migration 0036: `upsert_own_subscription`
-- let any authenticated user set their own subscriptions.status = 'active'
-- with an arbitrary product/expiry and no server-side receipt verification.
--
-- The new `verify_subscription` edge function is now the ONLY writer of
-- entitlement state. It verifies a StoreKit 2 signed transaction (JWS, x5c
-- chain rooted in Apple's pinned Root CA - G3) server-side, then writes
-- public.subscriptions directly using the service-role key (which bypasses
-- RLS entirely — Supabase's service_role Postgres role is BYPASSRLS by
-- default, so no new SECURITY DEFINER function is needed for that write).
--
-- This migration only needs to revoke the client's ability to call the old
-- self-grant function. Nothing else changes:
--   - `public.subscriptions` never had an INSERT/UPDATE policy (RLS only
--     defines "own subscription read" — a SELECT policy), so direct table
--     writes from `authenticated` were already denied by default-deny RLS.
--     The SECURITY DEFINER function was the only write path, and it's the
--     thing we're locking down here.
--   - `is_plus()` and `kyra_daily_limit_for_user()` (both read-only) are
--     untouched, so existing Plus subscribers' entitlement reads keep
--     working exactly as before — nobody is locked out.
--   - The function is revoked, not dropped, so this is trivially
--     reversible and doesn't break any other caller's reference to it.

revoke execute on function public.upsert_own_subscription(text, text, timestamptz, text, text) from authenticated;

-- Belt-and-suspenders: anon never had execute on this function (0036 only
-- granted to authenticated), but make the "no client can self-grant" intent
-- explicit and future-proof against an accidental grant elsewhere.
revoke execute on function public.upsert_own_subscription(text, text, timestamptz, text, text) from anon;

comment on function public.upsert_own_subscription(text, text, timestamptz, text, text) is
  'DEPRECATED / LOCKED DOWN (migration 0044): no longer callable by authenticated or anon. '
  'Client-supplied subscription state was never receipt-verified — this let any signed-in '
  'user grant themselves Plus for free. The verify_subscription edge function (StoreKit 2 '
  'JWS + Apple root-CA chain verification, service-role write) is now the sole writer of '
  'public.subscriptions. Kept (not dropped) only for audit history / easy rollback.';
