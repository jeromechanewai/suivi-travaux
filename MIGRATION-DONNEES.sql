-- =============================================
-- MIGRATION DES DONNEES EXISTANTES
-- SuiviTravaux.app - Adapte a votre schema
-- =============================================
--
-- Ce script migre vos 3 chantiers existants vers le nouveau systeme
-- A executer APRES INSTALL-COMPLET.sql
-- =============================================

-- =============================================
-- ETAPE 1: Creer entreprises pour les artisans
-- =============================================

-- Recuperer les infos des artisans depuis la table artisans
INSERT INTO enterprises (id, name, trade_type, contact_name, contact_phone, created_at)
SELECT DISTINCT ON (a.id)
    gen_random_uuid(),
    COALESCE(a.name, 'Mon Entreprise'),
    'general'::trade_type,
    a.name,
    a.phone,
    NOW()
FROM artisans a
WHERE a.id IN (SELECT DISTINCT artisan_id FROM chantiers WHERE artisan_id IS NOT NULL)
AND a.enterprise_id IS NULL
ON CONFLICT DO NOTHING;

-- Lier les artisans a leurs entreprises
UPDATE artisans a
SET enterprise_id = e.id
FROM enterprises e
WHERE e.contact_name = a.name
AND a.enterprise_id IS NULL;

-- =============================================
-- ETAPE 2: Migrer chantiers vers projets
-- =============================================

INSERT INTO projects (
    id, coordinator_id, name, description, client_name, client_phone,
    share_token, status, progress, share_token_expires_at, created_at, updated_at
)
SELECT
    c.id,
    c.artisan_id,
    c.name,
    'Migre depuis ancien systeme',
    c.client_name,
    c.client_phone,
    c.share_token,
    CASE
        WHEN c.progress >= 100 THEN 'completed'
        WHEN c.progress > 0 THEN 'active'
        ELSE 'draft'
    END,
    COALESCE(c.progress, 0),
    NOW() + INTERVAL '1 year',
    c.created_at,
    COALESCE(c.updated_at, c.created_at)
FROM chantiers c
WHERE c.artisan_id IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM projects p WHERE p.id = c.id)
ON CONFLICT (id) DO NOTHING;

-- =============================================
-- ETAPE 3: Creer interventions pour chaque projet
-- =============================================

INSERT INTO interventions (
    id, project_id, enterprise_id, name, description,
    order_index, status, progress, created_at, updated_at
)
SELECT
    gen_random_uuid(),
    c.id,
    a.enterprise_id,
    c.name,
    COALESCE(c.status, c.stage),
    1,
    CASE
        WHEN c.progress >= 100 THEN 'done'
        WHEN c.progress > 0 THEN 'active'
        ELSE 'waiting'
    END::intervention_status,
    COALESCE(c.progress, 0),
    c.created_at,
    COALESCE(c.updated_at, c.created_at)
FROM chantiers c
JOIN artisans a ON a.id = c.artisan_id
WHERE c.artisan_id IS NOT NULL
AND a.enterprise_id IS NOT NULL
AND NOT EXISTS (SELECT 1 FROM interventions i WHERE i.project_id = c.id)
ON CONFLICT DO NOTHING;

-- =============================================
-- RAPPORT DE MIGRATION
-- =============================================

DO $$
DECLARE
    v_chantiers INTEGER;
    v_projects INTEGER;
    v_enterprises INTEGER;
    v_interventions INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_chantiers FROM chantiers WHERE artisan_id IS NOT NULL;
    SELECT COUNT(*) INTO v_projects FROM projects;
    SELECT COUNT(*) INTO v_enterprises FROM enterprises;
    SELECT COUNT(*) INTO v_interventions FROM interventions;

    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'RAPPORT DE MIGRATION';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Chantiers trouves: %', v_chantiers;
    RAISE NOTICE 'Projets crees: %', v_projects;
    RAISE NOTICE 'Entreprises creees: %', v_enterprises;
    RAISE NOTICE 'Interventions creees: %', v_interventions;
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Migration terminee !';
    RAISE NOTICE '';
    RAISE NOTICE 'Vos anciens liens clients continueront de fonctionner.';
    RAISE NOTICE 'Vous pouvez maintenant utiliser app-v2.html';
    RAISE NOTICE '==============================================';
END $$;
