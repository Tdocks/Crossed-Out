// explore_sermons — scheduled ingestion for the Explore "Sermons" vertical.
//
// Allowlist = churches already in the DB that have a real youtube_channel_id
// (seeded from the church table the user curates). For each channel we read
// its "uploads" playlist (channelId UCxxx -> uploads UUxxx) and pull the most
// recent videos with a single playlistItems.list call (1 quota unit each),
// then upsert them into explore_items. Deterministic, cheap, idempotent.
//
// Auth: header  x-pipeline-secret: <PIPELINE_SECRET>  (deploy --no-verify-jwt).
// Secrets: YOUTUBE_API_KEY, PIPELINE_SECRET. SUPABASE_URL / SERVICE_ROLE_KEY
// are auto-injected. Optional: EXPLORE_SERMONS_PER_CHANNEL (default 6).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const YOUTUBE_API_KEY = Deno.env.get("YOUTUBE_API_KEY") ?? "";
const PIPELINE_SECRET = Deno.env.get("PIPELINE_SECRET") ?? "";
const PER_CHANNEL = parseInt(Deno.env.get("EXPLORE_SERMONS_PER_CHANNEL") ?? "6", 10);

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

type PlaylistItem = {
  videoId: string;
  title: string;
  channelTitle: string;
  thumb: string | null;
  publishedAt: string | null;
};

// A channel's uploads playlist id is the channel id with the 2nd char flipped:
// UC... -> UU...  (documented, stable YouTube convention).
function uploadsPlaylistId(channelId: string): string | null {
  if (!channelId.startsWith("UC") || channelId.length < 3) return null;
  return "UU" + channelId.slice(2);
}

function bestThumb(thumbs: Record<string, { url: string }> | undefined): string | null {
  if (!thumbs) return null;
  return (thumbs.high ?? thumbs.medium ?? thumbs.default)?.url ?? null;
}

async function fetchUploads(channelId: string): Promise<PlaylistItem[]> {
  const playlistId = uploadsPlaylistId(channelId);
  if (!playlistId) return [];
  const url = new URL("https://www.googleapis.com/youtube/v3/playlistItems");
  url.searchParams.set("part", "snippet,contentDetails");
  url.searchParams.set("playlistId", playlistId);
  url.searchParams.set("maxResults", String(Math.min(Math.max(PER_CHANNEL, 1), 50)));
  url.searchParams.set("key", YOUTUBE_API_KEY);
  const res = await fetch(url);
  if (!res.ok) {
    console.error(`playlistItems failed for ${channelId}: ${res.status} ${await res.text()}`);
    return [];
  }
  const data = await res.json();
  const items: PlaylistItem[] = [];
  for (const it of data.items ?? []) {
    const vid = it.contentDetails?.videoId ?? it.snippet?.resourceId?.videoId;
    const sn = it.snippet ?? {};
    // Skip private/deleted placeholders.
    if (!vid || sn.title === "Private video" || sn.title === "Deleted video") continue;
    items.push({
      videoId: vid,
      title: sn.title ?? "Untitled",
      channelTitle: sn.videoOwnerChannelTitle ?? sn.channelTitle ?? "",
      thumb: bestThumb(sn.thumbnails),
      publishedAt: it.contentDetails?.videoPublishedAt ?? sn.publishedAt ?? null,
    });
  }
  return items;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  if (!PIPELINE_SECRET || req.headers.get("x-pipeline-secret") !== PIPELINE_SECRET) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401, headers: { "content-type": "application/json" },
    });
  }
  if (!YOUTUBE_API_KEY) {
    return new Response(JSON.stringify({ error: "YOUTUBE_API_KEY not set" }), {
      status: 500, headers: { "content-type": "application/json" },
    });
  }

  // Allowlist from the curated church table.
  const { data: churches, error } = await supabase
    .from("churches")
    .select("name, youtube_channel_id")
    .not("youtube_channel_id", "is", null)
    .neq("youtube_channel_id", "");
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500, headers: { "content-type": "application/json" },
    });
  }

  const rows: Record<string, unknown>[] = [];
  let channelsOk = 0;
  for (const c of churches ?? []) {
    const channelId = c.youtube_channel_id as string;
    const items = await fetchUploads(channelId);
    if (items.length > 0) channelsOk++;
    for (const it of items) {
      rows.push({
        vertical: "sermons",
        source: "youtube",
        source_item_id: it.videoId,
        title: it.title,
        subtitle: it.channelTitle || (c.name as string),
        thumbnail_url: it.thumb,
        open_url: `https://www.youtube.com/watch?v=${it.videoId}`,
        app_url: `vnd.youtube://www.youtube.com/watch?v=${it.videoId}`,
        published_at: it.publishedAt,
        is_active: true,
      });
    }
  }

  let upserted = 0;
  if (rows.length > 0) {
    const { error: upErr, count } = await supabase
      .from("explore_items")
      .upsert(rows, { onConflict: "source,source_item_id", count: "exact" });
    if (upErr) {
      return new Response(JSON.stringify({ error: upErr.message }), {
        status: 500, headers: { "content-type": "application/json" },
      });
    }
    upserted = count ?? rows.length;
  }

  return new Response(
    JSON.stringify({
      channels_checked: (churches ?? []).length,
      channels_with_videos: channelsOk,
      items_upserted: upserted,
      at: new Date().toISOString(),
    }),
    { headers: { "content-type": "application/json" } },
  );
});
