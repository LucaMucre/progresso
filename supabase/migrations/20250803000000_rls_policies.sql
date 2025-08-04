-- RLS Policies für Progresso App
-- 2025-08-03

-- RLS für action_templates aktivieren
ALTER TABLE public.action_templates ENABLE ROW LEVEL SECURITY;

-- RLS für action_logs aktivieren
ALTER TABLE public.action_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Users können nur ihre eigenen Templates sehen/bearbeiten
CREATE POLICY "Users can only access their own templates"
ON public.action_templates
FOR ALL
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Policy: Users können nur ihre eigenen Logs sehen/bearbeiten
CREATE POLICY "Users can only access their own logs"
ON public.action_logs
FOR ALL
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Policy: Users können nur ihr eigenes Profil sehen/bearbeiten
CREATE POLICY "Users can only access their own profile"
ON public.users
FOR ALL
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Trigger für automatische User-Profile-Erstellung
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, name)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'name');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger aktivieren
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user(); 