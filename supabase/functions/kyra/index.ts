// Kyra — Crossed Out's guide. Proxies OpenAI so the API key never ships in the app.
// Deploy: ./supabase/deploy_kyra.sh (see repo root)

const MODEL = Deno.env.get("KYRA_MODEL") ?? "gpt-5.6-luna";

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

  try {
    const { messages, firstName } = await req.json();
    if (!Array.isArray(messages) || messages.length === 0) {
      return new Response(JSON.stringify({ error: "messages required" }), {
        status: 400, headers: { ...cors, "Content-Type": "application/json" },
      });
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
