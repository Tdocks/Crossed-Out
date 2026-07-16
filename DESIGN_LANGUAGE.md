# Crossed Out — Design Language v1.0
### The Living Manuscript
_Canonical visual + interaction system. Hand this (plus reference images) to any human or AI builder. Companion: MASTER_PLAN.md (product), GAP_ANALYSIS_AND_ROADMAP.md (build order)._

## Philosophy
Crossed Out should feel less like an app and more like opening something sacred that belongs to you — a well-used journal, a beautifully typeset Bible, and a premium editorial magazine blended into a modern native iOS app. Every interaction communicates peace, clarity, intentionality, warmth, permanence, humanity. **Never trendiness. Never "artificial intelligence." Never social media.** The app does not chase attention; it invites presence.

**Design thesis:** *The interface disappears so the experience can remain.* Think Apple HIG × Kinfolk × a premium hardcover Bible × Moleskine × NYT Magazine — NOT ChatGPT, AI startups, crypto dashboards, SaaS admin panels, or social feeds.

**The Golden Rule:** the interface must never compete with Scripture. Whenever Scripture is on screen, Scripture is the visual hierarchy; everything else is supporting information.

## Emotional goals
Every screen should make the user feel one or more of: **seen, calm, curious, hopeful, connected, safe, inspired.** This is a *presence* product, not a dopamine product.

## What to AVOID
**"AI slop" conventions:** purple→blue gradients as identity, glowing AI orbs/spheres, glassmorphism everywhere, floating chatbot cards on every screen, sparkles on routine actions, generated ethereal landscapes behind Scripture, everything rounded, generic smiling stock models, giant motivational headlines with little substance, neon crosses, "Powered by AI" as a brand message, every card its own gradient, every screen a hero image.
**Stereotypical Christian-app clichés:** beige + cursive, watercolor mountains, sunsets behind verses, gold cross logos, dove silhouettes, open-Bible clip art, church stock photography, rustic-farmhouse or luxury-worship-album styling, handwriting fonts everywhere, lavender as a substitute for personality. Crossed Out is unmistakably Christian through substance, language, symbolism, and behavior — not a decorative cross on every screen.

## Core principles
1. Scripture is always the visual hierarchy.
2. White space is sacred — every screen breathes; slightly-too-empty is usually correct.
3. Typography carries the experience (the app could nearly function without illustration).
4. Content first, chrome second, decoration last.
5. Motion has purpose — never decorate with movement.
6. Depth on demand, peace by default (study tools appear when asked).
7. Reading should feel like reading, not operating software.
8. Personalization is visible — tell users *why* something was chosen.
9. Commercial elements stay out of sacred moments.
10. The app should age well (avoid 18-month trends).

## Brand motifs (only two)
- **Cross Out** — release, completion, transformation. Applies to fears, shame, isolation, old identity, completed habits/devotionals, answered prayers, finished tasks. **Never strike through actual Scripture.** A fine hand-drawn/editorial strike; used sparingly it becomes a signature. E.g. `~~I am forgotten.~~ I am seen.`
- **Bridge** — relationship, movement, invitation. Faith, community, church, friendship, mission, outreach, growth. Appears in Bridge Shares, new-believer journeys, church transitions, online→in-person, invitations. Needn't be a literal bridge: a line joining two profile circles, two panels connected by a thin path, a progress path crossing a gap, a subtle arch.

## Color — Ink, Paper, Clay, Light
~85% neutral surfaces, ~15% intentional accent. Color communicates meaning, not decoration. Never make every feature a different bright color.

**Light mode**
- Warm Paper (primary bg) `#F7F3EC`
- Clean Paper (reading/elevated) `#FCFAF6`
- Elevated cards `#FFFFFF`
- Carbon Ink (primary text) `#171717`
- Warm Graphite (secondary text) `#55514A`
- Tertiary text `#8B857B`
- Quiet Rule (dividers) `#D9D2C7`
- **Cross Red** (primary accent — CTAs, current nav, cross-out, prayer/answered) `#B5412C`
- **Wisdom Blue** (church, study, guidance) `#2D566A`
- **Living Olive** (growth, journeys, completed habits, service) `#69744D`
- **Candle Gold** (milestones, saved passages, bookmarks — sparing) `#C89B52`
Subtle paper-grain texture allowed at very low opacity (never distracting).

**Dark mode** — ink & candlelight, NOT a black SaaS dashboard; keep warm undertones, never blue-black, never neon.
- Night Ink (primary bg) `#121311`
- Raised Ink (secondary) `#1A1B19`
- Cards `#20211F` (almost flat)
- Warm Paper (primary text) `#EEE7DA`
- Secondary text `#B7B1A5`
- Dividers `#2E2F2B`
- Cross Ember (red) `#C14D37`
- Olive `#78845C` · Wisdom Blue `#527892` · Gold `#D1A35B`

## Typography (the product)
- **Scripture:** an elegant, highly readable literary serif — strong italics, beautiful quotation marks, comfortable paragraph spacing, long-form optimized, broad language support. Literary and contemporary, not old-fashioned, not fashion-editorial to the point of harming readability. (Current impl uses Playfair Display for scripture/display.)
- **Interface:** a clean, restrained geometric sans (neutral, never trendy) for nav, controls, metadata, filters, streaks, listings. (Current impl uses Inter.)
- **Display:** a related editorial face for campaign headlines / journey covers / section intros. Never three unrelated font personalities on one screen.
- Signature combination: **literary serif Scripture + disciplined sans interface + editorial strike mark.**

## Shape & components
- **Cards only when content needs containment** — not the default layout. Scripture generally sits directly on the page like a printed book, not trapped in a card.
- Reduce pills — use only for filters, compact statuses, topic selection, live indicators, short toggles. Not every button/card/stat.
- Three intentional corner radii: small (controls/fields), medium (content modules), large (immersive media). A Bible page can have no cards at all.
- Prefer hairline rules / spacing / typographic separation / background shifts over stacked floating cards.
- Buttons: firm, editorial, solid ink or Cross Red, clear silhouette, moderate corners, specific labels ("Begin today's reading," not "Continue"). No gradients/glow/giant shadows. Secondary actions recede visually.
- Inputs: soft borders, comfortable height, minimal decoration, focus state in Cross Red.

## Iconography
Custom, thin, monoline, editorial, purposeful — inspired by margin symbols, bookmaking marks, line engraving, wayfinding. Slightly imperfect at large sizes; geometrically consistent; no emoji styling, no filled blobs, no sparkles. Signature icons: cross-out mark, bridge path, open margin, prayer candle, live-service doorway, shared journey, answered prayer, Scripture thread. **Kyra** gets one subtle mark (an illuminated K / dialogue mark / guiding registration mark) — never a glowing orb.

## Photography & illustration
**Documentary, not advertising:** real churches, worship, coffee, notebooks, volunteers, conversations, architecture, light and detail — observed, not staged. Avoid people smiling at camera, corporate-diverse arrangements, lens flares, AI-looking hands/people, generic mountains, a cross in every image. Church media prioritizes actual sanctuary / preacher / congregation / livestream frame (builds trust). Treatment: natural contrast, warm highlights, restrained saturation, documentary crops, occasional duotone — never one heavy filter flattening every church and skin tone.
**Proprietary illustration system:** editorial, sophisticated, warm, organic, slightly textured, limited palette. Every journey ("Finding Peace," "Financial Wisdom," "Returning to Faith," "Who Is Jesus?," "Forgiveness," "Purpose," "Hope," "Marriage," "Prayer") gets a recognizable cover — like Headspace's illustration or Duo. This single decision separates Crossed Out from the stock-photo/AI-art sea.

## Motion
Meaning, not spectacle. Signature motions: **cross-out completion** (a fine line draws across the item, then the replacement truth appears); **bridge transition** (two points connect with a moving line when a friend accepts, a church is saved, a shared journey begins, a Bridge Share is answered); **Scripture reveal** (by paragraph/thought — never word-by-word AI typing); **page movement** (Bible chapters transition laterally/vertically like passing through a text); **Grace Day** (the missed day gently folds into the timeline — never shatters). Avoid floating blobs, shimmer everywhere, confetti/fireworks on spiritually sensitive actions, casino animations, aggressive haptics. Celebration matches the emotional weight of the action.

## Kyra's presentation
Invited, not omnipresent. Opened via "Ask about this passage," "Help me reflect," "Create a prayer," "Talk through this," "Help me share this." Feels like a focused conversation margin / study dialogue / journal exchange with Scripture references integrated — NOT a mystical oracle chamber, control room, therapy bot, or central orb. **Response structure:** Scripture (source/citation) → Context (what's happening) → What this may mean for you (carefully framed application) → A next step (reflection, prayer, action, or discussion). This structure also kills the "AI wall of text" feeling.

## Screen feel
- **Today — "The Daily Page":** a fresh journal page each morning. `TUESDAY · JULY 14 · Day 18`, a quiet greeting ("Tyler, what are you carrying today?"), the selected focus in plain language ("You said: 'I need wisdom about money and direction.'"), then personalized passage + one-line reason it was chosen + read/listen + context + reflection + today's action + optional music/sermon. Streak visible but not dominant. No dashboard, no graphs.
- **Bible — "The Quiet Reader":** navigation recedes, clean-paper background, serif typography IS the experience, tap reveals tools, long-press selects a verse, a margin rail holds notes/highlights/context, swipe changes chapter, a subtle reading-progress thread at the edge. No feed modules beneath chapters.
- **Attend — "The Front Door":** cinematic, time-aware. "Services happening now" → live now / begins in 18 min / tonight / tomorrow. Each church card carries decision-relevant info (church, ministry style, sermon approach, worship style, length, distance, verified status). Metaphor: entering a doorway — not Netflix.
- **Community — "The Common Table":** a church lobby after service, not Reddit/Facebook/Instagram. Organized by my circle / my church / prayer / journeys / local. Prayer requests are NOT treated like posts chasing likes. Actions: "I prayed," "Send encouragement," "Check in privately," "Share a passage." No vanity metrics.
- **Bridge Share — "Between Us":** composition visibly connects sender and recipient (left: what I wanted to share · center: a subtle bridge line · right: why I thought of you). The verse comes AFTER the personal message.
- **Progress — "What's Being Rewritten":** not an analytics dashboard. "What you're working through" with crossed-out negatives (`~~I have to carry this alone~~`, `~~I am too far behind~~`) above current focuses, then streak, weekly rhythm, journey progress, prayers revisited, themes encountered, people encouraged.
- **Explore:** editorial, curated cultural-guide density — not algorithm spam.
- **Music:** discovery through a trusted friend (albums, artists, playlists) — not an infinite feed.
- **Church Finder:** finding your next church family — not browsing businesses.
- **Give:** participating in God's work — impact first, money second, not a checkout.

## Voice (copy)
The interface speaks quietly. "Today's reading is complete." (not "🔥 YOU DID IT!!"). "A plan created around what you're walking through." (not "AI GENERATED PLAN"). "You're growing." (not "LEVEL UP"). Tell users *why*: "Selected because you asked for help with uncertainty and purpose."

## App icon / logo
Not a generic cross in a rounded square. A compact wordmark/monogram where a horizontal strike passes through part of the lettering and subtly forms a cross, with negative space suggesting a bridge/open path; works in one color; recognizable at icon size. Concepts: the "Crossed O" (interrupted then reconnected by a crossbar); a CO monogram whose stroke crosses one letter and continues outward like a bridge; an "open mark" that crosses something out but ends by opening a path. Icon palette: Carbon Ink background, Scripture Paper mark, one Cross Red line — apart from the sea of blue/purple/white/gold Christian icons.

## Accessibility & native iOS
Support Dynamic Type; minimum AA contrast; readable by older users, beautiful for younger; never sacrifice readability for style. Build like a premium Apple app: native transitions, smooth scrolling, meaningful haptics, interactive gestures, fluid page transitions, context menus, large touch targets, respect safe areas. Avoid Android-inspired patterns.

## The design laws (enforce in review)
1. Scripture receives the most visual respect. 2. One primary intention per screen. 3. AI is available but never dominates. 4. Cards only when objects need containment. 5. Real people/places outrank generated imagery. 6. Celebration must fit the action. 7. Personalization is visible. 8. Spiritual depth is progressively revealed. 9. Commercial elements stay outside sacred moments (no subscription banners in Bible reading, active prayer, crisis content, a live service, or a received Bridge Share). 10. The app should age well.

## The one question
Before approving any screen: *Does this feel like a place I'd want to spend twenty quiet minutes with God?* And: Does it respect Scripture? Reduce distraction? Feel handcrafted rather than AI-generated? Still look premium in five years? If any answer is "no," redesign it.

## Final direction
Crossed Out should not look like "an AI Bible app made in 2026." It should look like **a contemporary Christian publication, personal journal, and community platform that happens to be extraordinarily intelligent** — editorial typography + warm paper and ink + documentary media + functional cross-out and bridge gestures + native interaction quality + quiet AI = **The Living Manuscript.** Goal: not the most beautiful Christian app — the most *trusted*. Every choice reinforces one feeling: "This app respects both Scripture and me."

## Recommended next artifact
A full 80–120 page design system (tokens, grids, spacing, type scales, motion, every component, every screen state, interaction patterns) — the Christian equivalent of Apple's HIG — before production screens scale. It keeps every future feature and contributor visually and behaviorally consistent.
