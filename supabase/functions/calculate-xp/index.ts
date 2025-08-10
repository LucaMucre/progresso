import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create a Supabase client with the Auth context of the logged in user.
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Get the user from the request
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser()

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { action_log_id } = await req.json()

    if (!action_log_id) {
      return new Response(
        JSON.stringify({ error: 'action_log_id is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get the action log
    const { data: actionLog, error: logError } = await supabaseClient
      .from('action_logs')
      .select(`
        *,
        action_templates (
          base_xp,
          attr_strength,
          attr_endurance,
          attr_knowledge
        )
      `)
      .eq('id', action_log_id)
      .eq('user_id', user.id)
      .single()

    if (logError || !actionLog) {
      return new Response(
        JSON.stringify({ error: 'Action log not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Neue XP-Formel: Zeit + Textlänge + 10% bei Bild (Kategorie/Vorlage neutral)
    const durationMin: number = actionLog.duration_min ?? 0
    let earnedXp = Math.floor(durationMin / 5) // 1 XP je 5 Minuten

    // Textlänge schätzen
    const estimateTextLen = (notes?: string | null): number => {
      if (!notes || !notes.trim()) return 0
      try {
        const obj = JSON.parse(notes)
        if (Array.isArray(obj)) {
          // Quill Delta
          return obj.reduce((sum, e) => sum + (typeof e?.insert === 'string' ? e.insert.length : 0), 0)
        }
        if (typeof obj === 'object' && obj) {
          let len = 0
          if (typeof obj.title === 'string') len += obj.title.trim().length
          if (typeof obj.content === 'string') len += obj.content.trim().length
          if (Array.isArray((obj as any).ops)) {
            len += (obj as any).ops.reduce((s: number, o: any) => s + (typeof o?.insert === 'string' ? o.insert.length : 0), 0)
          }
          if (len > 0) return len
          return JSON.stringify(obj).replace(/[{}\[\]",:]+/g, ' ').trim().length
        }
      } catch {}
      return notes.replace(/\s+/g, ' ').trim().length
    }

    const textLen = estimateTextLen(actionLog.notes)
    earnedXp += Math.floor(textLen / 100) // 1 XP je 100 Zeichen

    const hasImage = !!actionLog.image_url && String(actionLog.image_url).trim().length > 0
    if (hasImage) earnedXp = Math.round(earnedXp * 1.1)

    if (earnedXp <= 0 && (durationMin > 0 || textLen > 0 || hasImage)) earnedXp = 1

    // Update the action log with calculated XP
    const { error: updateError } = await supabaseClient
      .from('action_logs')
      .update({ earned_xp: earnedXp })
      .eq('id', action_log_id)
      .eq('user_id', user.id)

    if (updateError) {
      return new Response(
        JSON.stringify({ error: 'Failed to update action log' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        earned_xp: earnedXp,
        action_log_id: action_log_id 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
}) 