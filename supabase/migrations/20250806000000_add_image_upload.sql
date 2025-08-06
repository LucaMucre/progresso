-- Add image upload functionality to action_logs
ALTER TABLE action_logs ADD COLUMN image_url TEXT;

-- Create storage bucket for activity images
INSERT INTO storage.buckets (id, name, public) 
VALUES ('activity-images', 'activity-images', true)
ON CONFLICT (id) DO NOTHING;

-- Create storage policy for activity images
CREATE POLICY "Users can upload activity images" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'activity-images' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can view their own activity images" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'activity-images' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can update their own activity images" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'activity-images' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete their own activity images" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'activity-images' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  ); 