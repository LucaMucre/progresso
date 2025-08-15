-- Performance indexes for common queries (calendar, logs, achievements)
-- Safe to run multiple times with IF NOT EXISTS

create index if not exists idx_action_logs_user_date
  on public.action_logs (user_id, occurred_at desc);

create index if not exists idx_action_logs_user_created
  on public.action_logs (user_id, created_at desc);

create index if not exists user_achievements_user_created
  on public.user_achievements (user_id, unlocked_at desc);

