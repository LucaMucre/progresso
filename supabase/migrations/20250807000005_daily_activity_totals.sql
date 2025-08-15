-- Aggregates activities per day and area for a month window
-- Returns: day::date, area_key text, total integer

create or replace function public.daily_activity_totals(
  uid uuid,
  start_date date,
  end_date date
) returns table(day date, area_key text, total integer, sum_duration integer, sum_xp integer)
language sql
security definer
set search_path = pg_catalog, public
as $$
  with enriched as (
    select
      l.occurred_at::date as day,
      nullif(trim((regexp_match(l.notes::text,
        '"(area|life_area|category)"\s*:\s*"([^"]+)"'
      ))[2]), '') as area_from_notes,
      t.category as area_from_template,
      coalesce(l.duration_min, 0) as duration_min,
      coalesce(l.earned_xp, 0) as earned_xp
    from public.action_logs l
    left join public.action_templates t on t.id = l.template_id
    where l.user_id = uid
      and l.occurred_at >= start_date
      and l.occurred_at < (end_date + 1)
  )
  select day,
         coalesce(area_from_notes, area_from_template, 'unknown') as area_key,
         count(*)::int as total,
         sum(duration_min)::int as sum_duration,
         sum(earned_xp)::int as sum_xp
  from enriched
  group by day, area_key
  order by day asc, total desc, sum_duration desc, sum_xp desc, area_key asc;
$$;

revoke all on function public.daily_activity_totals(uuid, date, date) from public;
grant execute on function public.daily_activity_totals(uuid, date, date) to anon, authenticated;

