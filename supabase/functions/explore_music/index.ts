// explore_music — scheduled ingestion for the Explore "Music" vertical.
//
// Mints an Apple Music developer token (JWT, ES256) SERVER-SIDE from your
// MusicKit private key, then pulls the Christian & Gospel genre (id 22)
// charts (albums + playlists) and upserts them into explore_items. Tapping an
// item opens it in Apple Music via its universal link. The private key never
// leaves the edge function.
//
// Auth: header  x-pipeline-secret: <PIPELINE_SECRET>  (deploy --no-verify-jwt).
// Secrets:
//   APPLE_MUSIC_PRIVATE_KEY  — full contents of the MusicKit .p8 (PEM).
//   APPLE_MUSIC_KEY_ID       — the 10-char Key ID for that key.
//   APPLE_MUSIC_TEAM_ID      — your 10-char Apple Developer Team ID.
//   PIPELINE_SECRET
// SUPABASE_URL / SERVICE_ROLE_KEY auto-injected.
// Optional: EXPLORE_MUSIC_STOREFRONT (default "us").

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const PRIVATE_KEY = Deno.env.get("APPLE_MUSIC_PRIVATE_KEY") ?? "";
const KEY_ID = Deno.env.get("APPLE_MUSIC_KEY_ID") ?? "";
const TEAM_ID = Deno.env.get("APPLE_MUSIC_TEAM_ID") ?? "";
const PIPELINE_SECRET = Deno.env.get("PIPELINE_SECRET") ?? "";
const STOREFRONT = Deno.env.get("EXPLORE_MUSIC_STOREFRONT") ?? "us";
const CHRISTIAN_GENRE = "22"; // Apple Music "Christian & Gospel"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

// MARK: - JWT (ES256) minting via Web Crypto

function b64url(bytes: Uint8Array): string {
  let s = btoa(String.fromCharCode(...bytes));
  return s.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function b64urlStr(str: string): string {
  return b64url(new TextEncoder().encode(str));
}

function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const bin = atob(body);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}

async function developerToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: KEY_ID };
  const payload = { iss: TEAM_ID, iat: now, exp: now + 60 * 60 }; // 1h
  const signingInput = `${b64urlStr(JSON.stringify(header))}.${b64urlStr(JSON.stringify(payload))}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(PRIVATE_KEY),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  // Web Crypto returns the raw IEEE-P1363 (r||s) signature JWS ES256 expects.
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${b64url(new Uint8Array(sig))}`;
}

// MARK: - Apple Music catalog

function artwork(url: string | undefined, size = 300): string | null {
  if (!url) return null;
  return url.replace("{w}", String(size)).replace("{h}", String(size))
            .replace("{f}", "jpg");
}

type Row = Record<string, unknown>;

function rowFromResource(res: any, kind: "album" | "playlist"): Row | null {
  const a = res?.attributes;
  if (!a?.name || !a?.url) return null;
  return {
    vertical: "music",
    source: "apple_music",
    source_item_id: `${kind}:${res.id}`,
    title: a.name,
    subtitle: a.artistName ?? a.curatorName ?? "Apple Music",
    thumbnail_url: artwork(a.artwork?.url),
    open_url: a.url,
    published_at: null,
    attribution: "Apple Music",
    is_active: true,
  };
}

async function fetchCharts(token: string): Promise<Row[]> {
  const url = new URL(`https://api.music.apple.com/v1/catalog/${STOREFRONT}/charts`);
  url.searchParams.set("types", "albums,playlists");
  url.searchParams.set("genre", CHRISTIAN_GENRE);
  url.searchParams.set("limit", "25");
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) throw new Error(`charts failed ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const rows: Row[] = [];
  for (const group of data.results?.albums ?? []) {
    for (const item of group.data ?? []) { const r = rowFromResource(item, "album"); if (r) rows.push(r); }
  }
  for (const group of data.results?.playlists ?? []) {
    for (const item of group.data ?? []) { const r = rowFromResource(item, "playlist"); if (r) rows.push(r); }
  }
  return rows;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  if (!PIPELINE_SECRET || req.headers.get("x-pipeline-secret") !== PIPELINE_SECRET) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401, headers: { "content-type": "application/json" },
    });
  }
  if (!PRIVATE_KEY || !KEY_ID || !TEAM_ID) {
    return new Response(
      JSON.stringify({ error: "APPLE_MUSIC_PRIVATE_KEY / KEY_ID / TEAM_ID not all set" }),
      { status: 500, headers: { "content-type": "application/json" } },
    );
  }

  let token: string;
  try {
    token = await developerToken();
  } catch (e) {
    return new Response(JSON.stringify({ error: `token mint failed: ${e}` }), {
      status: 500, headers: { "content-type": "application/json" },
    });
  }

  let rows: Row[];
  try {
    rows = await fetchCharts(token);
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 502, headers: { "content-type": "application/json" },
    });
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
    JSON.stringify({ items_found: rows.length, items_upserted: upserted, at: new Date().toISOString() }),
    { headers: { "content-type": "application/json" } },
  );
});
