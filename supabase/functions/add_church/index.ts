// add_church — admin endpoint to add (or update) a church by YouTube handle,
// channel URL, or channel ID. Resolves channelId + title + thumbnail via
// channels.list (1 quota unit; supports forHandle), upserts into churches on
// youtube_channel_id, then immediately runs a live check so the row is fresh.
//
// Auth: requires header  x-pipeline-secret: <PIPELINE_SECRET>  (deployed --no-verify-jwt).
//
// POST body:
// {
//   "input": "@lifechurch" | "lifechurch" | "https://www.youtube.com/@lifechurch"
//            | "https://www.youtube.com/channel/UCoDt562cJaageYU-LYKt4Pw"
//            | "UCoDt562cJaageYU-LYKt4Pw",
//   "name"?: string, "city"?: string, "denomination"?: string, "style"?: string,
//   "accent"?: string, "rating"?: number, "distance_miles"?: number
// }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const YOUTUBE_API_KEY = Deno.env.get("YOUTUBE_API_KEY") ?? "";
const PIPELINE_SECRET = Deno.env.get("PIPELINE_SECRET") ?? "";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

// Returns a channel id / handle / video reference from any accepted input form:
// @handle, bare handle, channel URL, UC… id, OR a video/watch/live/shorts/
// youtu.be/embed link (resolved to its channel).
function parseInput(raw: string): { kind: "id" | "handle" | "video"; value: string } | null {
  const input = raw.trim();
  // Video-style links first — a watch/live/shorts/embed/youtu.be URL carries an
  // 11-char video id, which we resolve to its owning channel below.
  const videoMatch = input.match(/(?:[?&]v=|youtu\.be\/|\/live\/|\/shorts\/|\/embed\/)([A-Za-z0-9_-]{11})/);
  if (videoMatch) return { kind: "video", value: videoMatch[1] };
  const idMatch = input.match(/(UC[A-Za-z0-9_-]{22})/);
  if (idMatch) return { kind: "id", value: idMatch[1] };
  const urlHandle = input.match(/youtube\.com\/@([A-Za-z0-9._-]+)/i);
  if (urlHandle) return { kind: "handle", value: "@" + urlHandle[1] };
  const bare = input.replace(/^@/, "");
  if (/^[A-Za-z0-9._-]{3,30}$/.test(bare)) return { kind: "handle", value: "@" + bare };
  return null;
}

async function resolveChannel(ref: { kind: "id" | "handle" | "video"; value: string }): Promise<
  { channelId: string; title: string; thumbnail: string | null; handle: string | null } | null
> {
  // A video reference: look up the video to find its channel id, then fall
  // through to the normal channel resolution by id.
  if (ref.kind === "video") {
    const vurl = new URL("https://www.googleapis.com/youtube/v3/videos");
    vurl.searchParams.set("part", "snippet");
    vurl.searchParams.set("id", ref.value);
    vurl.searchParams.set("key", YOUTUBE_API_KEY);
    const vres = await fetch(vurl);
    if (!vres.ok) throw new Error(`videos.list failed ${vres.status}: ${await vres.text()}`);
    const vdata = await vres.json();
    const channelId = vdata.items?.[0]?.snippet?.channelId;
    if (!channelId) return null;
    ref = { kind: "id", value: channelId };
  }

  const url = new URL("https://www.googleapis.com/youtube/v3/channels");
  url.searchParams.set("part", "snippet");
  if (ref.kind === "id") url.searchParams.set("id", ref.value);
  else url.searchParams.set("forHandle", ref.value);
  url.searchParams.set("key", YOUTUBE_API_KEY);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`channels.list failed ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const item = data.items?.[0];
  if (!item) return null;
  const sn = item.snippet ?? {};
  const thumb = sn.thumbnails?.high?.url ?? sn.thumbnails?.medium?.url ?? sn.thumbnails?.default?.url ?? null;
  return {
    channelId: item.id,
    title: sn.title ?? "Unknown Church",
    thumbnail: thumb,
    handle: sn.customUrl ?? (ref.kind === "handle" ? ref.value : null), // customUrl is "@handle"
  };
}

// Same zero-quota + 1-unit confirm technique as refresh_church_streams.
async function currentLive(channelId: string): Promise<{ videoId: string | null; viewers: number | null }> {
  try {
    const page = await fetch(`https://www.youtube.com/channel/${channelId}/live`, {
      headers: { "user-agent": UA, "accept-language": "en-US,en;q=0.9", "cookie": "SOCS=CAI" },
      redirect: "follow",
    });
    if (!page.ok) return { videoId: null, viewers: null };
    const html = await page.text();
    const m = html.match(
      /<link rel="canonical" href="https:\/\/www\.youtube\.com\/watch\?v=([A-Za-z0-9_-]{11})"/,
    );
    if (!m) return { videoId: null, viewers: null };
    const url = new URL("https://www.googleapis.com/youtube/v3/videos");
    url.searchParams.set("part", "snippet,liveStreamingDetails");
    url.searchParams.set("id", m[1]);
    url.searchParams.set("key", YOUTUBE_API_KEY);
    const res = await fetch(url);
    if (!res.ok) return { videoId: null, viewers: null };
    const data = await res.json();
    const item = data.items?.[0];
    if (item?.snippet?.liveBroadcastContent === "live") {
      const cv = item.liveStreamingDetails?.concurrentViewers;
      return { videoId: m[1], viewers: cv ? parseInt(cv, 10) : null };
    }
    return { videoId: null, viewers: null };
  } catch {
    return { videoId: null, viewers: null };
  }
}

// Authorize a request: allow EITHER the shared pipeline secret (the CLI /
// add_church.sh) OR a signed-in system_admin's JWT (the in-app Add Church
// screen). The function is deployed --no-verify-jwt, so we verify here.
async function isAuthorized(req: Request): Promise<boolean> {
  if (PIPELINE_SECRET && req.headers.get("x-pipeline-secret") === PIPELINE_SECRET) {
    return true;
  }
  const authz = req.headers.get("Authorization") ?? "";
  const token = authz.startsWith("Bearer ") ? authz.slice(7).trim() : "";
  if (!token) return false;
  try {
    const { data: u } = await supabase.auth.getUser(token);
    const uid = u?.user?.id;
    if (!uid) return false;
    const { data: prof } = await supabase
      .from("profiles").select("role").eq("id", uid).maybeSingle();
    return prof?.role === "system_admin";
  } catch {
    return false;
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  if (!(await isAuthorized(req))) return json({ error: "unauthorized" }, 401);
  if (!YOUTUBE_API_KEY) return json({ error: "YOUTUBE_API_KEY not set" }, 500);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }
  const input = typeof body.input === "string" ? body.input : "";
  const ref = parseInput(input);
  if (!ref) return json({ error: `could not parse channel reference from "${input}"` }, 400);

  let channel;
  try {
    channel = await resolveChannel(ref);
  } catch (e) {
    return json({ error: String(e) }, 502);
  }
  if (!channel) return json({ error: `no YouTube channel found for ${ref.value}` }, 404);

  const live = await currentLive(channel.channelId);
  const now = new Date().toISOString();

  const row = {
    name: (body.name as string) ?? channel.title,
    city: (body.city as string) ?? "",
    rating: (body.rating as number) ?? 5.0,
    style: (body.style as string) ?? "Contemporary",
    distance_miles: (body.distance_miles as number) ?? 0,
    accent: (body.accent as string) ?? "blue",
    denomination: (body.denomination as string) ?? null,
    platform: "youtube",
    youtube_channel_id: channel.channelId,
    youtube_handle: channel.handle,
    thumbnail_url: channel.thumbnail,
    watch_url: `https://www.youtube.com/channel/${channel.channelId}/live`,
    is_live: live.videoId !== null,
    live_video_id: live.videoId,
    viewers: live.viewers,
    last_checked_at: now,
  };

  const { data, error } = await supabase
    .from("churches")
    .upsert(row, { onConflict: "youtube_channel_id" })
    .select()
    .single();
  if (error) return json({ error: error.message }, 500);

  // De-dup: remove any channel-less placeholder row(s) with the same name
  // (e.g. an earlier seed) so this church appears exactly once. Only touches
  // rows with no youtube_channel_id, never a real configured church. Their
  // live_services rows cascade-delete.
  await supabase.from("churches")
    .delete()
    .eq("name", data.name)
    .is("youtube_channel_id", null)
    .neq("id", data.id);

  // Ensure a live_services row exists — the Attend feed is live_services joined
  // to churches, so without one the church won't show up.
  const { data: svc } = await supabase
    .from("live_services").select("id").eq("church_id", data.id).limit(1);
  if (!svc || svc.length === 0) {
    await supabase.from("live_services").insert({
      church_id: data.id,
      title: "Live Service",
      is_live: live.videoId !== null,
      starts_in: null,
      service_time: null,
    });
  }

  return json({ church: data, resolved: channel, live_now: live.videoId !== null });
});
