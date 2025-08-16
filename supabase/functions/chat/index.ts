// @ts-nocheck
// Deno Edge Function: Chat (RAG)
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const OPENAI_BASE_URL = Deno.env.get("OPENAI_BASE_URL") ?? "https://api.openai.com/v1";
const OPENAI_EMBED_MODEL = Deno.env.get("OPENAI_EMBED_MODEL") ?? "text-embedding-3-small";
const OPENAI_CHAT_MODEL = Deno.env.get("OPENAI_CHAT_MODEL") ?? "gpt-4o-mini";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

// CORS: restrict by env ALLOWED_ORIGINS (comma-separated). Fallback to '*'
const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") ?? "*")
  .split(",")
  .map((s) => s.trim())
  .filter((s) => s.length > 0);

function isOriginAllowed(origin: string | null): boolean {
  if (!origin) return false;
  if (ALLOWED_ORIGINS.includes("*")) return true;
  try {
    const o = new URL(origin);
    return ALLOWED_ORIGINS.some((p) => {
      try {
        const u = new URL(p);
        return u.origin === o.origin;
      } catch {
        // allow bare host matches
        return p === origin || p === o.origin;
      }
    });
  } catch {
    return false;
  }
}

function makeCorsHeaders(origin: string | null): HeadersInit {
  const allowed = isOriginAllowed(origin);
  return {
    "Access-Control-Allow-Origin": allowed ? (origin ?? "") : "",
    "Vary": "Origin",
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  } as const;
}

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

  function extractMeta(notes?: string | null): { title: string; area: string; category: string; plaintext: string } {
    let title = "";
    let area = "";
    let category = "";
    let plaintext = "";
    try {
      if (!notes) return { title, area, category, plaintext };
      const obj = JSON.parse(notes);
      if (obj && typeof obj === 'object' && !Array.isArray(obj)) {
        const maybeTitle = (obj as any).title ?? (obj as any).name;
        const maybeArea = (obj as any).area;
        const maybeCategory = (obj as any).category;
        if (typeof maybeTitle === 'string') title = maybeTitle;
        if (typeof maybeArea === 'string') area = maybeArea;
        if (typeof maybeCategory === 'string') category = maybeCategory;
        if ('delta' in obj) {
          const ops = (obj as any).delta as unknown[];
          plaintext = ops.map((op: any) => (typeof op?.insert === 'string' ? op.insert : '')).join('');
        }
      }
      if (!plaintext) plaintext = quillToPlaintext(notes ?? '');
    } catch (_) {
      plaintext = notes ?? '';
    }
    return { title, area, category, plaintext };
  }

serve(async (req) => {
  const origin = req.headers.get("Origin");
  const corsHeaders = makeCorsHeaders(origin);
  // Preflight support
  if (req.method === "OPTIONS") {
    // Only acknowledge allowed origins to avoid reflecting arbitrary origins
    if (!isOriginAllowed(origin)) {
      return new Response("Forbidden", { status: 403, headers: { ...corsHeaders, "Content-Type": "text/plain" } });
    }
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    if (!isOriginAllowed(origin)) {
      return new Response(JSON.stringify({ error: "origin_forbidden" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const { query, top_k = 8, min_similarity = 0.0 } = await req.json();
    if (typeof query === 'string' && query.length > 2000) {
      return new Response(JSON.stringify({ error: 'Query too long' }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!query || typeof query !== "string") {
      return new Response(JSON.stringify({ error: "query required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "missing_bearer" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: user } = await supabase.auth.getUser();
    const userId = user.user?.id;
    if (!userId)
      return new Response("Unauthorized", {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });

    // Robuste Zeitfenster-Erkennung (vorab, für deterministische Pfade in beiden Modi)
    const lower = query.toLowerCase();
    let days = 7;
    const mDays = lower.match(/letzten\s+(\d+)\s*tag(e|en)?/);
    const mWeeks = lower.match(/letzten\s+(\d+)\s*woche(n)?/);
    const mMonths = lower.match(/letzten\s+(\d+)\s*monat(en)?/);
    if (mDays) days = Math.max(1, parseInt(mDays[1], 10));
    else if (mWeeks) days = Math.max(1, parseInt(mWeeks[1], 10)) * 7;
    else if (mMonths) days = Math.max(1, parseInt(mMonths[1], 10)) * 30;
    if (/heute/.test(lower)) days = 1;
    if (/gestern/.test(lower)) days = 2;
    const sinceDet = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

    // Deterministische Pfade vorab: Zählung und einfache Zusammenfassung per SQL (beide Modi)
    const isCountEarly = /wie\s*viele|anzahl|wieviel/.test(lower);
    const isTotal = /\binsgesamt\b/.test(lower);
    if (isCountEarly) {
      if (isTotal) {
        const { count: total } = await supabase
          .from("action_logs")
          .select("id", { head: true, count: "exact" })
          .eq("user_id", userId);
        const nTotal = total ?? 0;
        return new Response(JSON.stringify({
          answer: `Insgesamt hast du ${nTotal} Aktivität${nTotal === 1 ? '' : 'en'} erfasst.`,
          sources: [],
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      let { count } = await supabase
        .from("action_logs")
        .select("id", { head: true, count: "exact" })
        .eq("user_id", userId)
        .gte("occurred_at", sinceDet);
      const n = count ?? 0;
      if (n === 0) {
        const totalRes = await supabase
          .from("action_logs")
          .select("id", { head: true, count: "exact" })
          .eq("user_id", userId);
        const total = totalRes.count ?? 0;
        return new Response(JSON.stringify({
          answer: `Im gewünschten Zeitraum (≈${days} Tage) keine Aktivitäten. Insgesamt hast du ${total} Aktivitäten erfasst.`,
          sources: [],
        }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
      }
      return new Response(JSON.stringify({
        answer: `Du hast in den letzten ${days} Tagen ${n} Aktivität${n === 1 ? '' : 'en'} erfasst.`,
        sources: [],
      }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const isSummaryEarly = /fasse|zusammenfassung|zusammen/.test(lower);
    if (isSummaryEarly) {
      let { data: rows } = await supabase
        .from("action_logs")
        .select("id, occurred_at, notes")
        .eq("user_id", userId)
        .gte("occurred_at", sinceDet)
        .order("occurred_at", { ascending: false })
        .limit(12);
      if (!rows || rows.length === 0) {
        const since30 = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
        const res30 = await supabase
          .from("action_logs")
          .select("id, occurred_at, notes")
          .eq("user_id", userId)
          .gte("occurred_at", since30)
          .order("occurred_at", { ascending: false })
          .limit(12);
        rows = res30.data ?? [];
        days = Math.max(days, 30);
      }
      const lines = (rows ?? []).map((r: any) => `- ${new Date(r.occurred_at).toISOString().slice(0,10)}: ${quillToPlaintext(r.notes ?? "").split("\n")[0]}`);
      const text = lines.length > 0
        ? `Letzte Aktivitäten (ca. ${days} Tage):\n` + lines.join("\n")
        : `Keine Daten im Zeitraum der letzten ${days} Tage gefunden.`;
      return new Response(JSON.stringify({ answer: text, sources: [] }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Erzwinge Private Mode: keine externen LLM-Calls; erweitertes regelbasiertes Q&A
    {
      const since = sinceDet;

      // Hilfsfunktionen
      const areaMatch = async () => {
        const areasRes = await supabase
          .from('life_areas')
          .select('name, category')
          .eq('user_id', userId);
        const areas = areasRes.data ?? [];
        let matched: {name: string, category: string} | null = null;
        for (const a of areas) {
          const n = String(a.name ?? '').toLowerCase();
          const c = String(a.category ?? '').toLowerCase();
          if (n && lower.includes(n)) { matched = {name: a.name, category: a.category}; break; }
          if (c && lower.includes(c)) { matched = {name: a.name, category: a.category}; break; }
        }
        return matched;
      };

      const formatMinutes = (m: number) => {
        if (!m || m <= 0) return '0 Min';
        const h = Math.floor(m / 60);
        const r = m % 60;
        return h > 0 ? `${h} Std ${r} Min` : `${m} Min`;
      };

      // Intents
      const isCount = /\b(wie\s*viele|anzahl|wieviel)\b/.test(lower);
      const isXp = /\bxp\b|punkte|erfahr/i.test(lower);
      const isAvg = /durchschnitt|ø\s*dauer/.test(lower);
      const isSumDuration = /\b(gesamt|insgesamt).*dauer|wie\s*lange|summe\s*dauer|gesamtmin|stunden\b/.test(lower);
      const isTop = /top|meist|welcher\s*bereich|welche\s*bereiche/.test(lower);
      const isLast = /zuletzt|letzte(n)?\s*aktivität/.test(lower);
      const isStreak = /streak|serie|tage\s*in\s*folge/.test(lower);
      const mOnDate = lower.match(/am\s*(\d{1,2})[.](\d{1,2})(?:[.](\d{2,4}))?/);
      const isFocus = /fokus|focus|woran\s*habe\s*ich\s*gearbeitet|worauf\s*habe\s*ich\s*.*fokus/.test(lower);
      const isSummarize = /fasse|zusammenfassung|zusammen/.test(lower);
      const mBook = lower.match(/buch\s+"?([^"\n]+)"?|book\s+"?([^"\n]+)"?/);

      // Streak (DB RPC, falls vorhanden)
      if (isStreak) {
        try {
          const { data: sData } = await supabase.rpc('calculate_streak', { uid: userId });
          const s = (Array.isArray(sData) ? (sData[0]?.streak ?? 0) : (sData?.streak ?? 0)) as number;
          return new Response(JSON.stringify({ answer: `Dein aktueller Streak: ${s} Tag${s === 1 ? '' : 'e'}.`, sources: [] }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        } catch (_) {
          // Fallback: clientseitig zählen
          const since90 = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString();
          const { data: rows } = await supabase
            .from('action_logs')
            .select('occurred_at')
            .eq('user_id', userId)
            .gte('occurred_at', since90)
            .order('occurred_at');
          const daysSet = new Set((rows ?? []).map((r: any) => new Date(r.occurred_at).toISOString().slice(0,10)));
          let streak = 0;
          for (let i = 0; i < 90; i++) {
            const d = new Date(Date.now() - i*24*60*60*1000).toISOString().slice(0,10);
            if (daysSet.has(d)) streak++; else break;
          }
          return new Response(JSON.stringify({ answer: `Dein aktueller Streak: ${streak} Tag${streak === 1 ? '' : 'e'}.`, sources: [] }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
      }

      // Spezifischer Tag
      if (mOnDate) {
        const dd = parseInt(mOnDate[1], 10);
        const mm = parseInt(mOnDate[2], 10);
        const yyyy = mOnDate[3] ? parseInt(mOnDate[3], 10) : new Date().getFullYear();
        const start = new Date(yyyy, mm-1, dd).toISOString();
        const end = new Date(yyyy, mm-1, dd+1).toISOString();
        const { data: rows } = await supabase
          .from('action_logs')
          .select('id, occurred_at, notes, earned_xp, duration_min')
          .eq('user_id', userId)
          .gte('occurred_at', start)
          .lt('occurred_at', end)
          .order('occurred_at', { ascending: false });
        const lines = (rows ?? []).map((r: any) => `- ${new Date(r.occurred_at).toISOString().slice(0,16).replace('T',' ')} · ${formatMinutes(r.duration_min ?? 0)} · +${r.earned_xp} XP · ${quillToPlaintext(r.notes ?? '').split('\n')[0]}`);
        const text = lines.length ? `Aktivitäten am ${dd}.${mm}.${yyyy}:\n` + lines.join('\n') : `Keine Aktivitäten am ${dd}.${mm}.${yyyy}.`;
        return new Response(JSON.stringify({ answer: text, sources: [] }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      // Bereichsfilter (falls im Text genannt)
      const area = await areaMatch();
      const areaFilter = area ? ` and lower((notes::jsonb->>'area')::text) = '${String(area.name).toLowerCase()}'` : '';

      // Zählung
      if (isCount) {
        let q = supabase
          .from('action_logs')
          .select('id', { head: true, count: 'exact' })
          .eq('user_id', userId)
          .gte('occurred_at', since);
        // Supabase-Client unterstützt hier keinen direkten JSON-Filter im head-Count; daher ohne areaFilter im Count.
        const { count } = await q;
        const n = count ?? 0;
        return new Response(JSON.stringify({ answer: `${area ? `Im Bereich ${area.name} ` : ''}in den letzten ${days} Tagen: ${n} Aktivität${n === 1 ? '' : 'en'}.`, sources: [] }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      // XP gesamt (Zeitraum)
      if (isXp) {
        let { data: rows } = await supabase
          .from('action_logs')
          .select('earned_xp, notes, occurred_at')
          .eq('user_id', userId)
          .gte('occurred_at', since);
        rows = (rows ?? []).filter((r: any) => area ? String((() => { try { return JSON.parse(r.notes ?? '{}')?.area ?? ''; } catch { return ''; } })()).toLowerCase() === String(area.name).toLowerCase() : true);
        const total = (rows ?? []).reduce((s: number, r: any) => s + (Number(r.earned_xp) || 0), 0);
        return new Response(JSON.stringify({ answer: `${area ? `XP im Bereich ${area.name}` : 'XP'} in den letzten ${days} Tagen: ${total}.`, sources: [] }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      // Durchschnittliche Dauer
      if (isAvg) {
        let { data: rows } = await supabase
          .from('action_logs')
          .select('duration_min, notes, occurred_at')
          .eq('user_id', userId)
          .gte('occurred_at', since);
        rows = (rows ?? []).filter((r: any) => area ? String((() => { try { return JSON.parse(r.notes ?? '{}')?.area ?? ''; } catch { return ''; } })()).toLowerCase() === String(area.name).toLowerCase() : true);
        const vals = (rows ?? []).map((r: any) => Number(r.duration_min) || 0).filter((n: number) => n > 0);
        const avg = vals.length ? Math.round(vals.reduce((a,b)=>a+b,0)/vals.length) : 0;
        return new Response(JSON.stringify({ answer: `${area ? `Ø Dauer im Bereich ${area.name}` : 'Ø Dauer'} in den letzten ${days} Tagen: ${formatMinutes(avg)}.`, sources: [] }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      // Gesamtdauer
      if (isSumDuration) {
        let { data: rows } = await supabase
          .from('action_logs')
          .select('duration_min, notes, occurred_at')
          .eq('user_id', userId)
          .gte('occurred_at', since);
        rows = (rows ?? []).filter((r: any) => area ? String((() => { try { return JSON.parse(r.notes ?? '{}')?.area ?? ''; } catch { return ''; } })()).toLowerCase() === String(area.name).toLowerCase() : true);
        const total = (rows ?? []).reduce((s: number, r: any) => s + (Number(r.duration_min) || 0), 0);
        return new Response(JSON.stringify({ answer: `${area ? `Gesamtdauer im Bereich ${area.name}` : 'Gesamtdauer'} in den letzten ${days} Tagen: ${formatMinutes(total)}.`, sources: [] }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      // Top‑Bereiche (nach Count oder Dauer)
      if (isTop) {
        const metricIsDuration = /dauer|min|std/.test(lower);
        const { data: rows } = await supabase
          .from('action_logs')
          .select('notes, duration_min, occurred_at')
          .eq('user_id', userId)
          .gte('occurred_at', since);
        const agg = new Map<string, {count: number, dur: number}>();
        for (const r of (rows ?? [])) {
          let a = '';
          try { a = (JSON.parse(r.notes ?? '{}')?.area ?? '').toString(); } catch {}
          if (!a) continue;
          const key = a.toLowerCase();
          const cur = agg.get(key) ?? {count: 0, dur: 0};
          cur.count += 1;
          cur.dur += Number(r.duration_min) || 0;
          agg.set(key, cur);
        }
        const arr = Array.from(agg.entries()).map(([k,v]) => ({area: k, count: v.count, dur: v.dur}));
        arr.sort((a,b) => metricIsDuration ? b.dur - a.dur : b.count - a.count);
        const top = arr.slice(0, 5);
        if (top.length === 0) {
          return new Response(JSON.stringify({ answer: `Keine Daten für Top‑Bereiche im Zeitraum.`, sources: [] }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        const lines = top.map((t, i) => `${i+1}. ${t.area} – ${metricIsDuration ? formatMinutes(t.dur) : t.count + '×'}`);
        return new Response(JSON.stringify({ answer: `Top‑Bereiche der letzten ${days} Tage:\n` + lines.join('\n'), sources: [] }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      // Fokus der letzten X Tage: Bereich mit meisten Minuten (falls gleich: mit meisten Aktivitäten)
      if (isFocus) {
        const { data: rows } = await supabase
          .from('action_logs')
          .select('notes, duration_min')
          .eq('user_id', userId)
          .gte('occurred_at', since);
        const agg = new Map<string, {count: number, dur: number}>();
        for (const r of (rows ?? [])) {
          let a = '';
          try { a = (JSON.parse(r.notes ?? '{}')?.area ?? '').toString(); } catch {}
          if (!a) continue;
          const key = a.toLowerCase();
          const cur = agg.get(key) ?? {count: 0, dur: 0};
          cur.count += 1;
          cur.dur += Number(r.duration_min) || 0;
          agg.set(key, cur);
        }
        if (agg.size === 0) return new Response(JSON.stringify({ answer: `Keine Aktivitäten im Zeitraum.`, sources: [] }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        const arr = Array.from(agg.entries()).map(([k,v]) => ({area: k, count: v.count, dur: v.dur}));
        arr.sort((a,b) => b.dur - a.dur || b.count - a.count);
        const top = arr[0];
        return new Response(JSON.stringify({ answer: `Dein Fokus in den letzten ${days} Tagen lag auf „${top.area}“ (${Math.round(top.dur)} Min, ${top.count} Aktivität${top.count===1?'':'en'}).`, sources: [] }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      // Zusammenfassung für Bereich in Zeitraum
      if (isSummarize && (area || /fitness|lesen|bildung|ernährung|sport|karriere|beziehungen|meditation/.test(lower))) {
        let { data: rows } = await supabase
          .from('action_logs')
          .select('occurred_at, duration_min, earned_xp, notes')
          .eq('user_id', userId)
          .gte('occurred_at', since)
          .order('occurred_at', { ascending: false });
        const filterKey = area?.name?.toLowerCase() ?? (lower.match(/fitness|lesen|bildung|ernährung|sport|karriere|beziehungen|meditation/)?.[0] ?? '').toLowerCase();
        rows = (rows ?? []).filter((r: any) => {
          try { return String(JSON.parse(r.notes ?? '{}')?.area ?? '').toLowerCase() === filterKey; } catch { return false; }
        });
        const count = rows?.length ?? 0;
        const totalMin = (rows ?? []).reduce((s: number, r: any) => s + (Number(r.duration_min) || 0), 0);
        const avg = count ? Math.round(totalMin / count) : 0;
        const bullets = (rows ?? []).slice(0, 8).map((r: any) => `- ${new Date(r.occurred_at).toISOString().slice(0,10)}: ${extractMeta(r.notes).plaintext.split('\n')[0]}`);
        const text = `${filterKey ? filterKey.charAt(0).toUpperCase()+filterKey.slice(1) : 'Bereich'} – letzte ${days} Tage:\n` +
          `• Aktivitäten: ${count}\n• Gesamtdauer: ${formatMinutes(totalMin)}\n• Ø Dauer: ${formatMinutes(avg)}\n` +
          (bullets.length ? `Beispiel‑Notizen:\n${bullets.join('\n')}` : 'Keine Notizen verfügbar.');
        return new Response(JSON.stringify({ answer: text, sources: [] }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      // „Was habe ich aus dem Buch X gelernt?“ → Notes nach Titel/Plaintext durchsuchen
      if (/gelernt|learned/.test(lower) && (mBook?.[1] || mBook?.[2])) {
        const titlePhrase = (mBook?.[1] || mBook?.[2] || '').trim();
        const like = `%${titlePhrase}%`;
        const { data: rows } = await supabase
          .from('action_logs')
          .select('occurred_at, notes')
          .eq('user_id', userId)
          .ilike('notes', like)
          .order('occurred_at', { ascending: false })
          .limit(50);
        const snippets: string[] = [];
        for (const r of (rows ?? [])) {
          const meta = extractMeta(r.notes);
          const line = meta.plaintext.split('\n').map((s) => s.trim()).filter(Boolean)[0] ?? '';
          if (!line) continue;
          if (!snippets.includes(line)) snippets.push(line);
          if (snippets.length >= 10) break;
        }
        const text = snippets.length
          ? `Deine Notizen zu „${titlePhrase}“ (Auszug):\n` + snippets.map(s => `- ${s}`).join('\n')
          : `Keine expliziten Notizen zu „${titlePhrase}“ gefunden.`;
        return new Response(JSON.stringify({ answer: text, sources: [] }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
      }

      // Fallback: Liste letzter Aktivitäten (Titel+Datum)
      let { data: rows } = await supabase
        .from('action_logs')
        .select('id, occurred_at, notes, earned_xp, duration_min')
        .eq('user_id', userId)
        .gte('occurred_at', since)
        .order('occurred_at', { ascending: false })
        .limit(10);
      const lines = (rows ?? []).map((r: any) => `- ${new Date(r.occurred_at).toISOString().slice(0,10)} · ${formatMinutes(r.duration_min ?? 0)} · +${r.earned_xp} XP · ${quillToPlaintext(r.notes ?? '').split('\n')[0]}`);
      const text = lines.length > 0 ? `Letzte Aktivitäten (ca. ${days} Tage):\n` + lines.join('\n') : `Keine Daten im Zeitraum der letzten ${days} Tage gefunden.`;
      return new Response(JSON.stringify({ answer: text, sources: [] }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    // Externer LLM/RAG-Teil ist in Produktionsmodus deaktiviert.
    // Wenn du ihn wieder aktivieren willst, entferne diesen early return
    // und reaktiviere den Code unterhalb (RAG + OpenAI Chat Call).
    return new Response(JSON.stringify({
      answer: 'KI‑Modus ist deaktiviert. Stelle konkrete Datenfragen (z. B. "Wie viele Aktivitäten in den letzten 7 Tagen?") oder nutze die App‑Ansichten.',
      sources: [],
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 });

    const qEmb = await embedQuery(query);
    // Zeitfenster-Erkennung (robust): "letzten X Tag(e|en)"
    const lowerQ = query.toLowerCase();
    let sinceIso: string | null = null;
    const m = lowerQ.match(/letzten\s+(\d+)\s*tag(e|en)?/);
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
        .eq("user_id", userId)
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
      if (isTotal) {
        const { count: total, error: tErr } = await supabase
          .from("action_logs")
          .select("id", { head: true, count: "exact" })
          .eq("user_id", userId);
        if (!tErr) {
          const nTotal = total ?? 0;
          return new Response(
            JSON.stringify({
              answer: `Insgesamt hast du ${nTotal} Aktivität${nTotal === 1 ? '' : 'en'} erfasst.`,
              sources: [],
            }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 },
          );
        }
      }
      const days = m ? Math.max(1, parseInt(m[1], 10)) : 7;
      const since = (sinceIso ?? new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString());
      const { count, error: cErr } = await supabase
        .from("action_logs")
        .select("id", { head: true, count: "exact" })
        .eq("user_id", userId)
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

