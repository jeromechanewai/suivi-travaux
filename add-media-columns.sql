-- =============================================
-- AJOUTER LES COLONNES MEDIA AUX UPDATES
-- Exécutez ce script dans Supabase > SQL Editor
-- =============================================

-- Ajouter les colonnes pour photos et vocaux
ALTER TABLE updates ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE updates ADD COLUMN IF NOT EXISTS voice_url TEXT;

-- Créer le bucket pour les vocaux (si pas déjà fait)
-- Note: Ceci doit être fait via l'interface Supabase Storage
-- Allez dans Storage > New Bucket > Nom: "chantier-voices" > Public: Oui
