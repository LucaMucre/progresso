// @ts-nocheck
// Deno Edge Function: Ingest user data into user_documents (RAG index)
// - Reads action_logs for the authenticated user
// - Extracts plaintext from notes (Quill delta aware)
// - Chunks long texts, generates embeddings via OpenAI
// - Upserts chunks into user_documents with metadata

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const OPENAI_BASE_URL = Deno.env.get("OPENAI_BASE_URL") ?? "https://api.openai.com/v1";
const OPENAI_EMBED_MODEL = Deno.env.get("OPENAI_EMBED_MODEL") ?? "text-embedding-3-small";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

// Basic CORS headers for browser calls
const corsHeaders: HeadersInit = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function quillToPlaintext(notes?: string | null, occurredAtIso?: string | null): string {
  if (!notes) return "";
  try {
    const obj = JSON.parse(notes);
    let metaTitle = "";
    let metaArea = "";
    let metaCategory = "";
    // Optional metadata wrapper we store in notes
    if (typeof obj === "object" && obj && !Array.isArray(obj)) {
      const maybeTitle = (obj as any).title ?? (obj as any).name;
      const maybeArea = (obj as any).area;
      const maybeCategory = (obj as any).category;
      metaTitle = typeof maybeTitle === "string" ? maybeTitle : "";
      metaArea = typeof maybeArea === "string" ? maybeArea : "";
      metaCategory = typeof maybeCategory === "string" ? maybeCategory : "";
    }

    const header: string[] = [];
    if (metaTitle) header.push(`Titel: ${metaTitle}`);
    if (metaArea || metaCategory) header.push(`Bereich: ${metaArea}${metaCategory ? `/${metaCategory}` : ""}`);
    if (occurredAtIso) header.push(`Datum: ${occurredAtIso}`);

    // Legacy array of ops
    if (Array.isArray(obj)) {
      const body = (obj as unknown[])
        .map((op: any) => (typeof op?.insert === "string" ? op.insert : ""))
        .join("");
      return [...header, body].filter(Boolean).join("\n");
    }
    // Wrapped: { delta: [...] }
    if (typeof obj === "object" && obj && "delta" in obj) {
      const ops = (obj as any).delta as unknown[];
      const body = ops
        .map((op: any) => (typeof op?.insert === "string" ? op.insert : ""))
        .join("");
      return [...header, body].filter(Boolean).join("\n");
    }
  } catch (_) {
    // plain text fallback
  }
  // Fallback: prepend date line if available
  return [occurredAtIso ? `Datum: ${occurredAtIso}` : "", notes].filter(Boolean).join("\n");
}

function chunkText(text: string, maxLen = 2000, overlap = 200): string[] {
  const chunks: string[] = [];
  if (!text || text.trim().length === 0) return chunks;
  let i = 0;
  while (i < text.length) {
    const end = Math.min(i + maxLen, text.length);
    chunks.push(text.slice(i, end));
    if (end === text.length) break;
    i = Math.max(0, end - overlap);
  }
  return chunks;
}

async function embedBatch(inputs: string[]): Promise<number[][]> {
  const res = await fetch(`${OPENAI_BASE_URL}/embeddings`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ model: OPENAI_EMBED_MODEL, input: inputs }),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`OpenAI embed error: ${res.status} ${t}`);
  }
  const data = await res.json();
  return (data.data as any[]).map((d) => d.embedding as number[]);
}

serve(async (req) => {
  // Preflight support
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });

    const userRes = await supabase.auth.getUser();
    const userId = userRes.data.user?.id;
    if (!userId) return new Response("Unauthorized", { status: 401 });

    const payload = await req.json().catch(() => ({}));
    const since: string | null = payload?.since ?? null;

    const from = supabase
      .from("action_logs")
      .select("id, occurred_at, notes, template_id")
      .order("occurred_at", { ascending: false });

    const { data: logs, error } = since ? await from.gte("occurred_at", since) : await from;
    if (error) throw error;

    let totalChunks = 0;

    // Feature-Flag: Externe Embeddings deaktivieren (Privacy-by-default)
    const ENABLE_EXTERNAL_EMBEDDINGS = Deno.env.get('ENABLE_EXTERNAL_EMBEDDINGS') === 'true';

    for (const log of logs ?? []) {
      const text = quillToPlaintext(log.notes ?? "", log.occurred_at ?? null);
      const chunks = chunkText(text);
      if (chunks.length === 0) continue;
      if (!ENABLE_EXTERNAL_EMBEDDINGS) {
        // Überspringe Embedding‑Generierung: lege nur Platzhalter an, damit Funktion konsistent antwortet
        continue;
      }
      const embeddings = await embedBatch(chunks);
      for (let i = 0; i < chunks.length; i++) {
        const content = chunks[i];
        const embedding = embeddings[i];

        const up = await supabase.from("user_documents").upsert(
          {
            user_id: userId,
            source_table: "action_logs",
            source_id: `${log.id}#${i}`,
            title: "Log",
            content,
            metadata: { template_id: log.template_id },
            occurred_at: log.occurred_at,
            embedding,
          },
          { onConflict: "user_id,source_table,source_id" },
        );
        if (up.error) throw up.error;
        totalChunks++;
      }
    }

    return new Response(
      JSON.stringify({ logs: logs?.length ?? 0, chunks: totalChunks }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});

