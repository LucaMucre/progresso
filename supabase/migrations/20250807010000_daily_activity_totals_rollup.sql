-- Roll up subcategories to their parent life area in calendar aggregation
-- Maps: inner -> spirituality, social -> relationships, work -> career, development -> learning
-- Keeps other known areas as-is. Everything else becomes 'unknown'.

create or replace function public.daily_activity_totals(
  uid uuid,
  start_date date,
  end_date date
) returns table(
  day date,
  area_key text,
  total integer,
  sum_duration integer,
  sum_xp integer
)
language sql
security definer
set search_path = pg_catalog, public
as $$
  with enriched as (
    select
      l.occurred_at::date as day,
      -- Pull possible values from notes JSON and template category
      lower(nullif(trim((l.notes::jsonb ->> 'area')), '')) as area_from_notes,
      lower(nullif(trim((l.notes::jsonb ->> 'life_area')), '')) as life_area_from_notes,
      lower(nullif(trim((l.notes::jsonb ->> 'category')), '')) as category_from_notes,
      lower(nullif(trim(t.category), '')) as category_from_template,
      coalesce(l.duration_min, 0)::int as duration_min,
      coalesce(l.earned_xp, 0)::int as earned_xp
    from public.action_logs l
    left join public.action_templates t on t.id = l.template_id
    where l.user_id = uid
      and l.occurred_at >= start_date
      and l.occurred_at < (end_date + 1)
  ),
  normalized as (
    select
      day,
      (
        case
          -- If notes provide a direct area in the known set, use it
          when coalesce(area_from_notes, life_area_from_notes) in (
            'spirituality','finance','career','learning','relationships','health','creativity'
          ) then coalesce(area_from_notes, life_area_from_notes)

          -- Otherwise roll up known subcategories from notes to their parents
          when category_from_notes in ('inner') then 'spirituality'
          when category_from_notes in ('social') then 'relationships'
          when category_from_notes in ('work') then 'career'
          when category_from_notes in ('development') then 'learning'
          when category_from_notes in ('finance') then 'finance'
          when category_from_notes in ('health') then 'health'

          -- Or from template category if notes don't carry structure
          when category_from_template in ('inner') then 'spirituality'
          when category_from_template in ('social') then 'relationships'
          when category_from_template in ('work') then 'career'
          when category_from_template in ('development') then 'learning'
          when category_from_template in ('finance') then 'finance'
          when category_from_template in ('health') then 'health'

          -- As a last resort, accept a template category that already equals a parent area
          when category_from_template in (
            'spirituality','finance','career','learning','relationships','health','creativity'
          ) then category_from_template

          else 'unknown'
        end
      ) as area_key,
      duration_min,
      earned_xp
    from enriched
  )
  select
    day,
    area_key,
    count(*)::int as total,
    sum(duration_min)::int as sum_duration,
    sum(earned_xp)::int as sum_xp
  from normalized
  group by day, area_key
  order by day asc, total desc, sum_duration desc, sum_xp desc, area_key asc;
$$;

revoke all on function public.daily_activity_totals(uuid, date, date) from public;
grant execute on function public.daily_activity_totals(uuid, date, date) to anon, authenticated;

