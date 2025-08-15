-- Auth hardening: OTP expiry and leaked password protection
-- These settings mirror Supabase dashboard toggles; run only if the
-- auth schema and settings exist. This script is idempotent.

-- 1) Reduce OTP expiry from long defaults to 10 minutes (recommended)
--    See: auth.config for otp_max_age_sec
do $$ begin
  perform 1 from pg_namespace where nspname = 'auth';
  if found then
    -- Supabase exposes configs via "auth.config" table; update if present
    if exists (select 1 from information_schema.tables where table_schema='auth' and table_name='config') then
      update auth.config set otp_max_age = 600 where otp_max_age is distinct from 600;
    end if;
  end if;
end $$;

-- 2) Enable leaked password protection when table exists (requires GoTrue >= 2.64)
do $$ begin
  if exists (select 1 from information_schema.columns where table_schema='auth' and table_name='config' and column_name='enable_password_data_breach_detection') then
    update auth.config set enable_password_data_breach_detection = true where coalesce(enable_password_data_breach_detection,false) = false;
  end if;
end $$;

