-- Fix für Avatar Storage in Progresso App
-- Führe diese SQL-Befehle im Supabase Dashboard SQL Editor aus

-- 1. Avatar Storage Bucket erstellen (falls noch nicht vorhanden)
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Storage Policies für Avatars löschen (falls vorhanden)
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;

-- 3. Storage Policies für Avatars erstellen
-- INSERT Policy - Benutzer können ihr eigenes Avatar hochladen
CREATE POLICY "Users can upload their own avatar" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- SELECT Policy - Benutzer können alle Avatars ansehen (public)
CREATE POLICY "Users can view all avatars" ON storage.objects
FOR SELECT USING (bucket_id = 'avatars');

-- UPDATE Policy - Benutzer können ihr eigenes Avatar aktualisieren
CREATE POLICY "Users can update their own avatar" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- DELETE Policy - Benutzer können ihr eigenes Avatar löschen
CREATE POLICY "Users can delete their own avatar" ON storage.objects
FOR DELETE USING (
  bucket_id = 'avatars' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- 4. Überprüfung
SELECT 
  'Avatar Storage Bucket' as check_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'avatars') 
    THEN '✅ Avatars bucket exists' 
    ELSE '❌ Avatars bucket missing' 
  END as status
UNION ALL
SELECT 
  'Avatar Storage Policies' as check_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname LIKE '%avatar%')
    THEN '✅ Avatar policies exist' 
    ELSE '❌ Avatar policies missing' 
  END as status; 