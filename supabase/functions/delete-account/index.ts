import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders: HeadersInit = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!; // needs service role to delete auth user

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: user } = await supabase.auth.getUser();
    const userId = user.user?.id;
    if (!userId) return new Response("Unauthorized", { status: 401, headers: corsHeaders });

    // delete user-owned rows (adjust table list as needed)
    const tables = [
      "action_logs",
      "action_templates",
      "life_areas",
      "user_documents",
      "users",
    ];
    for (const t of tables) {
      await supabase.from(t).delete().eq("user_id", userId);
    }

    // delete auth user (requires service role)
    const admin = (supabase as any).auth.admin;
    await admin.deleteUser(userId);

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});

