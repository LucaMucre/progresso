-- Security hardening based on Supabase Security Advisor warnings
-- - Pin search_path on SECURITY DEFINER / trigger functions
-- - Move extensions out of public into dedicated schema

-- 1) Ensure dedicated schema for extensions exists
create schema if not exists extensions;

-- 2) Move commonly used extensions to the dedicated schema when present
do $$ begin
  if exists (select 1 from pg_extension where extname = 'uuid-ossp') then
    execute 'alter extension "uuid-ossp" set schema extensions';
  end if;
  if exists (select 1 from pg_extension where extname = 'vector') then
    execute 'alter extension vector set schema extensions';
  end if;
end $$;

-- 3) Pin search_path at function level to avoid mutable path attacks
--    Use pg_catalog first to prefer system functions, then public.
do $$ begin
  -- calculate_streak(uid uuid)
  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'calculate_streak'
          and pg_get_function_identity_arguments(p.oid) = 'uid uuid'
  ) then
    execute 'alter function public.calculate_streak(uid uuid) set search_path = pg_catalog, public';
  end if;

  -- handle_new_user()
  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'handle_new_user'
          and pg_get_function_identity_arguments(p.oid) = ''
  ) then
    execute 'alter function public.handle_new_user() set search_path = pg_catalog, public';
  end if;

  -- handle_new_user_character()
  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'handle_new_user_character'
          and pg_get_function_identity_arguments(p.oid) = ''
  ) then
    execute 'alter function public.handle_new_user_character() set search_path = pg_catalog, public';
  end if;

  -- update_characters_updated_at() trigger helper
  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'update_characters_updated_at'
          and pg_get_function_identity_arguments(p.oid) = ''
  ) then
    execute 'alter function public.update_characters_updated_at() set search_path = pg_catalog, public';
  end if;

  -- update_life_areas_updated_at() trigger helper
  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'update_life_areas_updated_at'
          and pg_get_function_identity_arguments(p.oid) = ''
  ) then
    execute 'alter function public.update_life_areas_updated_at() set search_path = pg_catalog, public';
  end if;

  -- If other public.* functions are reported later, add similar guards here.
end $$;

-- 3b) Pin search_path for any overloads of specific function names flagged by Advisor
do $$ declare
  r record;
begin
  for r in
    select p.oid,
           format('%I.%I(%s)', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid)) as fqn
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('match_user_documents','delete_user_fully')
  loop
    execute format('alter function %s set search_path = pg_catalog, public', r.fqn);
  end loop;
end $$;

-- 4) Optional: set safe default search_path for app roles so unqualified
--    calls to extensions continue to work without leaking public.
--    (Run only if roles exist; harmless otherwise.)
do $$ begin
  begin execute 'alter role authenticated set search_path = public, extensions, pg_catalog'; exception when undefined_object then null; end;
  begin execute 'alter role anon set search_path = public, extensions, pg_catalog'; exception when undefined_object then null; end;
  begin execute 'alter role service_role set search_path = public, extensions, pg_catalog'; exception when undefined_object then null; end;
end $$;

