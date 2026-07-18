# CROSSED OUT — FULL APP AUDIT (Fable 5)
**Date:** 2026-07-18 · Inputs: MASTER_PLAN.md, HANDOFF_2026-07-18.md, live web competitor verification. Source repo not accessible to the auditor — anything the handoff didn't state is marked **needs code verification (NCV)**.

---

## PART A — FEATURE-SET AUDIT vs. MASTER PLAN

| # | Capability | Planned intent | Status | Notes |
|---|-----------|----------------|--------|-------|
| 1 | Brand / "crossed out" metaphor | God didn't cross you out | Partial | Surfaces in one interaction; name-perception risk untested. |
| 2 | Onboarding + focus areas + auth | 24 focus areas, tone, translation; real accounts | Shipped (deploy gap) | Anon sign-in still ON in dashboard; Apple provider off. Ranked focus/excluded topics: NCV. |
| 3 | Deterministic Scripture engine | 5-layer personalization before AI | Shipped (layers 1–2) | Strongest asset. Layer 3 (approved explanations/devotionals/prayers/actions) barely started — biggest content lift. |
| 4 | Daily check-in (12 moods) | Mood drives selection | Shipped | — |
| 5 | Feedback loop | 8 signals | Partial | 4 of ~8 signals; "show deeper/more practical/already know this" NCV. |
| 6 | Today experience (full loop) | check-in→verse→context→audio→reflection→prayer→action→media | Partial | Missing context step, practical actions, session lengths, media handoffs. Today is a verse card, not the loop. |
| 7 | Kyra AI guide | Grounded, guardrailed, capped | Partial — coded, NOT deployed hardened | Safety persona red-lines NCV; needs an adversarial eval before submit. |
| 8 | Devotionals (G19) | Catalog + independent study + recommender | Built, not applied | Right pattern; catalog near-empty → ships hollow without content. |
| 9 | Streaks / rhythm / Grace Days | Streak + 8-practice rhythm + grace | Partial | Grace Days/rest/cooperative leaderboards NCV — cheap, high brand value. |
| 10 | Bible experience | Reader, search, notes, plans, memory verses, audio | Partial | Reader + full-text + semantic search shipped. Plans/memory/cross-refs/comparison likely missing. BSB/WEB/KJV only. |
| 11 | Cross the Bridge outreach | Package → no-install web recipient → shared journeys | Mock-or-unclear | **The plan's signature differentiator does not functionally exist.** |
| 12 | Community | Purpose Spaces, safety-first | Partial | No EULA = Guideline 1.2 risk; moderation/crisis/minor protections NCV. |
| 13 | Attend church online | Streaming directory + matching | Mock | Phase 2 — fine to defer, not as a dead tab. |
| 14 | Entertainment (music/movies) | Taste-matched Christian media | Missing | Phase 2. |
| 15 | Local churches / events | Verified profiles, "thinking of visiting" | Mock/Missing | Phase 3. |
| 16 | Mission trips & service | Verified discovery, no payments v1 | Missing | Phase 4. |
| 17 | Donations | Transparent giving | Mock/Missing | Don't ship a mock Give screen — review + trust hazard. |
| 18 | Video feed + automation pipelines | Purposeful feed; content/church/marketing automation | Missing | Phase 5 — correctly deferred. |
| 19 | Monetization (Plus, church subs) | Freemium, annual-first | Missing | No paywall + live AI = every engaged free user is pure cost. |
| 20 | 5-tab navigation | Today/Bible/Community/Attend/Explore | Shipped shell, hollow tabs | Mock tabs risk Guideline 2.1 (completeness). |
| 21 | Notifications & widgets | Phase 1 | NCV | Silent in handoff; notifications drive the daily loop. |
| 22 | Observability | (under-planned) | Missing | Launching blind = can't detect the trust failures the plan fears. |

**Five biggest plan-vs-reality gaps:** (1) the signature differentiator (Cross the Bridge) is a mock screen — positioning currently unearned; (2) the trust/compliance layer is coded but not deployed (anon auth live, Apple off, Kyra hardening undeployed, no EULA) — all days-not-weeks; (3) Today is a verse, not the understand→act loop the promise sells; (4) zero monetization with live AI cost — the plan's own bad economics is the shipped state; (5) the connected-journey back half (community→church→service→outreach) is mock/missing, so v1 must honestly be a personal formation companion (which the phased plan permits — but the nav over-promises via hollow tabs).

**Plan under-weights:** content operations (tags done ≠ approved content around them); App Review compliance as a workstream (EULA, UGC moderation, Sign in with Apple, account deletion, privacy labels for sensitive faith+mood data); audio quality (TTS reads cheap in this category); a distribution/acquisition plan (24 product sections, zero go-to-market); data sensitivity posture.

---

## PART B — COMPETITOR ANALYSIS (web-verified July 2026)

| Competitor | Wedge | Monetization | Scale | Crossed Out vs. |
|---|---|---|---|---|
| YouVersion | The default free Bible: reader, plans, VOTD, church network | Free, donation | 1B installs; 3,600+ translations; 25k+ church partners | Behind on translations/plans/network/price; differentiated on need/mood personalization + an AI guide YouVersion lacks. Don't fight the reader war. |
| Hallow | Premium Catholic prayer, celebrity talent, Super Bowl marketing | $9.99/mo, $69.99/yr | $105M raised; 10M+ dl; #1 overall Feb 2024; ~40% non-Catholic | Behind on audio/brand/capital; differentiated on Protestant lane + need-matching + outreach. Validates $70/yr willingness-to-pay. |
| Glorify | 5-min daily devotional + worship, wellness polish | ~$9.99/mo / ~$59.99/yr | 20M+ dl; a16z ($40M+) | **Closest analog to the Today loop.** Parity on "short daily devotional"; wins only if personalization is visibly better. The head-to-head fight. |
| Pray.com | Celebrity-narrated audio, Bible-in-a-Year | Freemium w/ ads; premium tiers | 10M+ installs | Behind on narration; differentiate on no-ads-ever (they run ads even on paid) + personalization. |
| Abide | Christian sleep + meditation, aggressive pricing | $9.99/mo; $39.99/yr | 100k+ 5-star | Not our fight; but $39.99/yr pressures the low end. |
| Dwell | Beautiful audio Bible, voices/soundscapes | $9.99/mo, ~$59.99/yr | Niche, durable | Behind on audio Bible; don't market audio until it's credible. |
| **Bible Chat** | **AI-first faith companion — the direct Kyra competitor**, denomination-aware, pastor-reviewed | Freemium; premium | ~5M MAU ~1yr; €13.4M raised; "fastest-growing faith app" | **Kills "Kyra as differentiator" on its own.** Guardrailed reviewed AI chat at scale already exists. Kyra's edge must be *embedded in a deterministic formation loop*, not chat. |

**Honest wedge assessment.** Weak/not-defensible-as-claimed: Kyra-as-grounded-AI (table stakes; Bible Chat at 5M MAU), the engine architecture per se (an invisible cost/safety moat, not an acquisition wedge), and the brand (distinctive but unproven). **Genuinely defensible if built:** (1) need→Scripture personalization with a visible "why" — no major competitor personalizes the daily unit to a ranked need + mood + feedback; it's the only differentiator that exists in the product today; (2) **Cross the Bridge** — no-install, low-pressure Scripture outreach that doubles as a zero-CAC growth loop; highest conviction, currently a mock; (3) the connected journey (a 2–3yr moat requiring church-side network — shapes sequencing, not v1 messaging); (4) grace-not-guilt mechanics (cheap, on-brand, hard for streak-driven competitors to copy). **Bottom line:** at launch the honest differentiation is *personalized-to-your-actual-life daily Scripture with provable textual integrity* — vs Glorify (loop, no personalization), YouVersion (scale, no personalization), Bible Chat (AI, no formation loop).

---

## PART C — PRIORITIZED GAP REGISTER

### P0 — Launch blockers (trust / App Review / economics)
1. **Deploy auth hardening** (anon sign-in live, Apple off, migrations unapplied) — Guideline 4.8 + abuse surface + account deletion 5.1.1(v) NCV. Effort S. A deployment day.
2. **EULA / objectionable-content acceptance; UGC readiness** — Guideline 1.2 rejection + the plan's #1 trust risk. Effort S–M. **Recommended: ship v1 with Community feature-flagged OFF** — kills the review risk and the empty-community cold-start at once.
3. **Deploy hardened Kyra + safety eval** — one reckless answer on abuse/treatment/suicide = trust catastrophe. Effort M. Versioned red-line prompt + ~100-prompt adversarial eval + crisis-resource interstitial (988) before submit.
4. **Mock tabs in shipping nav** — Guideline 2.1 completeness. Effort S. Ship 3 tabs (Today, Bible, Profile/Explore-lite); remove the rest (Apple dislikes "coming soon" too).
5. **Monetization + cost cap** — every engaged free user is negative margin. Effort M. Minimum viable Plus: StoreKit 2, annual-first ($49.99–59.99/yr), gating unlimited Kyra + AI devotional suggestions + reflection history. Never weekly.
6. **Crash/analytics** — TelemetryDeck + Sentry. Effort S.
7. **Privacy posture for sensitive data** (mood, addiction, faith struggles) — App Privacy labels, GDPR/CCPA, RLS audit. Effort S–M.
8. **Apply G19 + seed catalog** — 30–60 founder-reviewed devotionals across top ~8 focus areas or it ships hollow. Effort M.

### P1 — Differentiators (first 1–3 months)
9. **Complete the Today loop** — context step + one practical action + 2/5/10-min variants. Effort M. Actions are cheap content, outsized differentiation vs Glorify.
10. **Cross the Bridge MVP** — compose → gorgeous no-install web page → one shared journey ("Seven Days of Hope"). Skip audio/video v1. Effort L. The only unowned growth loop.
11. **Grace Days + rhythm + cooperative streaks** — Effort S–M. "The streak that forgives you." Ship with launch if possible.
12. **Notifications + widgets** (verify NCV) — the daily loop dies without a re-entry trigger. Effort S–M.
13. **Audio quality** — premium TTS voice for verse-of-day only; don't compete on audio Bible yet. Effort M.
14. **ESV licensing / LLC** — BSB-only caps mainstream credibility. Effort M (mostly legal).
15. **Reflection history / journaling insights (Plus)** — the actual reason to pay annually. Effort M.

### P2 — Scale (post-traction)
Community (re-enabled with full safety stack), Attend-online directory, entertainment recs, local churches + church subs, missions/service, donations (after legal review), video feed, all automation pipelines, church discovery/verification. None before the daily loop retains.

### Sequence to first submission
1. **Week 1 — deploy what's coded:** auth hardening, Apple sign-in, hardened Kyra, Sentry/TelemetryDeck, RLS audit. Zero new product work.
2. **Weeks 2–3 — compliance + cut:** EULA/ToS, privacy policy/labels, flag off Community/Attend/Bridge/Give, verify account deletion.
3. **Weeks 3–5 — complete the loop:** G19 applied + 30–60 devotionals, context + practical action on Today, Grace Days, StoreKit Plus.
4. **Weeks 5–6 — Kyra safety eval + TestFlight beta (50–100 from friendly churches), then submit** a focused 3-tab *personalized faith companion* (= Phase 1 of the plan's own phasing).
5. **Post-launch quarter:** Cross the Bridge MVP → re-enable Community → ESV.

### The 2–3 bets most likely to make it stand out
1. **Cross the Bridge** — the only feature no competitor has, and simultaneously the growth engine. Difference between "another devotional app" and a category of one.
2. **Radically visible personalization integrity** — the "why this verse" line + feedback learning + a public promise no AI-slop competitor can make: *every verse is real, tagged, and human-audited — we will never hallucinate Scripture.* Turn invisible cost-control into the trust brand.
3. **Grace-not-guilt mechanics** — cheap, impossible for streak-driven competitors to copy without breaking their engagement models, and it *is* the brand: God didn't cross you out.
