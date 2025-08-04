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

-- 8. Trigger für characters updated_at
CREATE OR REPLACE FUNCTION update_characters_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER characters_updated_at
    BEFORE UPDATE ON public.characters
    FOR EACH ROW
    EXECUTE FUNCTION update_characters_updated_at();

-- 9. Trigger für life_areas updated_at
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

-- 10. Funktion für automatische Character-Erstellung
CREATE OR REPLACE FUNCTION public.handle_new_user_character()
RETURNS trigger AS $$
BEGIN
    INSERT INTO public.characters (user_id, name)
    VALUES (new.id, COALESCE(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)));
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. Trigger für automatische Character-Erstellung
CREATE OR REPLACE TRIGGER on_auth_user_created_character
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user_character();

-- 12. Bestätigung
SELECT 'Database Setup erfolgreich angewendet!' as status; 