// Deno Edge Function: Chat (RAG)
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const OPENAI_BASE_URL = Deno.env.get("OPENAI_BASE_URL") ?? "https://api.openai.com/v1";
const OPENAI_EMBED_MODEL = Deno.env.get("OPENAI_EMBED_MODEL") ?? "text-embedding-3-small";
const OPENAI_CHAT_MODEL = Deno.env.get("OPENAI_CHAT_MODEL") ?? "gpt-4o-mini";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

async function embedQuery(q: string): Promise<number[]> {
  const res = await fetch(`${OPENAI_BASE_URL}/embeddings`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ model: OPENAI_EMBED_MODEL, input: q }),
  });
  if (!res.ok) throw new Error(await res.text());
  const data = await res.json();
  return data.data[0].embedding as number[];
}

serve(async (req) => {
  try {
    const { query, top_k = 8, min_similarity = 0.0 } = await req.json();
    if (!query || typeof query !== "string") {
      return new Response(JSON.stringify({ error: "query required" }), { status: 400 });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: user } = await supabase.auth.getUser();
    const userId = user.user?.id;
    if (!userId) return new Response("Unauthorized", { status: 401 });

    const qEmb = await embedQuery(query);
    const { data: matches, error } = await supabase.rpc("match_user_documents", {
      query_embedding: qEmb as unknown as any,
      match_count: top_k,
      min_similarity,
      uid: userId,
    });
    if (error) throw error;

    const context = (matches ?? []).map((m: any, i: number) => `# Doc ${i + 1}\n${m.content}`).join("\n\n");

    const prompt = `Beantworte präzise auf Basis des Kontextes. Wenn keine Info vorhanden ist, sage: \"Keine Daten vorhanden.\"\n\nKontext:\n${context}\n\nFrage: ${query}`;

    const resp = await fetch(`${OPENAI_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: OPENAI_CHAT_MODEL,
        messages: [
          { role: "system", content: "Du beantwortest Fragen zu den Daten des Nutzers." },
          { role: "user", content: prompt },
        ],
        temperature: 0.2,
      }),
    });
    if (!resp.ok) throw new Error(await resp.text());
    const data = await resp.json();
    const answer = data.choices?.[0]?.message?.content ?? "";

    return new Response(JSON.stringify({
      answer,
      sources: (matches ?? []).map((m: any) => ({ id: m.id, title: m.title, occurred_at: m.occurred_at })),
    }), { headers: { "Content-Type": "application/json" }, status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});

