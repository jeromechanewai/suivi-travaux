-- =============================================
-- CORRECTIONS DE SÉCURITÉ - SuiviTravaux.app
-- =============================================
-- IMPORTANT: Exécutez ce script dans Supabase > SQL Editor
-- APRÈS avoir exécuté supabase-schema.sql
-- =============================================

-- =============================================
-- 1. CORRIGER LA POLICY TROP PERMISSIVE SUR CHANTIERS
-- =============================================
-- PROBLÈME: La policy actuelle permet à TOUT le monde de voir
-- TOUS les chantiers qui ont un share_token (c'est-à-dire tous)
--
-- La vraie sécurité vient de la fonction RPC get_chantier_by_token
-- qui requiert de connaître le token exact

-- Supprimer l'ancienne policy trop permissive
DROP POLICY IF EXISTS "Public can view chantier by share_token" ON chantiers;

-- Nouvelle policy: accès public uniquement via RPC (pas d'accès direct à la table)
-- Les clients utilisent la fonction get_chantier_by_token qui est SECURITY DEFINER
-- Pas de nouvelle policy SELECT publique = plus sécurisé

-- =============================================
-- 2. CORRIGER LES POLICIES STORAGE
-- =============================================
-- PROBLÈME: N'importe quel utilisateur peut supprimer les photos de n'importe qui

-- Supprimer les anciennes policies de suppression
DROP POLICY IF EXISTS "Users can delete own photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own voices" ON storage.objects;

-- Nouvelles policies avec vérification du propriétaire
-- Note: Le chemin du fichier contient le chantier_id, on vérifie que c'est bien le sien
CREATE POLICY "Users can delete own photos" ON storage.objects
FOR DELETE TO authenticated
USING (
    bucket_id = 'chantier-photos' AND
    (storage.foldername(name))[1] IN (
        SELECT id::text FROM chantiers WHERE artisan_id = auth.uid()
    )
);

CREATE POLICY "Users can delete own voices" ON storage.objects
FOR DELETE TO authenticated
USING (
    bucket_id = 'chantier-voices' AND
    (storage.foldername(name))[1] IN (
        SELECT id::text FROM chantiers WHERE artisan_id = auth.uid()
    )
);

-- =============================================
-- 3. AMÉLIORER LES POLICIES D'UPLOAD
-- =============================================
-- Vérifier que l'utilisateur uploade dans ses propres dossiers

DROP POLICY IF EXISTS "Authenticated users can upload photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload voices" ON storage.objects;

CREATE POLICY "Users can upload photos to own chantiers" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'chantier-photos' AND
    (storage.foldername(name))[1] IN (
        SELECT id::text FROM chantiers WHERE artisan_id = auth.uid()
    )
);

CREATE POLICY "Users can upload voices to own chantiers" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'chantier-voices' AND
    (storage.foldername(name))[1] IN (
        SELECT id::text FROM chantiers WHERE artisan_id = auth.uid()
    )
);

-- =============================================
-- 4. VALIDATION DES DONNÉES
-- =============================================
-- Ajouter des contraintes sur les entrées

-- Limiter la longueur des champs texte pour éviter les abus
ALTER TABLE chantiers ALTER COLUMN name TYPE VARCHAR(200);
ALTER TABLE chantiers ALTER COLUMN client_name TYPE VARCHAR(200);
ALTER TABLE chantiers ALTER COLUMN client_phone TYPE VARCHAR(30);
ALTER TABLE chantiers ALTER COLUMN last_message TYPE VARCHAR(1000);

ALTER TABLE updates ALTER COLUMN title TYPE VARCHAR(200);
ALTER TABLE updates ALTER COLUMN message TYPE VARCHAR(2000);

ALTER TABLE artisans ALTER COLUMN name TYPE VARCHAR(200);
ALTER TABLE artisans ALTER COLUMN phone TYPE VARCHAR(30);
ALTER TABLE artisans ALTER COLUMN initials TYPE VARCHAR(5);

-- =============================================
-- 5. RATE LIMITING (via Supabase Edge Functions)
-- =============================================
-- Note: Le rate limiting doit être configuré dans Supabase Dashboard
-- Settings > API > Rate Limiting
--
-- Valeurs recommandées pour un site classique:
-- - Requêtes par seconde: 10
-- - Requêtes par minute: 100
-- - Requêtes par heure: 1000

-- =============================================
-- VÉRIFICATION
-- =============================================
-- Pour vérifier que les policies sont bien appliquées:
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
-- FROM pg_policies
-- WHERE tablename IN ('chantiers', 'updates', 'photos', 'artisans');

-- Pour vérifier les policies storage:
-- SELECT * FROM storage.policies;

COMMENT ON SCHEMA public IS 'Schéma sécurisé - SuiviTravaux.app v1.1';
