-- Life Areas Schema für Progresso App
-- 2025-08-04

-- Life Areas Tabelle erstellen
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

-- Index für user_id und order_index
CREATE INDEX IF NOT EXISTS life_areas_user_id_idx ON public.life_areas(user_id);
CREATE INDEX IF NOT EXISTS life_areas_order_idx ON public.life_areas(order_index);

-- RLS für life_areas aktivieren
ALTER TABLE public.life_areas ENABLE ROW LEVEL SECURITY;

-- Policy: Users können nur ihre eigenen Life Areas sehen/bearbeiten
CREATE POLICY "Users can only access their own life areas"
ON public.life_areas
FOR ALL
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Trigger für updated_at
CREATE OR REPLACE FUNCTION update_life_areas_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER life_areas_updated_at
    BEFORE UPDATE ON public.life_areas
    FOR EACH ROW
    EXECUTE FUNCTION update_life_areas_updated_at(); 