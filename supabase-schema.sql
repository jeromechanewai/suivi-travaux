-- =============================================
-- SCHEMA SUPABASE POUR SUIVITRAVAUX.APP
-- =============================================

-- Table des artisans (utilisateurs)
CREATE TABLE artisans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    initials TEXT,
    phone TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des chantiers
CREATE TABLE chantiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    artisan_id UUID REFERENCES artisans(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    client_name TEXT NOT NULL,
    client_phone TEXT,
    progress INTEGER DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
    stage TEXT DEFAULT 'preparation' CHECK (stage IN ('preparation', 'en_cours', 'finitions', 'livre')),
    status TEXT DEFAULT 'Préparation',
    estimated_end DATE,
    last_message TEXT,
    client_viewed BOOLEAN DEFAULT FALSE,
    client_viewed_at TIMESTAMP WITH TIME ZONE,
    client_feedback INTEGER CHECK (client_feedback >= 1 AND client_feedback <= 4),
    share_token TEXT UNIQUE DEFAULT encode(gen_random_bytes(8), 'hex'),
    archived BOOLEAN DEFAULT FALSE,
    archived_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table de l'historique des mises à jour
CREATE TABLE updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chantier_id UUID REFERENCES chantiers(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT,
    progress INTEGER,
    stage TEXT,
    photo_url TEXT,
    voice_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des photos
CREATE TABLE photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chantier_id UUID REFERENCES chantiers(id) ON DELETE CASCADE,
    update_id UUID REFERENCES updates(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- INDEX POUR PERFORMANCE
-- =============================================
CREATE INDEX idx_chantiers_artisan ON chantiers(artisan_id);
CREATE INDEX idx_chantiers_share_token ON chantiers(share_token);
CREATE INDEX idx_updates_chantier ON updates(chantier_id);
CREATE INDEX idx_photos_chantier ON photos(chantier_id);

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================

-- Activer RLS sur toutes les tables
ALTER TABLE artisans ENABLE ROW LEVEL SECURITY;
ALTER TABLE chantiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE photos ENABLE ROW LEVEL SECURITY;

-- Policies pour artisans (un artisan gère son profil)
CREATE POLICY "Artisans can view own profile" ON artisans
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Artisans can insert own profile" ON artisans
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Artisans can update own profile" ON artisans
    FOR UPDATE USING (auth.uid() = id);

-- Policies pour chantiers
CREATE POLICY "Artisans can view own chantiers" ON chantiers
    FOR SELECT USING (artisan_id = auth.uid());

CREATE POLICY "Artisans can insert own chantiers" ON chantiers
    FOR INSERT WITH CHECK (artisan_id = auth.uid());

CREATE POLICY "Artisans can update own chantiers" ON chantiers
    FOR UPDATE USING (artisan_id = auth.uid());

CREATE POLICY "Artisans can delete own chantiers" ON chantiers
    FOR DELETE USING (artisan_id = auth.uid());

-- Policy publique pour les clients (via share_token)
CREATE POLICY "Public can view chantier by share_token" ON chantiers
    FOR SELECT USING (share_token IS NOT NULL);

-- Policies pour updates
CREATE POLICY "Artisans can manage updates for own chantiers" ON updates
    FOR ALL USING (
        chantier_id IN (SELECT id FROM chantiers WHERE artisan_id = auth.uid())
    );

CREATE POLICY "Public can view updates by share_token" ON updates
    FOR SELECT USING (
        chantier_id IN (SELECT id FROM chantiers WHERE share_token IS NOT NULL)
    );

-- Policies pour photos
CREATE POLICY "Artisans can manage photos for own chantiers" ON photos
    FOR ALL USING (
        chantier_id IN (SELECT id FROM chantiers WHERE artisan_id = auth.uid())
    );

CREATE POLICY "Public can view photos by share_token" ON photos
    FOR SELECT USING (
        chantier_id IN (SELECT id FROM chantiers WHERE share_token IS NOT NULL)
    );

-- =============================================
-- FUNCTIONS
-- =============================================

-- Fonction pour mettre à jour le timestamp updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers pour updated_at
CREATE TRIGGER trigger_artisans_updated_at
    BEFORE UPDATE ON artisans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_chantiers_updated_at
    BEFORE UPDATE ON chantiers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Fonction pour obtenir un chantier par share_token (pour les clients)
CREATE OR REPLACE FUNCTION get_chantier_by_token(token TEXT)
RETURNS TABLE (
    id UUID,
    name TEXT,
    client_name TEXT,
    progress INTEGER,
    stage TEXT,
    status TEXT,
    estimated_end DATE,
    last_message TEXT,
    artisan_name TEXT,
    artisan_phone TEXT,
    client_feedback INTEGER,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- Marquer comme vu par le client
    UPDATE chantiers SET
        client_viewed = TRUE,
        client_viewed_at = NOW()
    WHERE share_token = token;

    -- Retourner les infos du chantier
    RETURN QUERY
    SELECT
        c.id,
        c.name,
        c.client_name,
        c.progress,
        c.stage,
        c.status,
        c.estimated_end,
        c.last_message,
        a.name AS artisan_name,
        a.phone AS artisan_phone,
        c.client_feedback,
        c.updated_at
    FROM chantiers c
    JOIN artisans a ON c.artisan_id = a.id
    WHERE c.share_token = token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour soumettre le feedback client
CREATE OR REPLACE FUNCTION submit_client_feedback(token TEXT, feedback INTEGER)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE chantiers
    SET client_feedback = feedback
    WHERE share_token = token AND progress = 100;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
