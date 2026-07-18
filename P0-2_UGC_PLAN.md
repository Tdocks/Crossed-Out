# P0-2 — EULA + UGC readiness — execution plan

Two paths. **Recommended: Path A (feature-flag Community/Attend off for v1).**
Fable's call, and it's right: it removes almost the entire UGC moderation burden
for App Review *and* sidesteps the empty-community cold-start problem — you launch
the strong personal-formation loop and turn community on later when you can staff
moderation and seed it network-by-network.

## What counts as UGC in v1 under each path
- **Path A (Community + Bridge off):** the only user-authored surfaces left are
  Kyra chat (private, AI), independent-study notes, and reflections — all private
  to the user. Public UGC ≈ none, so Guideline 1.2's full moderation stack isn't
  triggered. You STILL need a EULA/ToS + privacy policy (every app does).
- **Path B (keep Community):** you must ship the full 1.2 stack — EULA acceptance,
  in-app reporting, blocking, a working report→human-review flow acted on within
  24h, and a way to filter/remove content. More work, more risk at launch.

## Artifacts already drafted (this session)
- `legal/EULA.md` — Terms of Use incl. the zero-tolerance objectionable-content +
  24h-action clauses Apple looks for, plus the not-a-substitute-for-professional
  and crisis (988) language.
- `legal/PRIVACY_POLICY.md` — covers the sensitive faith/mood data, AI processing,
  Supabase RLS, deletion, no ad SDKs, GDPR/CCPA.
- **Both are drafts — have counsel review, fill in the domain/contact, and host at
  public URLs** (needed for the App Store listing + in-app links).

## Code changes to execute (when ready)
1. **Terms acceptance record.** Migration: `alter table public.profiles add column
   if not exists terms_accepted_at timestamptz;` Set it when the user accepts.
2. **Acceptance gate at the mandatory auth step** (`Features/Onboarding/AuthSheet`
   / `OnboardingView`): a required "I agree to the Terms of Use & Privacy Policy"
   checkbox with tappable links before account creation completes; write
   `terms_accepted_at` on success. Also link both docs in Settings → About.
3. **Feature flags (Path A).** Add a `FeatureFlags` enum (e.g.
   `communityEnabled=false`, `attendEnabled=false`, `bridgeEnabled=false`). In
   `DesignSystem/TabBar.swift`, drive the tab bar from a computed `visibleTabs`
   filtered by flags instead of `COTab.allCases` — v1 shows **today, bible, more**.
   In `App/RootView.swift`, make the `"community"`/`"attend"` deep-link cases fall
   back to `.today` when disabled. (This also satisfies **P0-4** — ship 3 tabs.)
4. **App Store Connect:** add the hosted EULA + Privacy Policy URLs; complete the
   App Privacy "Data Types" for account + sensitive faith/health-adjacent data.

## Note
Path A collapses P0-2 and P0-4 into one small, contained change (flags + one tab
bar + a couple deep-link fallbacks + the acceptance gate). Recommend doing them
together. Estimated effort: S–M, all additive/low-risk.
