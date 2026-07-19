// refresh_church_streams — scheduled worker.
// For every platform='youtube' church: resolve current live videoId via the
// zero-quota /live canonical-link technique, confirm liveness + viewers with a
// single batched videos.list call (1 quota unit per 50 candidates), then update
// is_live / live_video_id / viewers / last_checked_at and live_services.is_live.
//
// Auth: requires header  x-pipeline-secret: <PIPELINE_SECRET>  (deployed --no-verify-jwt).
// Secrets: YOUTUBE_API_KEY, PIPELINE_SECRET (set via CLI).
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are auto-injected into hosted edge functions.
// Optional: USE_SEARCH_FALLBACK="true" enables search.list (100 units/channel) when
// scraping fails. Leave unset/false unless the scrape technique ever breaks.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const YOUTUBE_API_KEY = Deno.env.get("YOUTUBE_API_KEY") ?? "";
const PIPELINE_SECRET = Deno.env.get("PIPELINE_SECRET") ?? "";
const USE_SEARCH_FALLBACK = (Deno.env.get("USE_SEARCH_FALLBACK") ?? "false") === "true";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36";

type Candidate = { churchId: string; channelId: string; videoId: string | null; scrapeOk: boolean };

// Zero-quota: /channel/{id}/live canonicalizes to watch?v={id} when a live or
// upcoming broadcast exists, and back to the channel URL otherwise.
async function scrapeCandidate(churchId: string, channelId: string): Promise<Candidate> {
  try {
    const res = await fetch(`https://www.youtube.com/channel/${channelId}/live`, {
      headers: {
        "user-agent": UA,
        "accept-language": "en-US,en;q=0.9",
        // Skip EU consent interstitial if the function ever runs in an EU region.
        "cookie": "SOCS=CAI",
      },
      redirect: "follow",
    });
    if (!res.ok) return { churchId, channelId, videoId: null, scrapeOk: false };
    const html = await res.text();
    const m = html.match(
      /<link rel="canonical" href="https:\/\/www\.youtube\.com\/watch\?v=([A-Za-z0-9_-]{11})"/,
    );
    return { churchId, channelId, videoId: m ? m[1] : null, scrapeOk: true };
  } catch (_e) {
    return { churchId, channelId, videoId: null, scrapeOk: false };
  }
}

// Optional expensive fallback: search.list eventType=live (100 units per call).
async function searchLiveVideoId(channelId: string): Promise<string | null> {
  const url = new URL("https://www.googleapis.com/youtube/v3/search");
  url.searchParams.set("part", "id");
  url.searchParams.set("channelId", channelId);
  url.searchParams.set("eventType", "live");
  url.searchParams.set("type", "video");
  url.searchParams.set("maxResults", "1");
  url.searchParams.set("key", YOUTUBE_API_KEY);
  const res = await fetch(url);
  if (!res.ok) return null;
  const data = await res.json();
  return data.items?.[0]?.id?.videoId ?? null;
}

// Authoritative confirmation. 1 quota unit per <=50 ids. Returns the broadcast
// status ("live" / "upcoming" / "none"), viewer count, scheduled start time,
// and title — so callers can surface scheduled streams, not just live ones.
type StreamStatus = {
  status: "live" | "upcoming" | "none";
  viewers: number | null;
  scheduledStart: string | null;
  title: string | null;
};

async function confirmStreams(videoIds: string[]): Promise<Map<string, StreamStatus>> {
  const out = new Map<string, StreamStatus>();
  for (let i = 0; i < videoIds.length; i += 50) {
    const chunk = videoIds.slice(i, i + 50);
    const url = new URL("https://www.googleapis.com/youtube/v3/videos");
    url.searchParams.set("part", "snippet,liveStreamingDetails");
    url.searchParams.set("id", chunk.join(","));
    url.searchParams.set("key", YOUTUBE_API_KEY);
    const res = await fetch(url);
    if (!res.ok) throw new Error(`videos.list failed ${res.status}: ${await res.text()}`);
    const data = await res.json();
    for (const item of data.items ?? []) {
      const lbc = item.snippet?.liveBroadcastContent; // "live" | "upcoming" | "none"
      const cv = item.liveStreamingDetails?.concurrentViewers;
      out.set(item.id, {
        status: lbc === "live" ? "live" : lbc === "upcoming" ? "upcoming" : "none",
        viewers: cv ? parseInt(cv, 10) : null,
        scheduledStart: item.liveStreamingDetails?.scheduledStartTime ?? null,
        title: item.snippet?.title ?? null,
      });
    }
  }
  return out;
}

async function mapPool<T, R>(items: T[], limit: number, fn: (t: T) => Promise<R>): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const i = next++;
      results[i] = await fn(items[i]);
    }
  });
  await Promise.all(workers);
  return results;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  if (!PIPELINE_SECRET || req.headers.get("x-pipeline-secret") !== PIPELINE_SECRET) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { "content-type": "application/json" },
    });
  }
  if (!YOUTUBE_API_KEY) {
    return new Response(JSON.stringify({ error: "YOUTUBE_API_KEY not set" }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }

  const { data: churches, error } = await supabase
    .from("churches")
    .select("id, youtube_channel_id")
    .eq("platform", "youtube")
    .not("youtube_channel_id", "is", null)
    .neq("youtube_channel_id", "");
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }

  const now = new Date().toISOString();
  const candidates = await mapPool(
    churches ?? [],
    10,
    (c) => scrapeCandidate(c.id, c.youtube_channel_id as string),
  );

  // Optional fallback for scrape failures (expensive: 100 units each).
  if (USE_SEARCH_FALLBACK) {
    for (const c of candidates) {
      if (!c.scrapeOk) {
        c.videoId = await searchLiveVideoId(c.channelId);
        c.scrapeOk = true; // treat fallback result as authoritative discovery
      }
    }
  }

  const idsToConfirm = [...new Set(candidates.filter((c) => c.videoId).map((c) => c.videoId!))];
  let statuses = new Map<string, StreamStatus>();
  let confirmError: string | null = null;
  try {
    if (idsToConfirm.length > 0) statuses = await confirmStreams(idsToConfirm);
  } catch (e) {
    confirmError = String(e);
  }

  let liveCount = 0, upcomingCount = 0, offlineCount = 0, skipped = 0;
  for (const c of candidates) {
    if (!c.scrapeOk || confirmError) {
      // Transient failure: don't kill a possibly-live embed; just stamp the check.
      skipped++;
      await supabase.from("churches").update({ last_checked_at: now }).eq("id", c.churchId);
      continue;
    }
    const st = c.videoId ? statuses.get(c.videoId) : undefined;
    const kind = st?.status ?? "none";

    if (kind === "live") {
      await supabase.from("churches").update({
        is_live: true, live_video_id: c.videoId, viewers: st?.viewers ?? null, last_checked_at: now,
      }).eq("id", c.churchId);
      const ls: Record<string, unknown> = { is_live: true, scheduled_start_at: null, upcoming_video_id: null };
      if (st?.title) ls.title = st.title;
      await supabase.from("live_services").update(ls).eq("church_id", c.churchId);
      liveCount++;
    } else if (kind === "upcoming") {
      await supabase.from("churches").update({
        is_live: false, live_video_id: null, viewers: null, last_checked_at: now,
      }).eq("id", c.churchId);
      const ls: Record<string, unknown> = {
        is_live: false, scheduled_start_at: st?.scheduledStart ?? null, upcoming_video_id: c.videoId,
      };
      if (st?.title) ls.title = st.title;
      await supabase.from("live_services").update(ls).eq("church_id", c.churchId);
      upcomingCount++;
    } else {
      await supabase.from("churches").update({
        is_live: false, live_video_id: null, viewers: null, last_checked_at: now,
      }).eq("id", c.churchId);
      await supabase.from("live_services").update({
        is_live: false, scheduled_start_at: null, upcoming_video_id: null,
      }).eq("church_id", c.churchId);
      offlineCount++;
    }
  }

  return new Response(
    JSON.stringify({
      checked: candidates.length,
      live: liveCount,
      upcoming: upcomingCount,
      offline: offlineCount,
      skipped_transient: skipped,
      confirm_error: confirmError,
      quota_units_spent: Math.ceil(idsToConfirm.length / 50),
      at: now,
    }),
    { headers: { "content-type": "application/json" } },
  );
});
