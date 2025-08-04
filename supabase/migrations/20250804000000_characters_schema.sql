-- Characters Schema für Progresso App
-- 2025-08-04

-- Characters Tabelle erstellen
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

-- Unique constraint für user_id (ein Character pro User)
CREATE UNIQUE INDEX IF NOT EXISTS characters_user_id_idx ON public.characters(user_id);

-- RLS für characters aktivieren
ALTER TABLE public.characters ENABLE ROW LEVEL SECURITY;

-- Policy: Users können nur ihren eigenen Character sehen/bearbeiten
CREATE POLICY "Users can only access their own character"
ON public.characters
FOR ALL
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Trigger für updated_at
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

-- Funktion für automatische Character-Erstellung
CREATE OR REPLACE FUNCTION public.handle_new_user_character()
RETURNS trigger AS $$
BEGIN
    INSERT INTO public.characters (user_id, name)
    VALUES (new.id, COALESCE(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)));
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger für automatische Character-Erstellung
CREATE OR REPLACE TRIGGER on_auth_user_created_character
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user_character(); 