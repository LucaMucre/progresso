-- Progresso App Setup - RLS Policies und Storage
-- Führe diese SQL-Befehle im Supabase Dashboard SQL Editor aus

-- 1. RLS für alle Tabellen aktivieren
ALTER TABLE public.action_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.action_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 2. Policies für action_templates
CREATE POLICY "Users can only access their own templates"
ON public.action_templates
FOR ALL
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 3. Policies für action_logs
CREATE POLICY "Users can only access their own logs"
ON public.action_logs
FOR ALL
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 4. Policies für users
CREATE POLICY "Users can only access their own profile"
ON public.users
FOR ALL
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- 5. Storage Bucket für Avatare erstellen
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 6. Storage Policies für Avatare
CREATE POLICY "Users can upload own avatar"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can view own avatar"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'avatars' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can update own avatar"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete own avatar"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- 7. Funktion für automatische User-Profile-Erstellung
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, name)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'name');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Trigger aktivieren
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 9. Bestätigung
SELECT 'RLS Policies und Storage Setup erfolgreich angewendet!' as status; 