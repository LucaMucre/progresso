import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders: HeadersInit = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!; // needs service role to delete auth user
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    // Use anon client to read the current user from the JWT
    const supabaseUser = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: user, error: userErr } = await supabaseUser.auth.getUser();
    if (userErr) throw userErr;
    const userId = user.user?.id;
    if (!userId) return new Response("Unauthorized", { status: 401, headers: corsHeaders });

    // Use service-role client for destructive operations
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // Atomar in der DB löschen (idempotent)
    {
      const { error } = await admin.rpc('delete_user_fully', { p_uid: userId });
      if (error) throw error;
    }

    // delete auth user (requires service role)
    {
      const { error } = await (admin as any).auth.admin.deleteUser(userId);
      if (error) throw error;
    }

    return new Response(JSON.stringify({ ok: true, id: userId }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});

