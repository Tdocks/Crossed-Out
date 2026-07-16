// Semantic ("search by meaning") Bible search. Embeds the caller's query
// with OpenAI and ranks verses via the match_verses_text RPC (migration
// 0014, wrapping migration 0012's match_verses). Mirrors kyra's auth
// pattern: requires a real (non-anonymous) authenticated Supabase user.
// Deploy: ./supabase/deploy_semantic_search.sh (see repo root)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const EMBEDDING_MODEL = "text-embedding-3-small";
const EMBEDDING_DIMENSIONS = 1536;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

Deno.serve(async (req) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const jsonError = (status: number, error: string, extra?: Record<string, unknown>) =>
    new Response(JSON.stringify({ error, ...extra }), {
      status, headers: { ...cors, "Content-Type": "application/json" },
    });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!jwt) {
      return jsonError(401, "unauthorized");
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false },
    });

    const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !userData?.user) {
      return jsonError(401, "unauthorized");
    }
    if (userData.user.is_anonymous) {
      return jsonError(403, "anonymous_not_allowed");
    }

    const { query, translation, limit } = await req.json();
    const trimmedQuery = typeof query === "string" ? query.trim() : "";
    if (!trimmedQuery) {
      return jsonError(400, "query required");
    }

    const embedResp = await fetch("https://api.openai.com/v1/embeddings", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: EMBEDDING_MODEL,
        input: trimmedQuery.slice(0, 2000),
        dimensions: EMBEDDING_DIMENSIONS,
      }),
    });

    if (!embedResp.ok) {
      const detail = await embedResp.text();
      return new Response(JSON.stringify({ error: "upstream_embedding", detail: detail.slice(0, 400) }), {
        status: 502, headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const embedData = await embedResp.json();
    const embedding: number[] | undefined = embedData?.data?.[0]?.embedding;
    if (!Array.isArray(embedding) || embedding.length !== EMBEDDING_DIMENSIONS) {
      return jsonError(502, "bad_embedding");
    }

    // pgvector literal string: "[v1,v2,...]"
    const pgvectorLiteral = `[${embedding.join(",")}]`;

    const { data: rows, error: rpcError } = await supabase.rpc("match_verses_text", {
      p_embedding: pgvectorLiteral,
      p_translation: translation || "BSB",
      p_limit: limit || 20,
    });

    if (rpcError) {
      return jsonError(500, "search_failed", { detail: rpcError.message });
    }

    const results = (rows ?? []).map((r: {
      book: string; chapter: number; verse: number; text: string; similarity: number;
    }) => ({
      book: r.book,
      chapter: r.chapter,
      verse: r.verse,
      text: r.text,
      similarity: r.similarity,
    }));

    return new Response(JSON.stringify({ results }), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
