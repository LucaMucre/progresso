-- RLS Policies und Storage Security
-- 2025-08-03

-- RLS für alle Tabellen aktivieren
alter table public.users enable row level security;
alter table public.action_templates enable row level security;
alter table public.action_logs enable row level security;

-- Users Policies
create policy "Users can view own profile"
  on public.users for select
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.users for insert
  with check (auth.uid() = id);

create policy "Users can update own profile"
  on public.users for update
  using (auth.uid() = id);

-- Action Templates Policies
create policy "Users can view own templates"
  on public.action_templates for select
  using (auth.uid() = user_id);

create policy "Users can insert own templates"
  on public.action_templates for insert
  with check (auth.uid() = user_id);

create policy "Users can update own templates"
  on public.action_templates for update
  using (auth.uid() = user_id);

create policy "Users can delete own templates"
  on public.action_templates for delete
  using (auth.uid() = user_id);

-- Action Logs Policies
create policy "Users can view own logs"
  on public.action_logs for select
  using (auth.uid() = user_id);

create policy "Users can insert own logs"
  on public.action_logs for insert
  with check (auth.uid() = user_id);

create policy "Users can update own logs"
  on public.action_logs for update
  using (auth.uid() = user_id);

create policy "Users can delete own logs"
  on public.action_logs for delete
  using (auth.uid() = user_id);

-- Storage Bucket für Avatare erstellen (falls nicht vorhanden)
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Storage Policies für Avatare (korrigierter Index)
create policy "Users can upload own avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars' 
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can view own avatar"
  on storage.objects for select
  using (
    bucket_id = 'avatars' 
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can update own avatar"
  on storage.objects for update
  using (
    bucket_id = 'avatars' 
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can delete own avatar"
  on storage.objects for delete
  using (
    bucket_id = 'avatars' 
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Funktion für automatische User-Profile-Erstellung
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

-- Trigger für automatische User-Profile-Erstellung
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user(); 