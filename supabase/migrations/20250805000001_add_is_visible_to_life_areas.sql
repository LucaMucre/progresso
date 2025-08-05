-- Add is_visible field to life_areas table
-- 2025-08-05

-- Add is_visible column to life_areas table
ALTER TABLE public.life_areas 
ADD COLUMN is_visible boolean DEFAULT true;

-- Add index for better performance when filtering by is_visible
CREATE INDEX idx_life_areas_is_visible ON public.life_areas(is_visible); 