-- Progresso App - Complete Database Setup
-- Führe diese SQL-Befehle im Supabase Dashboard SQL Editor aus

-- 1. Characters Tabelle erstellen
CREATE TABLE IF NOT EXISTS public.characters (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL DEFAULT 'Hero',
    level INTEGER NOT NULL DEFAULT 1,
    total_xp INTEGER NOT NULL DEFAULT 0,
    stats JSONB NOT NULL DEFAULT '{
        "strength": 1,
        "intelligence": 1,
        "wisdom": 1,
        "charisma": 1,
        "endurance": 1,
        "agility": 1
    }',
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Life Areas Tabelle erstellen
CREATE TABLE IF NOT EXISTS public.life_areas (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    parent_id UUID REFERENCES public.life_areas(id) ON DELETE CASCADE,
    color TEXT NOT NULL DEFAULT '#2196F3',
    icon TEXT NOT NULL DEFAULT 'circle',
    order_index INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Indexes erstellen
CREATE UNIQUE INDEX IF NOT EXISTS characters_user_id_idx ON public.characters(user_id);
CREATE INDEX IF NOT EXISTS life_areas_user_id_idx ON public.life_areas(user_id);
CREATE INDEX IF NOT EXISTS life_areas_order_idx ON public.life_areas(order_index);

-- 4. RLS für characters aktivieren
ALTER TABLE public.characters ENABLE ROW LEVEL SECURITY;

-- 5. RLS für life_areas aktivieren
ALTER TABLE public.life_areas ENABLE ROW LEVEL SECURITY;

-- 6. Policies für characters
CREATE POLICY "Users can only access their own character"
ON public.characters
FOR ALL
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 7. Policies für life_areas
CREATE POLICY "Users can only access their own life areas"
ON public.life_areas
FOR ALL
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 8. image_url Feld zu action_logs hinzufügen (falls noch nicht vorhanden)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'action_logs' AND column_name = 'image_url') THEN
        ALTER TABLE public.action_logs ADD COLUMN image_url TEXT;
    END IF;
END $$;

-- 9. Storage Bucket für Avatare erstellen
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 10. Storage Bucket für Activity Images erstellen
INSERT INTO storage.buckets (id, name, public)
VALUES ('activity-images', 'activity-images', true)
ON CONFLICT (id) DO NOTHING;

-- 11. Storage Policies für Avatare
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

-- 12. Storage Policies für Activity Images
CREATE POLICY "Users can upload activity images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'activity-images' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can view their own activity images"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'activity-images' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can update their own activity images"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'activity-images' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete their own activity images"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'activity-images' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- 13. Funktion für automatische User-Profile-Erstellung
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, name)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'name');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 14. Trigger aktivieren
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 15. Bestätigung
SELECT 'Complete Database Setup erfolgreich angewendet!' as status; 