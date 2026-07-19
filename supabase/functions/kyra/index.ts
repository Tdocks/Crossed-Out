// Kyra — Crossed Out's guide. Proxies OpenAI so the API key never ships in the app.
// Requires a real (non-anonymous) authenticated Supabase user and enforces a
// per-user daily usage cap via public.increment_kyra_usage (see migration 0008).
//
// Retrieval grounding: before answering, the latest user message is embedded
// and matched against the real Bible corpus (match_verses_text, migration
// 0014 — the same deterministic pgvector path semantic_search uses). Kyra may
// quote Scripture verbatim ONLY from those database-verified verses, which
// makes hallucinated verse text structurally impossible to pass off as a quote.
//
// Deploy: ./supabase/deploy_kyra.sh (see repo root)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const MODEL = Deno.env.get("KYRA_MODEL") ?? "gpt-5.6-luna";
const DAILY_LIMIT = Number(Deno.env.get("KYRA_DAILY_LIMIT") ?? "30");
const GROUND_LIMIT = Number(Deno.env.get("KYRA_GROUND_LIMIT") ?? "5");
const EMBEDDING_MODEL = "text-embedding-3-small";
const EMBEDDING_DIMENSIONS = 1536;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const SYSTEM_PROMPT = `You are Kyra, the gentle guide inside Crossed Out, a Christian
formation app. You are warm, calm, intelligent, nonjudgmental, and grounded.
You help people understand Scripture in the context of their real lives, write
prayers, and take small faithful next steps.

Hard rules you must never break:
- Never claim God told you something or that you know God's private will for the user.
- Never call an event a divine sign.
- Never roleplay as God, Jesus, or the Holy Spirit, and never speak in God's
  first-person voice. You are a guide, not a divine being.
- Never advise stopping professional medical or mental-health treatment.
- Never advise staying in an abusive situation; gently point to safety and help
  (in the U.S.: the National Domestic Violence Hotline, 1-800-799-7233, and 911
  in an emergency).
- If the user expresses suicidal thoughts, self-harm, or intent to hurt
  themselves: take it seriously, respond with warmth and without judgment, and
  encourage them right away to contact the 988 Suicide & Crisis Lifeline (call
  or text 988 in the U.S.), local emergency services, or a trusted person.
  Never minimize it, never keep it a secret, and never offer spiritual practice
  as a substitute for immediate real-world help.
- Present disputed interpretations as "many Christians understand..." or
  "Christian traditions differ on this."
- You are not a replacement for a pastor, counselor, physician, or emergency
  services, and you say so when it matters.
- Keep responses concise (2-4 short paragraphs), pastoral, and practical.

Scripture integrity (non-negotiable):
- A "Retrieved Scripture" list of real, database-verified BSB verses may be
  provided for this conversation. When you quote Scripture verbatim, quote
  ONLY from that list — word for word, with its reference.
- If no retrieved verse fits, you may point the user to a passage by reference
  and summarize its meaning in your own words, clearly as a summary — but
  never present invented or approximate wording as Bible text.
- Never invent, alter, or loosely "quote" Scripture. It is better to cite a
  reference without quoting than to misquote God's word.`;

// Embeds the user's latest message and retrieves real verses from the Bible
// corpus. Deterministic pgvector match over verified text. Returns a
// formatted block, or null on any failure — grounding is best-effort and
// must never block the conversation.
async function retrieveGrounding(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  query: string,
): Promise<string | null> {
  try {
    const trimmed = query.trim().slice(0, 2000);
    if (!trimmed) return null;

    const embedResp = await fetch("https://api.openai.com/v1/embeddings", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: EMBEDDING_MODEL,
        input: trimmed,
        dimensions: EMBEDDING_DIMENSIONS,
      }),
    });
    if (!embedResp.ok) return null;

    const embedData = await embedResp.json();
    const embedding: number[] | undefined = embedData?.data?.[0]?.embedding;
    if (!Array.isArray(embedding) || embedding.length !== EMBEDDING_DIMENSIONS) return null;

    const { data: rows, error } = await supabase.rpc("match_verses_text", {
      p_embedding: `[${embedding.join(",")}]`,
      p_translation: "BSB",
      p_limit: GROUND_LIMIT,
    });
    if (error || !Array.isArray(rows) || rows.length === 0) return null;

    return rows
      .map((r: { book: string; chapter: number; verse: number; text: string }) =>
        `${r.book} ${r.chapter}:${r.verse} (BSB) — "${String(r.text).trim()}"`)
      .join("\n");
  } catch {
    return null;
  }
}

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

    const { data: allowed, error: rpcError } = await supabase.rpc(
      "increment_kyra_usage",
      { p_limit: DAILY_LIMIT },
    );
    if (rpcError) {
      return jsonError(500, "rate_limit_check_failed");
    }
    if (!allowed) {
      return jsonError(429, "daily_limit_reached", {
        message: "You've reached today's Kyra limit — come back tomorrow.",
      });
    }

    const { messages, firstName, stream } = await req.json();
    if (!Array.isArray(messages) || messages.length === 0) {
      return jsonError(400, "messages required");
    }

    const trimmed = messages.slice(-12).map((m: { role: string; text: string }) => ({
      role: m.role === "kyra" ? "assistant" : "user",
      content: String(m.text).slice(0, 2000),
    }));

    // Ground on the latest user message (deterministic retrieval; one cheap
    // embedding call). Best-effort: a grounding failure never blocks Kyra —
    // the fallback system message then forbids verbatim quoting entirely.
    const lastUserContent =
      [...trimmed].reverse().find((m) => m.role === "user")?.content ?? "";
    const grounding = await retrieveGrounding(supabase, lastUserContent);

    const systemMessages = [
      {
        role: "system",
        content: SYSTEM_PROMPT +
          (firstName
            ? `\n\nAbout the user's name: their first name is ${firstName}. Use it
sparingly and naturally — only when it genuinely adds warmth, such as an
opening greeting in a new conversation or a genuinely weighty moment. Your
default is to NOT use it. Never use it as a habitual prefix or sign-off,
never in most replies, and never begin consecutive replies with it —
overusing someone's name reads as scripted, not warm.`
            : ""),
      },
      grounding
        ? {
          role: "system",
          content:
            "Retrieved Scripture — real, database-verified verses matched to this conversation. Quote verbatim ONLY from these:\n" +
            grounding,
        }
        : {
          role: "system",
          content:
            "No retrieved Scripture is available for this turn. Do not quote any verse verbatim; refer to passages by reference and summarize in your own words instead.",
        },
    ];

    // All gating (401/403/429) and grounding retrieval happen BEFORE this
    // point — a streaming caller still gets the daily-limit 429 as a plain
    // JSON status response, never mid-stream.
    const wantsStream = stream === true;

    const r = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_completion_tokens: 600,
        stream: wantsStream,
        messages: [...systemMessages, ...trimmed],
      }),
    });

    if (!r.ok) {
      const detail = await r.text();
      return new Response(JSON.stringify({ error: "upstream", detail: detail.slice(0, 400) }), {
        status: 502, headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    if (wantsStream && r.body) {
      // Re-emit OpenAI's SSE as a minimal stream the app can parse without
      // knowing OpenAI's chunk shape: `data: {"delta":"..."}` per token,
      // then `data: [DONE]`.
      const upstream = r.body;
      const sse = new ReadableStream<Uint8Array>({
        async start(controller) {
          const reader = upstream.getReader();
          const decoder = new TextDecoder();
          const encoder = new TextEncoder();
          let buffer = "";
          let finished = false;
          const emitDone = () => {
            if (!finished) {
              finished = true;
              controller.enqueue(encoder.encode("data: [DONE]\n\n"));
            }
          };
          try {
            while (true) {
              const { done, value } = await reader.read();
              if (done) break;
              buffer += decoder.decode(value, { stream: true });
              const lines = buffer.split("\n");
              buffer = lines.pop() ?? "";
              for (const rawLine of lines) {
                const line = rawLine.trim();
                if (!line.startsWith("data:")) continue;
                const payload = line.slice(5).trim();
                if (payload === "[DONE]") {
                  emitDone();
                  continue;
                }
                try {
                  const chunk = JSON.parse(payload);
                  const delta = chunk.choices?.[0]?.delta?.content;
                  if (typeof delta === "string" && delta.length > 0) {
                    controller.enqueue(
                      encoder.encode(`data: ${JSON.stringify({ delta })}\n\n`),
                    );
                  }
                } catch {
                  // Ignore unparseable keep-alive/partial chunks.
                }
              }
            }
            emitDone();
            controller.close();
          } catch (e) {
            controller.error(e);
          }
        },
      });
      return new Response(sse, {
        headers: {
          ...cors,
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
        },
      });
    }

    const data = await r.json();
    const text = data.choices?.[0]?.message?.content ?? "";
    return new Response(JSON.stringify({ text }), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
