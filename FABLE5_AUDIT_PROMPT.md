# Prompt for Fable 5 — Full App Audit: Crossed Out

_Paste everything below the line into Fable 5. It is written to be run against
the repo at `~/Projects/Crossed Out` with file access. If Fable 5 has no file
access, attach: MASTER_PLAN.md, DESIGN_LANGUAGE.md, GAP_ANALYSIS_AND_ROADMAP.md,
the `CrossedOut/` source tree, and the `supabase/migrations/` folder._

---

## Role
You are a senior product + technical auditor for **Crossed Out**, a premium
Christian formation iOS app (SwiftUI, Supabase backend, an AI guide named Kyra).
Produce a rigorous, evidence-based audit — not a pep talk. Every claim about what
is or isn't built must cite a file/path or migration as evidence. Distinguish
sharply between **shipped** (working code + backend), **partial**, **mock/stub**
(UI exists but wired to `MockData` or no backend), and **missing**.

## Inputs (read these first, in order)
1. `MASTER_PLAN.md` — the intended product vision + full feature set.
2. `DESIGN_LANGUAGE.md` — the intended design system + experience principles.
3. `GAP_ANALYSIS_AND_ROADMAP.md` — an EXISTING internal gap analysis + roadmap
   (§1 audit, §2 capability areas, §3 gap register, §4 competitive lens, §5
   roadmap, §7 G19 devotionals, §8 backlog, §9 deterministic-first AI principle).
   **Build on this and pressure-test it — do not just restate it.** Flag where it
   is now out of date (e.g. Bible tagging is complete; G19 slice 1 + Tier 2/3 are
   built).
4. Ground truth in code:
   - `CrossedOut/Features/*` (Today, Bible, Devotionals, Progress, Explore,
     Profile, Onboarding, Community/Bridge, Give, Church/Attend) — what each
     screen actually does; note anything reading from `Services/MockData.swift`.
   - `CrossedOut/Services/SupabaseService*.swift` — what's actually wired to the
     backend (the real feature surface).
   - `supabase/migrations/*.sql` — the real data model + RPCs (0001→0017).
   - `supabase/functions/*` — deployed AI/edge capability (kyra, semantic_search,
     devotional_suggest).

## Deliverable — three parts

### Part A — Feature-set audit vs. the master plan
A table of every capability area in MASTER_PLAN.md with columns:
`Capability | Planned intent | Status (Shipped/Partial/Mock/Missing) | Evidence
(file or migration) | Notes`. Then a short narrative: what's genuinely done, what
looks done but is mock, and the 5 biggest gaps between plan and reality. Call out
launch-blockers explicitly (auth hardening deploy, UGC/EULA for App Review,
monitoring — verify their status in code rather than assuming).

### Part B — Competitor analysis
Assess Crossed Out against the current Christian-app market — at minimum
YouVersion Bible, Hallow, Glorify, Pray.com, Abide, Dwell, and any others you
judge relevant. For each: their core wedge, monetization, and where Crossed Out
is at **parity**, **behind**, or **differentiated**. Then synthesize: what is
Crossed Out's defensible wedge (candidates: the deterministic + gated-AI
personalization engine, Kyra as a grounded non-roleplay guide, the "cross out /
formation" metaphor, community + bridge sharing), and where it is merely
achieving parity vs. truly differentiating. Be honest about weak differentiation.

### Part C — Prioritized gap register + recommendations
A ranked list of gaps (feature, quality, and competitive). For each: the gap, why
it matters (user + business + App Review risk), effort (S/M/L), and a
recommendation. Group into **P0 launch-blockers**, **P1 differentiators**, **P2
scale**. Close with a recommended sequence to first App Store submission and the
2–3 bets most likely to make the app stand out.

## Rules
- Evidence over assertion. If you can't verify something in the code/docs, say so.
- Prefer the code as ground truth over the planning docs where they disagree.
- Be specific and critical; surface uncomfortable gaps and weak differentiation.
- Where you make market claims about competitors, mark anything you're unsure of
  as needing verification (the market moves; don't state stale facts as current).
- Keep it skimmable: tables + tight prose, no filler.
