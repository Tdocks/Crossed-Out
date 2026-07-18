# Fable 5 brief — fix the YouTube live embed + build a reliable church-streaming pipeline

## Role
You are a senior iOS (SwiftUI) + Supabase (Postgres + Deno edge functions)
engineer working on **Crossed Out**, a Christian app. Fix a broken YouTube live
embed and design + build a reliable, automated pipeline for (a) adding new
churches by their YouTube channel and (b) keeping every church's live status +
current live video fresh so the app always embeds the correct broadcast.

## The bug
The Attend "Watch Live" screen embeds a church's stream via
`https://www.youtube.com/embed/live_stream?channel={CHANNEL_ID}`. This shows
**"This video is unavailable. Error code: 152-4."** The `live_stream?channel=`
embed is deprecated/unreliable, and the `is_live` flags are hardcoded seed data
that don't reflect real YouTube live status. Current player code:

```swift
// StreamPlayer.swift — the broken part
struct YouTubeLiveEmbedView: UIViewRepresentable {
    let channelId: String
    // ...loads: https://www.youtube.com/embed/live_stream?channel=\(channelId)&autoplay=1&playsinline=1
}
enum WatchSource: Identifiable, Hashable { case youtube(channelId: String); case hls(url: URL); /* id... */ }
```
```swift
// ServiceDetailView.startWatching()
if ch.platform == "youtube", let cid = ch.youtubeChannelId, !cid.isEmpty {
    watchSource = .youtube(channelId: cid)     // <-- embeds by channel (unreliable)
} else if ch.platform == "hls", let s = ch.hlsURL, ... { watchSource = .hls(url: URL(string:s)!) }
else if let w = ch.watchURL, ... { openURL(u) }        // link-out fallback
else { /* youtube search link-out */ }
```

## Data model (Postgres `public.churches`)
Columns: id uuid, name, city, rating, style, distance_miles, is_live bool,
viewers int, accent, **platform text ('youtube'|'hls'|'facebook'|'web'),
youtube_channel_id text, hls_url text, watch_url text, thumbnail_url text,
denomination text**. `public.live_services(id, church_id, title, starts_in,
service_time, is_live)`. The app model `Church` + `ChurchDTO` decode these
(snake_case); `fetchLiveServices()` fetches churches + live_services and joins.

## Backend context
- Supabase project ref `wqumwxoiqsiwizlftojq`; URL
  `https://wqumwxoiqsiwizlftojq.supabase.co`; publishable (anon) key
  `sb_publishable_W6kfGB2XfRAYvV_kfe_tWA_NiAdhZmL` (public).
- Edge functions live in `supabase/functions/<name>/index.ts` (Deno, esm.sh
  supabase-js), deployed via a script like `deploy_kyra.sh`:
  `source supabase/.env.local; supabase secrets set X=$X --project-ref ...;
  supabase functions deploy <name> --project-ref ... --use-api`.
- Migrations are numbered SQL files; the next is **0020**.
- The app calls edge functions via URLSession POST with `Authorization: Bearer
  <session jwt>` + `apikey: <publishable>` (see kyra).

## Requirements
**A. Fix the embed.** Embed the actual live **video by its videoId**
(`https://www.youtube.com/embed/{videoId}?autoplay=1&playsinline=1&rel=0`), not
`live_stream?channel`. The app reads a stored current `live_video_id` from the DB.
When a church has no current live video, don't show a dead embed — link out or
show a graceful "not live right now" state.

**B. The pipeline (core deliverable).** Reliable + automated:
  1. **Add a church** by YouTube handle or URL: resolve its channelId (YouTube
     Data API v3 `channels`/`search`), fetch name/thumbnail, insert the church.
  2. **Refresh** every church on a schedule: use the YouTube Data API to
     determine real live status, the current live videoId, and viewer count;
     update `is_live`, `live_video_id`, `viewers`, `last_checked_at`. The app
     just reads these — it must NOT call the YouTube API on app open.
  3. **Respect quota:** YouTube Data API = 10,000 units/day; `search` costs 100
     units, `videos`/`channels` cost ~1. Design the refresh to stay well under
     quota (e.g., cost per church per cycle, cadence, and how many churches that
     supports). Prefer cheap calls where possible; document the math.

**C. Deliverables (complete + ready to apply — you have NO repo/DB access, so
output full artifacts):**
  - Migration `0020_church_live_pipeline.sql` (new columns e.g. `live_video_id
    text`, `last_checked_at timestamptz`, `youtube_handle text`; any helper
    RPCs; keep it idempotent).
  - Edge function(s): `refresh_church_streams` (the scheduled refresher) and an
    `add_church` admin function (resolve handle -> channelId -> insert). Full
    `index.ts` for each, mirroring the kyra/deploy pattern. Include a
    `deploy_*.sh` for each.
  - **Scheduling**: recommend and provide the concrete mechanism — Supabase
    `pg_cron` + `pg_net` calling the edge function on an interval (give the SQL),
    or an external cron; note the trade-offs.
  - **Swift changes** (precise before/after): `WatchSource` carries a `videoId`;
    `StreamPlayer` embeds by videoId; `ServiceDetailView.startWatching` uses the
    stored `live_video_id`; `Church`/`ChurchDTO` gain `liveVideoId`.
  - **Setup runbook**: how to create a YouTube Data API key in Google Cloud
    (enable "YouTube Data API v3"), set it as a Supabase secret
    (`YOUTUBE_API_KEY`), deploy the functions, schedule the refresh, and add the
    first churches. Include how the existing seeded channels (Life.Church
    `UCoDt562cJaageYU-LYKt4Pw`, Elevation `UCIQqvZbHSwX0yKNVK1MyYjQ`,
    Transformation `UCETv6h2iCi2FpVAFPPmpytg`) get picked up.

**D. Verify your approach with web search** (YouTube Data API live-broadcast
resolution, embedding by videoId, quota costs, `eventType=live` search) so the
method is current and correct — cite what you rely on.

## Output format
Your FINAL MESSAGE is the deliverable and will be applied verbatim by the main
agent. Structure it as an ordered implementation package: (1) short design +
quota math, (2) each new/changed file with its full contents or a precise
before/after, (3) the scheduling SQL, (4) the setup runbook, (5) a smoke-test
checklist. Be concrete and complete — no placeholders left for the reader.
