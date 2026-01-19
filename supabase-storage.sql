-- =============================================
-- CONFIGURATION STORAGE SUPABASE
-- =============================================
-- Exécutez ce script APRES avoir créé les buckets dans
-- Supabase > Storage > New Bucket
--
-- Buckets à créer :
-- 1. chantier-photos (public)
-- 2. chantier-voices (public)
-- =============================================

-- Policies pour le bucket chantier-photos
-- Permet aux utilisateurs authentifiés d'uploader
CREATE POLICY "Authenticated users can upload photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'chantier-photos');

-- Permet à tout le monde de voir les photos (pour les clients)
CREATE POLICY "Public can view photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'chantier-photos');

-- Permet aux utilisateurs authentifiés de supprimer leurs photos
CREATE POLICY "Users can delete own photos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'chantier-photos');

-- =============================================
-- Policies pour le bucket chantier-voices
-- =============================================

-- Permet aux utilisateurs authentifiés d'uploader des vocaux
CREATE POLICY "Authenticated users can upload voices"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'chantier-voices');

-- Permet à tout le monde d'écouter les vocaux (pour les clients)
CREATE POLICY "Public can listen voices"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'chantier-voices');

-- Permet aux utilisateurs authentifiés de supprimer leurs vocaux
CREATE POLICY "Users can delete own voices"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'chantier-voices');
