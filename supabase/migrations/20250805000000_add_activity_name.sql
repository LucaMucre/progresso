-- Add activity_name field to action_logs table
-- 2025-08-05

-- Add activity_name column to action_logs table
ALTER TABLE public.action_logs 
ADD COLUMN activity_name text;

-- Add index for better performance when filtering by activity_name
CREATE INDEX idx_action_logs_activity_name ON public.action_logs(activity_name); 