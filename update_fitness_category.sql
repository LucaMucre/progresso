-- Update Fitness life area category from Health to Vitality
UPDATE public.life_areas 
SET category = 'Vitality', 
    updated_at = NOW()
WHERE name = 'Fitness' 
  AND category = 'Health'
  AND user_id = '0b793054-6c2e-4647-b409-9912a0ba23c1';

-- Verify the update
SELECT id, name, category, color, updated_at 
FROM public.life_areas 
WHERE user_id = '0b793054-6c2e-4647-b409-9912a0ba23c1'
ORDER BY name;