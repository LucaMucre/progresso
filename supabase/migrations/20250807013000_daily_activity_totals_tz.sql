-- TZ-aware rollup for daily activity totals
-- Adds tz_offset_minutes so that grouping and filtering use the user's local day

create or replace function public.daily_activity_totals(
  uid uuid,
  start_date date,
  end_date date,
  tz_offset_minutes integer default 0
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
      -- shift occurred_at by the client's timezone offset before casting to date
      (l.occurred_at + make_interval(mins => tz_offset_minutes))::date as day,
      lower(nullif(trim((l.notes::jsonb ->> 'area')), '')) as area_from_notes,
      lower(nullif(trim((l.notes::jsonb ->> 'life_area')), '')) as life_area_from_notes,
      lower(nullif(trim((l.notes::jsonb ->> 'category')), '')) as category_from_notes,
      lower(nullif(trim(t.category), '')) as category_from_template,
      coalesce(l.duration_min, 0)::int as duration_min,
      coalesce(l.earned_xp, 0)::int as earned_xp
    from public.action_logs l
    left join public.action_templates t on t.id = l.template_id
    where l.user_id = uid
      -- Convert local day window [start_date, end_date] to UTC by subtracting the offset
      and l.occurred_at >= ((start_date)::timestamp - make_interval(mins => tz_offset_minutes))
      and l.occurred_at <  (((end_date + 1))::timestamp - make_interval(mins => tz_offset_minutes))
  ),
  normalized as (
    select
      day,
      (
        case
          when coalesce(area_from_notes, life_area_from_notes) in (
            'spirituality','finance','career','learning','relationships','health','creativity'
          ) then coalesce(area_from_notes, life_area_from_notes)

          when category_from_notes in ('inner') then 'spirituality'
          when category_from_notes in ('social') then 'relationships'
          when category_from_notes in ('work') then 'career'
          when category_from_notes in ('development') then 'learning'
          when category_from_notes in ('finance') then 'finance'
          when category_from_notes in ('health') then 'health'

          when category_from_template in ('inner') then 'spirituality'
          when category_from_template in ('social') then 'relationships'
          when category_from_template in ('work') then 'career'
          when category_from_template in ('development') then 'learning'
          when category_from_template in ('finance') then 'finance'
          when category_from_template in ('health') then 'health'

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

grant execute on function public.daily_activity_totals(uuid, date, date, integer) to anon, authenticated;

