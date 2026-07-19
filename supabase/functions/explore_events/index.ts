// explore_events — scheduled ingestion for the Explore "Events" vertical.
//
// Pulls upcoming Christian / religious events from the Ticketmaster Discovery
// API and upserts them into explore_items. Deep-links out to the event page
// (Ticketmaster universal link). Scheduled, national (US) pull ordered by
// date; per-region filtering can be layered on later.
//
// Auth: header  x-pipeline-secret: <PIPELINE_SECRET>  (deploy --no-verify-jwt).
// Secrets: TICKETMASTER_API_KEY, PIPELINE_SECRET. SUPABASE_URL /
// SERVICE_ROLE_KEY auto-injected. Optional: EXPLORE_EVENTS_COUNTRY (default US).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const TM_API_KEY = Deno.env.get("TICKETMASTER_API_KEY") ?? "";
const PIPELINE_SECRET = Deno.env.get("PIPELINE_SECRET") ?? "";
const COUNTRY = Deno.env.get("EXPLORE_EVENTS_COUNTRY") ?? "US";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

// Discovery API classification filters. classificationName does a fuzzy match
// across segment/genre/subgenre; we run a few targeted queries and dedupe by
// event id so we catch worship tours as well as "Religious"-classified events.
const QUERIES: Record<string, string>[] = [
  { classificationName: "Religious" },
  { keyword: "worship" },
  { keyword: "Christian music" },
];

type TMImage = { url: string; width: number; ratio?: string };

function bestImage(images: TMImage[] | undefined): string | null {
  if (!images || images.length === 0) return null;
  const wide = images.filter((i) => i.ratio === "16_9" && i.width >= 640);
  const pick = (wide.length ? wide : images).sort((a, b) => b.width - a.width)[0];
  return pick?.url ?? null;
}

async function runQuery(params: Record<string, string>): Promise<Record<string, unknown>[]> {
  const url = new URL("https://app.ticketmaster.com/discovery/v2/events.json");
  url.searchParams.set("apikey", TM_API_KEY);
  url.searchParams.set("countryCode", COUNTRY);
  url.searchParams.set("sort", "date,asc");
  url.searchParams.set("size", "40");
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
  const res = await fetch(url);
  if (!res.ok) {
    console.error(`ticketmaster query failed ${res.status}: ${await res.text()}`);
    return [];
  }
  const data = await res.json();
  return data._embedded?.events ?? [];
}

function toRow(ev: Record<string, any>): Record<string, unknown> | null {
  const id = ev.id as string;
  const name = ev.name as string;
  if (!id || !name || !ev.url) return null;
  const venue = ev._embedded?.venues?.[0];
  const city = venue?.city?.name;
  const state = venue?.state?.stateCode;
  const venueName = venue?.name;
  const where = [venueName, [city, state].filter(Boolean).join(", ")]
    .filter(Boolean).join(" · ");
  const start = ev.dates?.start ?? {};
  let publishedAt: string | null = null;
  if (start.dateTime) {
    publishedAt = start.dateTime;
  } else if (start.localDate) {
    const d = new Date(`${start.localDate}T00:00:00Z`);
    if (!isNaN(d.getTime())) publishedAt = d.toISOString();
  }
  return {
    vertical: "events",
    source: "ticketmaster",
    source_item_id: id,
    title: name,
    subtitle: where || null,
    thumbnail_url: bestImage(ev.images),
    open_url: ev.url,
    published_at: publishedAt,
    attribution: "Event data provided by Ticketmaster",
    is_active: true,
  };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  if (!PIPELINE_SECRET || req.headers.get("x-pipeline-secret") !== PIPELINE_SECRET) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401, headers: { "content-type": "application/json" },
    });
  }
  if (!TM_API_KEY) {
    return new Response(JSON.stringify({ error: "TICKETMASTER_API_KEY not set" }), {
      status: 500, headers: { "content-type": "application/json" },
    });
  }

  const byId = new Map<string, Record<string, unknown>>();
  for (const q of QUERIES) {
    const events = await runQuery(q);
    for (const ev of events) {
      const row = toRow(ev);
      if (row) byId.set(row.source_item_id as string, row);
    }
  }
  const rows = [...byId.values()];

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
    JSON.stringify({ events_found: rows.length, items_upserted: upserted, at: new Date().toISOString() }),
    { headers: { "content-type": "application/json" } },
  );
});
