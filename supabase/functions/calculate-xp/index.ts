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

    // Calculate XP with bonuses
    let earnedXp = actionLog.action_templates.base_xp

    // Duration bonus (every 10 minutes = +1 XP)
    if (actionLog.duration_min) {
      earnedXp += Math.floor(actionLog.duration_min / 10)
    }

    // Streak bonus (if user has a streak > 7 days)
    const { data: streakData } = await supabaseClient
      .from('action_logs')
      .select('occurred_at')
      .eq('user_id', user.id)
      .gte('occurred_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())
      .order('occurred_at', { ascending: false })

    if (streakData) {
      const dates = streakData.map(log => 
        new Date(log.occurred_at).toDateString()
      ).filter((date, index, arr) => arr.indexOf(date) === index)

      let streak = 0
      const today = new Date().toDateString()
      const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toDateString()

      if (dates.includes(today)) {
        streak = 1
        let checkDate = new Date(Date.now() - 24 * 60 * 60 * 1000)
        
        while (dates.includes(checkDate.toDateString())) {
          streak++
          checkDate = new Date(checkDate.getTime() - 24 * 60 * 60 * 1000)
        }
      } else if (dates.includes(yesterday)) {
        streak = 1
        let checkDate = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)
        
        while (dates.includes(checkDate.toDateString())) {
          streak++
          checkDate = new Date(checkDate.getTime() - 24 * 60 * 60 * 1000)
        }
      }

      // Streak bonus: +2 XP for 7+ day streak
      if (streak >= 7) {
        earnedXp += 2
      }
    }

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