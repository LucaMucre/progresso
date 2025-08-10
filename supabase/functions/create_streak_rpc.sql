-- Creates a deterministic streak RPC that counts consecutive days back from the most recent log
-- Safe to run multiple times (DROP IF EXISTS)

create or replace function public.calculate_streak(uid uuid)
returns integer
language plpgsql
security definer
as $$
declare
  d date;
  last_day date;
  streak int := 0;
begin
  -- most recent day with any activity
  select max((occurred_at at time zone 'utc')::date) into last_day
  from public.action_logs
  where user_id = uid;

  if last_day is null then
    return 0;
  end if;

  d := last_day;
  loop
    exit when not exists (
      select 1 from public.action_logs
      where user_id = uid and (occurred_at at time zone 'utc')::date = d
    );
    streak := streak + 1;
    d := d - interval '1 day';
  end loop;

  return streak;
end;
$$;

revoke all on function public.calculate_streak(uuid) from public;
grant execute on function public.calculate_streak(uuid) to anon, authenticated;

