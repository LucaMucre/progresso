-- RPC to sum earned_xp for a user. Uses search_path hardening and RLS-safe filter.
create or replace function public.sum_user_xp(uid uuid)
returns table(sum integer)
language sql
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(sum(earned_xp), 0)::int as sum
  from public.action_logs
  where user_id = uid;
$$;

revoke all on function public.sum_user_xp(uuid) from public;
grant execute on function public.sum_user_xp(uuid) to anon, authenticated;

