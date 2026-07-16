# Crossed Out — Reality vs. Master Plan
### Gap analysis, competitive lens, and a phased build roadmap
_Written Jul 16, 2026. Measures the shipped build against the full "Christian life OS" master plan + a 4-stream competitive/blindspot study._

---

## 0. The honest headline
The master plan describes a **personalized Christian formation, community, church-discovery, entertainment, outreach, missions, donation, and content platform** — a ~5-phase "Christian life operating system." What's actually built is a **polished, well-architected shell of early Phase 1**: real Bible reading, community, streak/journey, auth, and a working Kyra chat — wrapped in a genuinely strong "Living Manuscript" design foundation.

Two things to internalize:
1. **We're at ~20-25% of the planned capability**, not near done. The design maturity makes it *look* further along than it is.
2. **Several finished-looking screens are mock or stub** — they'll read as "broken/fake" to a reviewer or user if shipped as-is. The gap is not just "missing features," it's "convincing placeholders that need real backends or need to be hidden."

The good news: the plan's single most important bet — **relevance/personalization done with a deterministic engine so AI cost stays controlled** — is exactly the right moat, and it's mostly *unbuilt*, which means the highest-leverage work is still ahead and ours to win.

---

## 1. Where the app actually is (audit of the shipped code)

| Feature | Status | What's real | What's mock / missing |
|---|---|---|---|
| Onboarding | Partial | Focus/struggle selection, flow, mandatory auth gate | **Never collects the user's name** - persists hardcoded "Tyler" for every user (bug) |
| Today | Partial | Profile-driven "you said" framing, verse, check-in->re-rec, streak | Personalization is shallow/heuristic; no tagged-scripture engine behind it |
| Bible reader | Real | 66-book/chapter/translation nav from Supabase; highlight/note/bookmark persisted; paging | No **search**, no **cross-references**, no **audio**, no verse-compare; "..." kebab button is dead |
| Kyra (AI) | Partial | Live GPT chat via hardened edge function (auth + rate limit) | **No conversation history** (amnesia each session); **dead mic button**; no theological guardrails/retrieval grounding |
| Community | Real | Prayer/posts, pray_for/encourage_post RPCs, report/block | No groups/circles; no verified leaders; single-person moderation won't scale |
| Journey / Progress | Real | Streak, grace days, weekly rhythm from real completions | "Grace Days" card looks tappable but has no action; no leaderboards; no journeys engine |
| Attend | Mock | Service detail, save-church, plan-a-visit UI | **"Watch Live" is fake** (relabels a button 1.6s, no player); "Live Now" hero hardcoded to mock |
| Church Finder | Partial | Filter menu, save hearts | **Accent-color bug** (DB stores red/blue/olive/gold, code expects coCrossRed/... -> every live church loses its color); "Suggest a Church" is dead; location-based find not wired |
| Give | Real (by design) | Link-out only (not a nonprofit) | No donation platform (deliberate later phase) |
| Bridge (outreach) | Stub | - | VersePickerStub - literally non-functional; recipient/verse hardcoded to mock |
| Explore | Fake | - | **100% fake**: search + chips do nothing, "recommended" is hardcoded strings, no backend at all |
| Settings/Profile | Real | Profile edit, translation, appearance, reminder notifications, delete account | - |
| Auth | Real | Email + Sign in with Apple; anon removed; gate enforced | - |

**Two real bugs to fix regardless of roadmap:** the church accent-color mismatch, and onboarding persisting the hardcoded first name "Tyler" for every new user.

**Deploy note:** Phase-1 hardening (anon removal, Kyra rate-limit/auth, migrations 0007/0008) is now *live* (verified 401 on unauthenticated Kyra calls).

---

## 2. The master plan, decomposed into capability areas
Each of these is effectively its own product:

1. **Personalized Scripture Engine** - tagged-scripture DB + deterministic scoring (Layers 1-3), cached AI answers (Layer 4), live AI only when needed (Layer 5). *The core moat.*
2. **Today / daily loop** - check-in -> relevant scripture -> context -> audio -> reflection -> prayer -> one action -> optional share.
3. **Bible** - search, cross-refs, audio, verse compare, collections, licensed translations (KJV + NIV/ESV), offline.
4. **Journey + gamification** - traditional streak **and** spiritual rhythm, grace days, group/cooperative leaderboards, illustrated journey covers.
5. **Kyra AI** - warm guide, retrieval-grounded, theological guardrails, never roleplays as God, model-independent (GPT-5.6 Luna now).
6. **Entertainment transition** - connect Apple Music/Spotify -> Christian music matched to taste; movies/TV discovery.
7. **Attend (online church)** - aggregate churches that stream, filters + matching, live/soon timeline, online->in-person bridge.
8. **Community** - purpose-based spaces, safety, verified leaders.
9. **Local** - church finder w/ rich profiles + "I'm thinking of visiting," events, missions, partners, business discounts.
10. **Cross the Bridge outreach** - non-Christian-friendly personal shares (message + scripture + voice/video) via a no-install web experience.
11. **Missions** - discovery + application marketplace with safeguards.
12. **Donations** - transparent project funding via a payment provider + compliance.
13. **Video / short-form** - curated purposeful feed + an AI viral-Bible-video pipeline.
14. **Automation** - church auto-discovery/verification, content repurposing, marketing - so it runs **hands-off**.
15. **Business model** - freemium consumer (Plus) + church SaaS + marketplace revenue.
16. **Living Manuscript design system** - the editorial identity + cross-out/bridge motifs (partially built, strong).

---

## 3. Gap register (planned vs. built vs. priority)
Tiers: **P0** = launch-credibility/trust blocker; **P1** = differentiator, near-launch; **P2** = scale/automation, post-launch.

| # | Capability | Built now | Gap | Tier |
|---|---|---|---|---|
| G1 | Personalized Scripture Engine (tagged DB + scoring) | Shallow heuristic | Build tagged-scripture dataset + deterministic scoring; the "it's for *me*" promise | P0 |
| G2 | Bible search / cross-refs / verse compare | None | Full-text search is table-stakes | P0 |
| G3 | Licensed modern translation (NIV/ESV) | KJV/BSB/WEB (PD) | Contract via API.Bible (~$10-250/mo/translation); NIV needs written license | P0/P1 |
| G4 | Verse of the Day + widgets + lock-screen | None | Cheap, high-value, expected; retention + ASO surface | P0 |
| G5 | Share cards + Bridge outreach web | Bridge stub | Verse-image share cards (table-stakes) + non-Christian "cross the bridge" web flow (differentiator) | P0/P1 |
| G6 | Kyra guardrails + grounding + history | Chat only | Retrieval-ground verses, crisis handling, no-roleplay, stance statement, persist history, kill dead mic | P0 |
| G7 | UGC moderation at scale + EULA | Report/block | Apple 1.2: EULA acceptance, crisis detection, moderation queue, staged rollout | P0 |
| G8 | Audio (verse/Bible) | None | Popular-verse audio first (see ElevenLabs plan); full Bible later | P1 |
| G9 | Attend - real online-church streaming | Mock video | Aggregate streaming churches (YouTubePlayerKit / AVPlayer), filters, live/soon | P1 |
| G10 | Journeys engine + illustrated covers + leaderboards | Streak/rhythm only | Multi-day journeys, cooperative group boards, signature illustrations | P1 |
| G11 | Entertainment transition (music/TV) | None | Apple Music/Spotify taste-match -> Christian music; media discovery | P1/P2 |
| G12 | Rich church profiles + "thinking of visiting" | Basic finder (+ bug) | Denomination/style/first-visit info, verified newcomer contact | P1 |
| G13 | Events + RSVP | None | Local + church events, RSVP, share-to-web | P2 |
| G14 | Missions marketplace | None | Discovery + application w/ safeguards (no payments first) | P2 |
| G15 | Donation platform | Link-out only | Transparent project funding + charity/solicitation compliance | P2 |
| G16 | Short-form video + AI Bible-video pipeline | Explore fake | Curated feed; AI generation w/ human review | P2 |
| G17 | Automation (discovery/verification, content, marketing) | None | The "hands-off" requirement - confidence-scored discovery, claim flow, repurposing | P2 |
| G18 | Monetization: Plus (StoreKit) + church SaaS | None | Paywall + entitlements; gate Kyra-limit/premium audio; church tiers | P1 |
| G19 | Accessibility, offline, cost-control polish | Partial | VoiceOver pass, offline reading, deterministic-first AI routing | P0/P1 |
| G20 | Fix bugs + resolve mock screens | Explore/Attend/Bridge mock | Fix accent + name bugs; build **or hide** Explore/Attend-live/Bridge before submission | P0 |

---

## 4. Competitive lens - reiterating the gaps against the market

**Don't try to out-YouVersion YouVersion** (1B+ installs, 3,500+ translations, free - unwinnable head-on). Hallow ($69.99/yr, 10M+, $105M raised), Glorify ($41.99-69.99/yr), and Dwell ($59.99/yr audio) prove premium subscriptions work. The AI-Bible-chat crop (Bible Chat ~25-40M, $39.99-59.99/yr) proves demand for "ask the Bible a life question" - but is drowning in 1-star reviews for **surprise weekly charges, paywalling scripture, and sycophantic AI**. Text With Jesus drew "blasphemous" press for roleplaying Christ. A Bible Society study found systematic evangelical-default bias across chatbots.

**Real moats (hard to copy authentically):**
- **"Living Manuscript" editorial design + the cross-out ritual** - strongest ownable asset; the cross-out doubles as a share/growth mechanic.
- **The integrated journey** (need -> scripture -> context -> action -> community -> local church -> outreach). Competitors win one or two links; **no one connects the whole chain** - the white space.
- **Trustworthy source-cited AI + premium editorial content together** - the study found no one has both.

**Directionally right but not yet moats** (everyone is racing here; they become moats only with depth + guardrails + usage data): struggle-based personalization, and Kyra. The deterministic engine is what turns personalization into a real edge.

**Table-stakes we currently LACK:** full-text search, Verse of the Day, offline reading, share cards, widgets/lock-screen, basic audio, accessibility, a licensed modern translation. (G2, G3, G4, G5, G8, G19.)

**Blindspots / "what we don't know we don't know":**
- **Moderation is a product, not a promise** - Apple 1.2 needs EULA acceptance, crisis handling, a moderation queue + SLA. Top launch-rejection risk. (G7)
- **Kyra safety is reputational life-or-death** - retrieval-ground every verse (kill hallucination), publish a theological-stance statement, **never roleplay as Jesus**, build crisis handling before an incident. (G6)
- **Licensing is contractual** - translations via API.Bible (~$10-250/mo); NIV needs a Biblica license; music needs licensing beyond CCLI; images/illustrations must be cleared. (G3, G8, G11)
- **Donation/charity compliance** before any in-app giving. (G15)
- **Sensitive-data privacy** - prayer + Kyra logs are highly sensitive; need a clear stance.
- **AI cost control** - free users on live AI bleed money; deterministic-first is the fix, build early. (G1, G19)
- **ASO** - "bible" is unwinnable (~2,650 apps); win on long-tail struggle phrases and "beautiful/modern bible app."
- **Community cold-start** - empty feeds are worse than none; launch **city-by-city / church-by-church** (also solves moderation capacity).
- **Pricing** - avoid the weekly-subscription trap; price **annual-first, ~$49.99-69.99/yr** like Hallow/Glorify.

---

## 5. Recommended roadmap (one phase per gap cluster)

**Guiding call:** ship a **narrow, deep MVP** that fully delivers one transformative loop - "tell us what you're facing -> genuinely relevant scripture -> one action -> share it / attend a church" - rather than a broad-but-shallow version of all 16 areas.

### Tier P0 - Launch-credibility & trust (before any App Store submission)
- **P0-a Bug & mock cleanup (G20):** fix accent + first-name bugs; kill dead buttons; **build-or-hide** Explore, Attend-live, Bridge.
- **P0-b Personalization Engine v1 (G1):** tagged-scripture dataset + deterministic scoring. *The core.*
- **P0-c Bible table-stakes (G2, G19):** search, verse compare, accessibility/offline.
- **P0-d Verse of the Day + widgets + lock-screen (G4).**
- **P0-e Share cards + Bridge outreach web v1 (G5).**
- **P0-f Kyra trust (G6):** retrieval-grounded verses, crisis handling, no-roleplay, stance page, persisted history, remove dead mic.
- **P0-g Moderation + EULA (G7).**
- **P0-h Licensed modern translation (G3):** at least one of NIV/ESV via API.Bible.

### Tier P1 - Differentiators (near launch / fast-follow)
- **P1-a Attend online-church streaming directory (G9).**
- **P1-b Journeys engine + illustrated covers + cooperative leaderboards (G10).**
- **P1-c Popular-verse audio (G8).**
- **P1-d Rich church profiles + "I'm thinking of visiting" (G12).**
- **P1-e Crossed Out Plus (StoreKit) (G18)** - gate premium audio + higher Kyra limits; annual-first.
- **P1-f Entertainment/music transition (G11).**

### Tier P2 - Scale & automation (post-launch; enables "hands-off")
- **P2-a Church auto-discovery + confidence-scored verification + claim flow (G17).**
- **P2-b Short-form feed + AI Bible-video pipeline (G16).**
- **P2-c Automated content/marketing repurposing (G17).**
- **P2-d Events + RSVP (G13).**
- **P2-e Missions marketplace (G14).**
- **P2-f Donation platform + compliance (G15).**
- **P2-g Church SaaS tiers (G18).**

---

## 6. Decisions needed to lock the plan
1. **Launch scope:** narrow-deep MVP (recommended) vs. broader.
2. **Translations:** budget/timeline to license NIV and/or ESV via API.Bible, or launch KJV-first and fast-follow?
3. **Mock screens:** build now vs. hide for v1 (Explore, Attend-live, Bridge)?
4. **Pricing:** confirm annual-first ~$49.99-69.99/yr.
5. **Community launch:** staged city/church-by-church to manage moderation + cold-start?
6. **Kyra guardrails:** confirm retrieval-grounded, non-roleplay, stated-stance as hard requirements.

_Companion docs: NEXT_PHASES.md (Phase 1 runbook), research/ (ElevenLabs audio, church streaming). Full research: app_audit, competitors_bible, competitors_prayer_ai, differentiation_blindspots (delivered in chat)._
