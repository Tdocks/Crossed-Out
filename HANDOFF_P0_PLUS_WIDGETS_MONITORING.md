# Handoff — Plus, Widgets, Notifications, Monitoring
_Written Jul 19, 2026. Code is in the working tree; build verified green._

This pass implemented everything that does **not** require your Apple Developer / App Store Connect / third-party accounts. Your remaining work is mostly dashboard clicks + pasting keys.

---

## 1. What shipped in code (no action needed to “exist”)

| Area | What’s in the repo |
|------|--------------------|
| **Plus / StoreKit 2** | `SubscriptionService`, `PlusPaywallView`, Settings → Crossed Out Plus, Kyra limit upsell, product IDs, local `Configuration.storekit` for Simulator testing, DEBUG “Simulate Plus” |
| **Server entitlement** | Migration `0036_plus_subscriptions.sql` (`subscriptions`, `upsert_own_subscription`, `is_plus`, `kyra_daily_limit_for_user`) |
| **Kyra Plus limit** | `supabase/functions/kyra/index.ts` calls `is_plus()` → uses `KYRA_PLUS_DAILY_LIMIT` (default **200**) vs free **30** |
| **ASN v2 stub** | `supabase/functions/app-store-notifications/index.ts` (returns 501 until you wire it) |
| **Widget** | `CrossedOutWidgets` target — Verse of the Day + streak; App Group `group.com.tdocks.crossedout` |
| **Local notifications** | Existing daily reminder + new **Streak nudge** (evening) in Settings |
| **Analytics seam** | `AnalyticsService` + `AppSecrets` (empty keys = local OSLog only) |

**Product IDs (must match ASC exactly):**
- `com.tdocks.crossedout.plus.monthly`
- `com.tdocks.crossedout.plus.annual`

**Limits:** free 30 / day · Plus 200 / day (overridable via Supabase secrets).

**Local test without ASC:** Run scheme `CrossedOut` (already points at `CrossedOut/Configuration.storekit`) **or** Settings → Debug: simulate Plus.

---

## 2. Exact steps you must do

### A. Apply migration 0036 (required for Plus Kyra limit)

```bash
pbcopy < "/Users/tylerdockswell/Projects/Crossed Out /supabase/migrations/0036_plus_subscriptions.sql"
```

Paste into Supabase → SQL Editor → Run.

Verify:

```sql
select to_regclass('public.subscriptions');
select public.is_plus(); -- false until entitled
```

### B. Redeploy Kyra (required so Plus limit is live)

```bash
cd "/Users/tylerdockswell/Projects/Crossed Out "
./supabase/deploy_kyra.sh
```

Optional secrets:

```bash
supabase secrets set KYRA_DAILY_LIMIT=30 KYRA_PLUS_DAILY_LIMIT=200 --project-ref wqumwxoiqsiwizlftojq
```

### C. App Store Connect — Crossed Out Plus (required for real purchases)

1. [App Store Connect](https://appstoreconnect.apple.com) → your app `com.tdocks.crossedout`
2. **Subscriptions** → create a subscription group (e.g. “Crossed Out Plus”)
3. Add two auto-renewables with **exact** product IDs above
4. Set pricing (plan guidance: ~$7.99/mo, ~$59.99/yr — adjust as you like)
5. Add localization (display name + description)
6. Submit subscription metadata with the next app version
7. Complete **Paid Apps Agreement**, banking, tax if not already done

Until this exists, Simulator StoreKit config + Debug simulate Plus are enough for UI QA.

### D. Apple Developer — App Group for widgets (required for home-screen widget)

1. [developer.apple.com](https://developer.apple.com) → Identifiers
2. App ID `com.tdocks.crossedout` → enable **App Groups** → add `group.com.tdocks.crossedout`
3. Create App ID `com.tdocks.crossedout.widgets` (if Xcode didn’t) → same App Group
4. In Xcode: open project → ensure both targets show the App Group checked (entitlements already list it)
5. Build to a **device**, long-press home screen → add **Verse of the Day** widget

If the group isn’t registered on the portal, the widget will show placeholder verse only.

### E. Monitoring — TelemetryDeck + Sentry (optional but recommended)

1. Create apps at [TelemetryDeck](https://telemetrydeck.com) and [Sentry](https://sentry.io)
2. Paste into `CrossedOut/Config/AppSecrets.swift`:

```swift
static let telemetryDeckAppID = "YOUR_APP_ID"
static let sentryDSN = "https://…@….ingest.sentry.io/…"
```

3. Add SPM packages (Xcode → Package Dependencies, or `project.yml`):
   - TelemetryDeck: `https://github.com/TelemetryDeck/SwiftClient`
   - Sentry: `https://github.com/getsentry/sentry-cocoa`
4. Initialize in `AnalyticsService.start()` (TODOs are marked there)
5. Privacy: only event **names** + coarse enums — never verse text, prayers, Kyra bodies, or names

### F. Remote push / APNs (not built — still TODO)

Local reminders work today. Server push needs:

1. Apple Developer → Keys → **APNs** key (.p8)
2. Enable Push Notifications capability on the app ID + entitlements `aps-environment`
3. Store device tokens in Supabase + a cron/edge sender

Skip until after Plus is live unless you specifically want server-driven nudges.

### G. App Store Server Notifications v2 (optional hardening)

Client StoreKit sync already updates `subscriptions` for the purchasing device. For multi-device / refunds:

1. Finish stub `supabase/functions/app-store-notifications`
2. ASC → App → App Store Server Notifications → Production + Sandbox URLs
3. Map `originalTransactionId` → `user_id` (use the value written by `upsert_own_subscription`)

### H. Commit / TestFlight when ready

Working tree has Journey + badges + this P0 slice uncommitted unless you already committed. Review diff, then commit/push when you want.

Suggested commit split:
1. Journey / grace / paths / badges (0034–0035)
2. Plus / widgets / monitoring seam (0036 + widget target)

---

## 3. Quick QA checklist (you or anyone)

- [ ] Apply 0036 + redeploy Kyra  
- [ ] Settings → Debug: simulate Plus → Kyra limit messaging changes  
- [ ] Run with StoreKit config → paywall shows Monthly/Annual → purchase in Simulator  
- [ ] After “purchase”, `select * from subscriptions` has your user row  
- [ ] Hit free Kyra cap → paywall CTA appears  
- [ ] Check-in updates widget snapshot (add widget on device)  
- [ ] Settings → Streak nudge schedules a local notification  

---

## 4. Files to know

```
CrossedOut/Config/PlusProducts.swift
CrossedOut/Config/AppSecrets.swift
CrossedOut/Services/SubscriptionService.swift
CrossedOut/Services/AnalyticsService.swift
CrossedOut/Features/Plus/PlusPaywallView.swift
CrossedOut/Shared/AppGroupStore.swift
CrossedOut/Configuration.storekit
CrossedOutWidgets/
supabase/migrations/0036_plus_subscriptions.sql
supabase/functions/kyra/index.ts          # Plus limit
supabase/functions/app-store-notifications/  # stub
project.yml                               # widget target + StoreKit scheme
```

---

## 5. What you do **not** need to rebuild

Paywall UI, entitlement listening, widget UI, streak nudge, analytics seam, migration SQL, Kyra Plus branching — all already coded and building.
