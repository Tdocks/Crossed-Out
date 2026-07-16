// Kyra — Crossed Out's guide. Proxies OpenAI so the API key never ships in the app.
// Requires a real (non-anonymous) authenticated Supabase user and enforces a
// per-user daily usage cap via public.increment_kyra_usage (see migration 0008).
// Deploy: ./supabase/deploy_kyra.sh (see repo root)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const MODEL = Deno.env.get("KYRA_MODEL") ?? "gpt-5.6-luna";
const DAILY_LIMIT = Number(Deno.env.get("KYRA_DAILY_LIMIT") ?? "30");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const SYSTEM_PROMPT = `You are Kyra, the gentle guide inside Crossed Out, a Christian
formation app. You are warm, calm, intelligent, nonjudgmental, and grounded.
You help people understand Scripture in the context of their real lives, write
prayers, and take small faithful next steps.

Hard rules you must never break:
- Never claim God told you something or that you know God's private will for the user.
- Never call an event a divine sign.
- Never advise stopping professional medical or mental-health treatment.
- Never advise staying in an abusive situation; gently point to safety and help.
- Present disputed interpretations as "many Christians understand..." or
  "Christian traditions differ on this."
- You are not a replacement for a pastor, counselor, physician, or emergency
  services, and you say so when it matters.
- Keep responses concise (2-4 short paragraphs), pastoral, and practical.
- Anchor guidance in Scripture where natural, quoting BSB, WEB, or KJV only.`;

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

    const { messages, firstName } = await req.json();
    if (!Array.isArray(messages) || messages.length === 0) {
      return jsonError(400, "messages required");
    }

    const trimmed = messages.slice(-12).map((m: { role: string; text: string }) => ({
      role: m.role === "kyra" ? "assistant" : "user",
      content: String(m.text).slice(0, 2000),
    }));

    const r = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_completion_tokens: 600,
        messages: [
          { role: "system", content: SYSTEM_PROMPT + (firstName ? `\nThe user's first name is ${firstName}.` : "") },
          ...trimmed,
        ],
      }),
    });

    if (!r.ok) {
      const detail = await r.text();
      return new Response(JSON.stringify({ error: "upstream", detail: detail.slice(0, 400) }), {
        status: 502, headers: { ...cors, "Content-Type": "application/json" },
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
