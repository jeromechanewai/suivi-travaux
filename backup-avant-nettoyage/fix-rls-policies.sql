-- =============================================
-- CORRECTION DES POLICIES RLS POUR ARTISANS
-- =============================================
-- Exécutez ce script dans Supabase > SQL Editor > New Query
-- Puis cliquez sur "Run"

-- Supprimer les anciennes policies de la table artisans
DROP POLICY IF EXISTS "Artisans can view own profile" ON artisans;
DROP POLICY IF EXISTS "Artisans can update own profile" ON artisans;
DROP POLICY IF EXISTS "Artisans can insert own profile" ON artisans;
DROP POLICY IF EXISTS "Users can insert own profile" ON artisans;

-- Recréer les policies correctement
-- 1. Permettre à un utilisateur de voir son propre profil
CREATE POLICY "Artisans can view own profile" ON artisans
    FOR SELECT USING (auth.uid() = id);

-- 2. Permettre à un utilisateur de CRÉER son propre profil (MANQUAIT!)
CREATE POLICY "Artisans can insert own profile" ON artisans
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 3. Permettre à un utilisateur de modifier son propre profil
CREATE POLICY "Artisans can update own profile" ON artisans
    FOR UPDATE USING (auth.uid() = id);

-- Vérification : afficher les policies actives
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'artisans';
