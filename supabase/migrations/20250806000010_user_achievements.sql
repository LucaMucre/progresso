-- User achievements persistence
create table if not exists public.user_achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id text not null,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

alter table public.user_achievements enable row level security;

-- Select own achievements
create policy if not exists "ua_select_own"
  on public.user_achievements for select
  using (auth.uid() = user_id);

-- Insert new achievements for self
create policy if not exists "ua_insert_own"
  on public.user_achievements for insert
  with check (auth.uid() = user_id);

-- Update existing achievements for self (for upsert conflicts)
create policy if not exists "ua_update_own"
  on public.user_achievements for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists user_achievements_user_id_idx on public.user_achievements(user_id);



