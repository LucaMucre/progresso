-- Fix für Bild-Upload in Progresso App
-- Führe diese SQL-Befehle im Supabase Dashboard SQL Editor aus

-- 1. image_url Feld zu action_logs hinzufügen (falls noch nicht vorhanden)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'action_logs' AND column_name = 'image_url') THEN
        ALTER TABLE public.action_logs ADD COLUMN image_url TEXT;
        RAISE NOTICE 'image_url Spalte zu action_logs hinzugefügt';
    ELSE
        RAISE NOTICE 'image_url Spalte existiert bereits';
    END IF;
END $$;

-- 2. Storage Bucket für Activity Images erstellen
INSERT INTO storage.buckets (id, name, public)
VALUES ('activity-images', 'activity-images', true)
ON CONFLICT (id) DO NOTHING;

-- 3. Storage Policies für Activity Images (mit DROP IF EXISTS um Konflikte zu vermeiden)
DROP POLICY IF EXISTS "Users can upload activity images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own activity images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own activity images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own activity images" ON storage.objects;

-- 4. Neue Storage Policies erstellen
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

-- 5. Bestätigung
SELECT 'Bild-Upload Fix erfolgreich angewendet!' as status; 