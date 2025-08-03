-- init_schema.sql
-- 2025-07-31

-- UUID-Extension aktivieren (benötigt für uuid_generate_v4())
create extension if not exists "uuid-ossp";

-- Tabelle users anlegen
create table public.users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  name text,
  bio text,
  avatar_url text,
  created_at timestamptz default now()
);

-- Tabelle action_templates anlegen
create table public.action_templates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  name text not null,
  category text not null,
  base_xp integer not null default 25,
  attr_strength integer not null default 0,
  attr_endurance integer not null default 0,
  attr_knowledge integer not null default 0,
  created_at timestamptz default now()
);

-- Tabelle action_logs anlegen
create table public.action_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  template_id uuid references public.action_templates(id) on delete cascade,
  occurred_at timestamptz default now(),
  duration_min integer,
  notes text,
  earned_xp integer not null default 25,
  created_at timestamptz default now()
);

-- Indizes für bessere Performance
create index idx_action_templates_user_id on public.action_templates(user_id);
create index idx_action_logs_user_id on public.action_logs(user_id);
create index idx_action_logs_occurred_at on public.action_logs(occurred_at);
create index idx_action_logs_template_id on public.action_logs(template_id);