// devotional_suggest — Tier 3 AI escape hatch (G19 §9). The deterministic
// engine is the default; this only fires on an explicit user tap. It does
// NOT free-generate: it embeds the user's context, retrieves a real,
// approved-tagged BSB verse via match_verses_text (semantic search), and asks
// the model to FRAME a short reflection grounded strictly in that verse —
// controlling both cost and theology risk. Per-user daily cap via
// public.increment_devotional_ai_usage. Deploy: ./supabase/deploy_devotional_suggest.sh

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const FRAMING_MODEL = Deno.env.get("DEVO_MODEL") ?? "gpt-4o-mini";
const DAILY_LIMIT = Number(Deno.env.get("DEVO_DAILY_LIMIT") ?? "5");
const EMBEDDING_MODEL = "text-embedding-3-small";
const EMBEDDING_DIMENSIONS = 1536;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const FRAMING_SYSTEM = `You write a very short devotional grounded STRICTLY in the
one Bible verse you are given. You may not introduce other verses, invent
quotations, or drift to a different topic. Stay faithful to the verse's actual
meaning in context. Warm, calm, pastoral, non-judgmental. Never claim to know
God's private will for the reader, never call events divine signs, never give
medical/mental-health directives. Present disputed readings as "many Christians
understand...". Return STRICT JSON only:
{"title": "<= 6 words", "body": "1-2 short paragraphs, <= 130 words", "prompt": "one short reflection question"}`;

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
    if (!jwt) return jsonError(401, "unauthorized");

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false },
    });

    const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !userData?.user) return jsonError(401, "unauthorized");
    if (userData.user.is_anonymous) return jsonError(403, "anonymous_not_allowed");

    const { data: allowed, error: rpcError } = await supabase.rpc(
      "increment_devotional_ai_usage", { p_limit: DAILY_LIMIT },
    );
    if (rpcError) return jsonError(500, "rate_limit_check_failed");
    if (!allowed) {
      return jsonError(429, "daily_limit_reached", {
        message: "You've reached today's AI-suggestion limit — the daily verse and devotional are always here.",
      });
    }

    const { context } = await req.json();
    const trimmed = typeof context === "string" ? context.trim() : "";
    if (!trimmed) return jsonError(400, "context required");

    // 1) Embed the user's context.
    const embedResp = await fetch("https://api.openai.com/v1/embeddings", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: EMBEDDING_MODEL, input: trimmed.slice(0, 2000), dimensions: EMBEDDING_DIMENSIONS,
      }),
    });
    if (!embedResp.ok) {
      const detail = await embedResp.text();
      return jsonError(502, "upstream_embedding", { detail: detail.slice(0, 300) });
    }
    const embedData = await embedResp.json();
    const embedding: number[] | undefined = embedData?.data?.[0]?.embedding;
    if (!Array.isArray(embedding) || embedding.length !== EMBEDDING_DIMENSIONS) {
      return jsonError(502, "bad_embedding");
    }

    // 2) Retrieve a real verse (semantic match over the tagged BSB corpus).
    const { data: rows, error: matchErr } = await supabase.rpc("match_verses_text", {
      p_embedding: `[${embedding.join(",")}]`, p_translation: "BSB", p_limit: 1,
    });
    if (matchErr) return jsonError(500, "match_failed", { detail: matchErr.message });
    const top = (rows ?? [])[0] as { book: string; chapter: number; verse: number; text: string } | undefined;
    if (!top) return jsonError(404, "no_match");

    const verseRef = `${top.book} ${top.chapter}:${top.verse}`;

    // 3) Frame a short reflection grounded strictly in that one verse.
    const chatResp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: FRAMING_MODEL,
        response_format: { type: "json_object" },
        max_completion_tokens: 500,
        messages: [
          { role: "system", content: FRAMING_SYSTEM },
          { role: "user", content: `The person shared: "${trimmed.slice(0, 600)}"\n\nGround your devotional in ONLY this verse:\n${verseRef} (BSB): "${top.text}"` },
        ],
      }),
    });
    if (!chatResp.ok) {
      const detail = await chatResp.text();
      return jsonError(502, "upstream_framing", { detail: detail.slice(0, 300) });
    }
    const chatData = await chatResp.json();
    let framed: { title?: string; body?: string; prompt?: string } = {};
    try { framed = JSON.parse(chatData.choices?.[0]?.message?.content ?? "{}"); } catch { framed = {}; }

    return new Response(JSON.stringify({
      verseRef,
      book: top.book, chapter: top.chapter, verse: top.verse, text: top.text,
      title: framed.title ?? "A verse for you",
      body: framed.body ?? "",
      prompt: framed.prompt ?? null,
    }), { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
