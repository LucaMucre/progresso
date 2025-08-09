// Deno Edge Function: Chat (RAG)
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const OPENAI_BASE_URL = Deno.env.get("OPENAI_BASE_URL") ?? "https://api.openai.com/v1";
const OPENAI_EMBED_MODEL = Deno.env.get("OPENAI_EMBED_MODEL") ?? "text-embedding-3-small";
const OPENAI_CHAT_MODEL = Deno.env.get("OPENAI_CHAT_MODEL") ?? "gpt-4o-mini";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

// Basic CORS headers for browser calls
const corsHeaders: HeadersInit = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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

// Minimal plaintext extractor to reuse notes content if needed
function quillToPlaintext(notes?: string | null): string {
  if (!notes) return "";
  try {
    const obj = JSON.parse(notes);
    if (Array.isArray(obj)) {
      return (obj as unknown[])
        .map((op: any) => (typeof op?.insert === "string" ? op.insert : ""))
        .join("");
    }
    if (typeof obj === "object" && obj && "delta" in obj) {
      const ops = (obj as any).delta as unknown[];
      return ops.map((op: any) => (typeof op?.insert === "string" ? op.insert : "")).join("");
    }
  } catch (_) {}
  return notes;
}

serve(async (req) => {
  // Preflight support
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const { query, top_k = 8, min_similarity = 0.0 } = await req.json();
    if (!query || typeof query !== "string") {
      return new Response(JSON.stringify({ error: "query required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: user } = await supabase.auth.getUser();
    const userId = user.user?.id;
    if (!userId)
      return new Response("Unauthorized", {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });

    const qEmb = await embedQuery(query);
    // Very light time-window parsing (German): "letzten X tag(e)" → filter client-side after match
    const lowerQ = query.toLowerCase();
    let sinceIso: string | null = null;
    const m = lowerQ.match(/letzten\s+(\d+)\s*tag/);
    if (m) {
      const days = Math.max(1, parseInt(m[1], 10));
      const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
      sinceIso = since.toISOString();
    }

    const { data: matches, error } = await supabase.rpc("match_user_documents", {
      query_embedding: qEmb as unknown as any,
      match_count: Math.max(12, top_k),
      min_similarity: Math.max(0.2, min_similarity),
      uid: userId,
    });
    if (error) throw error;

    // Similarity guard: require decent similarity, else treat as smalltalk
    const SIM_THRESHOLD = 0.2;
    const bySim = (matches ?? []).filter((d: any) => (typeof d?.similarity === "number" ? d.similarity : 0) >= SIM_THRESHOLD);

    // Optional time filter client-side using occurred_at
    const filtered = bySim.filter((d: any) => {
      if (!sinceIso) return true;
      if (!d?.occurred_at) return false;
      try { return new Date(d.occurred_at).toISOString() >= sinceIso; } catch { return false; }
    });

    let docsForContext: any[] = [...filtered];
    let context = docsForContext
      .map((m: any, i: number) => `# Doc ${i + 1}\n${m.content}`)
      .join("\n\n");

    const hadContext = filtered.length > 0 && context.trim().length > 0;
    // Detect obvious data questions; otherwise treat as smalltalk
    const lowerQ2 = query.toLowerCase();
    const DATA_KEYWORDS = [
      "aktiv", "log", "tage", "woche", "monat", "xp", "streak", "zuletzt",
      "datum", "anzahl", "wie viele", "liste", "zusammenfass", "fasse",
      "durchschnitt", "summe", "statistik", "notiz", "buch", "titel",
      "heute", "gestern"
    ];
    const isDataQuestion = DATA_KEYWORDS.some((k) => lowerQ2.includes(k));
    const isCountQuestion = /wie\s*viele|anzahl|wieviel/.test(lowerQ2);
    let useDataMode = isDataQuestion && hadContext;

    // Fallback: if Daten-Frage aber kein Kontext → hole letzte N Tage direkt aus action_logs
    if (isDataQuestion && !hadContext) {
      const days = m ? Math.max(1, parseInt(m[1], 10)) : 7;
      const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
      const { data: rawLogs, error: logsErr } = await supabase
        .from("action_logs")
        .select("id, occurred_at, notes, template_id")
        .gte("occurred_at", since)
        .order("occurred_at", { ascending: false });
      if (!logsErr && (rawLogs?.length ?? 0) > 0) {
        const fallbackDocs = (rawLogs ?? []).slice(0, 20).map((r: any, i: number) => ({
          id: r.id,
          title: "Log",
          occurred_at: r.occurred_at,
          content: quillToPlaintext(r.notes ?? ""),
        }));
        docsForContext = fallbackDocs;
        context = fallbackDocs
          .map((m: any, i: number) => `# Log ${i + 1} (${m.occurred_at})\n${m.content}`)
          .join("\n\n");
        useDataMode = true; // Wir haben jetzt Kontext aus den Roh-Logs
      }
    }

    // If it's a counting question, answer deterministisch via SQL count
    if (isCountQuestion) {
      const days = m ? Math.max(1, parseInt(m[1], 10)) : 7;
      const since = (sinceIso ?? new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString());
      const { count, error: cErr } = await supabase
        .from("action_logs")
        .select("id", { head: true, count: "exact" })
        .gte("occurred_at", since);
      if (!cErr) {
        const n = count ?? 0;
        return new Response(
          JSON.stringify({
            answer: `Du hast in den letzten ${days} Tagen ${n} Aktivität${n === 1 ? '' : 'en'} erfasst.`,
            sources: [],
          }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
        );
      }
    }

    const dataPrompt = `Beantworte präzise auf Basis des Kontextes. Wenn keine Info vorhanden ist, sage: \"Keine Daten vorhanden.\"\n\nKontext:\n${context}\n\nFrage: ${query}`;
    const smalltalkPrompt = query; // direkte Nutzerfrage ohne Kontext

    const resp = await fetch(`${OPENAI_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: OPENAI_CHAT_MODEL,
        messages: useDataMode
          ? [
              { role: "system", content: "Du bist ein strukturierter Assistent für persönliche Aktivitätsdaten. Antworte kurz, präzise, auf Deutsch, mit klaren Aufzählungen. Wenn die Datenlage unsicher ist, sag es explizit. Zähle wenn möglich konkrete Werte (Anzahl, Summen)." },
              { role: "user", content: dataPrompt },
            ]
          : [
              { role: "system", content: "Du bist ein freundlicher Assistent innerhalb einer Produktivitäts-App. Antworte kurz und hilfreich auf Deutsch. Wenn der Nutzer nach seinen Daten fragt, erkläre kurz, dass du auf seine Einträge zugreifen kannst (z. B. \"Fasse meine letzten 7 Tage\")." },
              { role: "user", content: smalltalkPrompt },
            ],
        temperature: useDataMode ? 0.1 : 0.6,
      }),
    });
    if (!resp.ok) throw new Error(await resp.text());
    const data = await resp.json();
    const answer = data.choices?.[0]?.message?.content ?? "";

    return new Response(
      JSON.stringify({
        answer,
        sources: useDataMode ? (docsForContext ?? []).map((m: any) => ({
          id: m.id,
          title: m.title,
          occurred_at: m.occurred_at,
        })) : [],
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});

