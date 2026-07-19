// explore_devotionals — scheduled ingestion for the Explore "Devotionals"
// vertical. Pulls public RSS feeds, stores TITLE + a SHORT capped EXCERPT
// (never full text) + a link OUT to the publisher, and upserts into
// explore_items. Excerpt is capped hard at EXCERPT_WORD_CAP words — well
// under any fair-use line and a courtesy to the ministries whose work this is.
//
// Auth: header  x-pipeline-secret: <PIPELINE_SECRET>  (deploy --no-verify-jwt).
// Secrets: PIPELINE_SECRET. SUPABASE_URL / SERVICE_ROLE_KEY auto-injected.
//
// FEEDS: add a ministry here only once we're comfortable excerpting it. If a
// publisher replies to our clearance email with terms (exact length, required
// credit), encode them per-feed below and every item will honor them.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const PIPELINE_SECRET = Deno.env.get("PIPELINE_SECRET") ?? "";
const EXCERPT_WORD_CAP = 55;
const PER_FEED = 15;

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

type Feed = { source: string; name: string; url: string; attribution: string };

const FEEDS: Feed[] = [
  {
    source: "desiring_god",
    name: "Desiring God · Solid Joys",
    url: "https://feed.desiringgod.org/solid-joys.rss",
    attribution: "Solid Joys © Desiring God (desiringgod.org)",
  },
  // Ligonier: add once the RSS URL + excerpt permission are confirmed from
  // their reply to our clearance email. Kept out until then rather than
  // guessing a feed URL.
  // { source: "ligonier", name: "Ligonier Ministries", url: "<confirm>",
  //   attribution: "© Ligonier Ministries (ligonier.org)" },
];

const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36";

type ParsedItem = {
  guid: string;
  title: string;
  link: string;
  excerpt: string;
  pubDate: string | null;
  image: string | null;
};

function decodeEntities(s: string): string {
  return s
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&nbsp;/g, " ")
    .replace(/&#8217;/g, "’").replace(/&#8216;/g, "‘")
    .replace(/&#8220;/g, "“").replace(/&#8221;/g, "”")
    .replace(/&#8212;/g, "—").replace(/&#8230;/g, "…");
}

function stripTags(html: string): string {
  return decodeEntities(html.replace(/<[^>]+>/g, " ")).replace(/\s+/g, " ").trim();
}

function capWords(text: string, cap: number): string {
  const words = text.split(/\s+/).filter(Boolean);
  if (words.length <= cap) return words.join(" ");
  return words.slice(0, cap).join(" ") + "…";
}

function tag(block: string, name: string): string | null {
  const m = block.match(new RegExp(`<${name}[^>]*>([\\s\\S]*?)</${name}>`, "i"));
  return m ? m[1].trim() : null;
}

function firstImage(block: string): string | null {
  const enc = block.match(/<enclosure[^>]*url="([^"]+)"[^>]*type="image/i);
  if (enc) return enc[1];
  const media = block.match(/<media:(?:content|thumbnail)[^>]*url="([^"]+)"/i);
  if (media) return media[1];
  const desc = tag(block, "description") ?? "";
  const img = decodeEntities(desc).match(/<img[^>]*src="([^"]+)"/i);
  return img ? img[1] : null;
}

function parseFeed(xml: string): ParsedItem[] {
  const items: ParsedItem[] = [];
  const blocks = xml.match(/<item[\s\S]*?<\/item>/gi) ?? [];
  for (const block of blocks) {
    const title = stripTags(tag(block, "title") ?? "");
    const link = decodeEntities(tag(block, "link") ?? "").trim();
    if (!title || !link) continue;
    const rawBody = tag(block, "content:encoded") ?? tag(block, "description") ?? "";
    const excerpt = capWords(stripTags(rawBody), EXCERPT_WORD_CAP);
    const guid = stripTags(tag(block, "guid") ?? "") || link;
    const pubRaw = tag(block, "pubDate") ?? tag(block, "dc:date");
    let pubDate: string | null = null;
    if (pubRaw) { const d = new Date(pubRaw.trim()); if (!isNaN(d.getTime())) pubDate = d.toISOString(); }
    items.push({ guid, title, link, excerpt, pubDate, image: firstImage(block) });
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

  const rows: Record<string, unknown>[] = [];
  const perFeed: Record<string, number> = {};
  for (const feed of FEEDS) {
    try {
      const res = await fetch(feed.url, { headers: { "user-agent": UA } });
      if (!res.ok) { console.error(`feed ${feed.source} ${res.status}`); perFeed[feed.source] = -1; continue; }
      const xml = await res.text();
      const items = parseFeed(xml).slice(0, PER_FEED);
      perFeed[feed.source] = items.length;
      for (const it of items) {
        rows.push({
          vertical: "devotionals",
          source: feed.source,
          source_item_id: it.guid,
          title: it.title,
          subtitle: feed.name,
          excerpt: it.excerpt,
          thumbnail_url: it.image,
          open_url: it.link,
          attribution: feed.attribution,
          published_at: it.pubDate,
          is_active: true,
        });
      }
    } catch (e) {
      console.error(`feed ${feed.source} threw: ${e}`);
      perFeed[feed.source] = -1;
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
    JSON.stringify({ feeds: perFeed, items_upserted: upserted, at: new Date().toISOString() }),
    { headers: { "content-type": "application/json" } },
  );
});
