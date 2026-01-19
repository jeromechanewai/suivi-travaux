-- =============================================
-- INSTALLATION COMPLETE - SuiviTravaux.app
-- Version: Multi-Equipes Light 2.0
-- =============================================
--
-- INSTRUCTIONS:
-- 1. Allez sur Supabase Dashboard > SQL Editor
-- 2. Ctrl+A pour tout selectionner ce fichier
-- 3. Ctrl+C pour copier
-- 4. Ctrl+V dans Supabase SQL Editor
-- 5. Cliquez sur "Run"
--
-- Ce script gere automatiquement:
-- - Creation des tables si elles n'existent pas
-- - Ajout des colonnes manquantes
-- - Pas d'erreur si deja execute
-- =============================================

-- =============================================
-- PARTIE 1: TYPES ENUMERES
-- =============================================

DO $$
BEGIN
    -- Type trade_type
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'trade_type') THEN
        CREATE TYPE trade_type AS ENUM (
            'maconnerie', 'electricite', 'plomberie', 'chauffage',
            'carrelage', 'peinture', 'menuiserie', 'charpente',
            'couverture', 'isolation', 'platrerie', 'cuisine',
            'salle_de_bain', 'general', 'autre'
        );
    END IF;

    -- Type intervention_status
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'intervention_status') THEN
        CREATE TYPE intervention_status AS ENUM ('waiting', 'active', 'done');
    END IF;

    -- Type user_role
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('solo', 'coordinator', 'team', 'viewer');
    END IF;
END $$;

-- =============================================
-- PARTIE 2: TABLE ENTERPRISES
-- =============================================

CREATE TABLE IF NOT EXISTS enterprises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    trade_type trade_type DEFAULT 'general',
    contact_name TEXT,
    contact_phone TEXT,
    contact_email TEXT,
    logo_url TEXT,
    color TEXT DEFAULT '#3b82f6',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_enterprises_name ON enterprises(name);
CREATE INDEX IF NOT EXISTS idx_enterprises_trade ON enterprises(trade_type);

-- =============================================
-- PARTIE 3: EXTENSION TABLE ARTISANS
-- =============================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'artisans' AND column_name = 'enterprise_id') THEN
        ALTER TABLE artisans ADD COLUMN enterprise_id UUID REFERENCES enterprises(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'artisans' AND column_name = 'role') THEN
        ALTER TABLE artisans ADD COLUMN role user_role DEFAULT 'solo';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'artisans' AND column_name = 'avatar_url') THEN
        ALTER TABLE artisans ADD COLUMN avatar_url TEXT;
    END IF;
END $$;

-- =============================================
-- PARTIE 4: TABLE PROJECTS
-- =============================================

CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    address TEXT,
    client_name TEXT NOT NULL,
    client_phone TEXT,
    client_email TEXT,
    coordinator_id UUID REFERENCES artisans(id) NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('draft', 'active', 'completed', 'archived')),
    progress INTEGER DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
    start_date DATE,
    estimated_end DATE,
    share_token TEXT UNIQUE DEFAULT encode(gen_random_bytes(12), 'hex'),
    share_token_expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '1 year'),
    client_viewed BOOLEAN DEFAULT FALSE,
    client_viewed_at TIMESTAMP WITH TIME ZONE,
    client_view_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_projects_coordinator ON projects(coordinator_id);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_share_token ON projects(share_token);

-- =============================================
-- PARTIE 5: TABLE INTERVENTIONS
-- =============================================

CREATE TABLE IF NOT EXISTS interventions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
    enterprise_id UUID REFERENCES enterprises(id),
    name TEXT NOT NULL,
    description TEXT,
    order_index INTEGER NOT NULL DEFAULT 1,
    status intervention_status DEFAULT 'waiting',
    progress INTEGER DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
    last_message TEXT,
    last_update_at TIMESTAMP WITH TIME ZONE,
    estimated_start DATE,
    estimated_end DATE,
    actual_start TIMESTAMP WITH TIME ZONE,
    actual_end TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ajouter contrainte unique si elle n'existe pas
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'interventions_project_id_order_index_key'
    ) THEN
        ALTER TABLE interventions ADD CONSTRAINT interventions_project_id_order_index_key
        UNIQUE (project_id, order_index);
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL; -- Ignorer si deja existe
END $$;

CREATE INDEX IF NOT EXISTS idx_interventions_project ON interventions(project_id);
CREATE INDEX IF NOT EXISTS idx_interventions_enterprise ON interventions(enterprise_id);
CREATE INDEX IF NOT EXISTS idx_interventions_status ON interventions(status);
CREATE INDEX IF NOT EXISTS idx_interventions_order ON interventions(project_id, order_index);

-- =============================================
-- PARTIE 6: TABLE INTERVENTION_UPDATES
-- =============================================

CREATE TABLE IF NOT EXISTS intervention_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    intervention_id UUID REFERENCES interventions(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES artisans(id),
    title TEXT,
    message TEXT,
    progress INTEGER CHECK (progress >= 0 AND progress <= 100),
    photo_url TEXT,
    photo_urls TEXT[] DEFAULT '{}',
    voice_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_intervention_updates_intervention ON intervention_updates(intervention_id);
CREATE INDEX IF NOT EXISTS idx_intervention_updates_date ON intervention_updates(created_at DESC);

-- =============================================
-- PARTIE 7: TABLE INVITATIONS
-- =============================================

CREATE TABLE IF NOT EXISTS project_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
    intervention_id UUID REFERENCES interventions(id) ON DELETE CASCADE,
    invite_email TEXT,
    invite_phone TEXT,
    enterprise_id UUID REFERENCES enterprises(id),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
    invite_token TEXT UNIQUE DEFAULT encode(gen_random_bytes(16), 'hex'),
    invited_by UUID REFERENCES artisans(id),
    invited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    responded_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_invitations_token ON project_invitations(invite_token);
CREATE INDEX IF NOT EXISTS idx_invitations_project ON project_invitations(project_id);

-- =============================================
-- PARTIE 8: TABLE NOTIFICATIONS
-- =============================================

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES artisans(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('turn', 'update', 'done', 'invite', 'reminder')),
    title TEXT NOT NULL,
    message TEXT,
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    intervention_id UUID REFERENCES interventions(id) ON DELETE CASCADE,
    read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_date ON notifications(created_at DESC);

-- Index partiel pour non lus (ignore erreur si existe)
DO $$
BEGIN
    CREATE INDEX idx_notifications_unread ON notifications(user_id, read) WHERE NOT read;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- =============================================
-- PARTIE 9: TABLE TEMPLATES
-- =============================================

CREATE TABLE IF NOT EXISTS project_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    interventions JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Inserer templates (ignore si existent)
INSERT INTO project_templates (name, description, interventions) VALUES
('Renovation Cuisine', 'Template pour renovation complete de cuisine',
 '[{"name": "Demolition / Preparation", "order": 1},{"name": "Maconnerie", "order": 2},{"name": "Plomberie", "order": 3},{"name": "Electricite", "order": 4},{"name": "Carrelage", "order": 5},{"name": "Menuiserie / Pose cuisine", "order": 6},{"name": "Peinture", "order": 7},{"name": "Finitions", "order": 8}]'::JSONB),
('Salle de Bain', 'Template pour renovation salle de bain',
 '[{"name": "Demolition", "order": 1},{"name": "Plomberie", "order": 2},{"name": "Electricite", "order": 3},{"name": "Etancheite", "order": 4},{"name": "Carrelage", "order": 5},{"name": "Pose sanitaires", "order": 6},{"name": "Peinture", "order": 7}]'::JSONB),
('Extension Maison', 'Template pour extension de maison',
 '[{"name": "Terrassement / Fondations", "order": 1},{"name": "Maconnerie / Gros oeuvre", "order": 2},{"name": "Charpente / Couverture", "order": 3},{"name": "Menuiseries exterieures", "order": 4},{"name": "Electricite", "order": 5},{"name": "Plomberie", "order": 6},{"name": "Isolation / Placo", "order": 7},{"name": "Carrelage / Sols", "order": 8},{"name": "Peinture", "order": 9},{"name": "Finitions", "order": 10}]'::JSONB),
('Projet Simple', 'Template minimaliste',
 '[{"name": "Preparation", "order": 1},{"name": "Travaux", "order": 2},{"name": "Finitions", "order": 3}]'::JSONB)
ON CONFLICT DO NOTHING;

-- =============================================
-- PARTIE 10: FONCTIONS UTILITAIRES
-- =============================================

-- Calculer progression projet
CREATE OR REPLACE FUNCTION calculate_project_progress(p_project_id UUID)
RETURNS INTEGER AS $$
DECLARE
    total_interventions INTEGER;
    total_progress INTEGER;
BEGIN
    SELECT COUNT(*), COALESCE(SUM(progress), 0)
    INTO total_interventions, total_progress
    FROM interventions WHERE project_id = p_project_id;

    IF total_interventions = 0 THEN RETURN 0; END IF;
    RETURN ROUND(total_progress::DECIMAL / total_interventions);
END;
$$ LANGUAGE plpgsql;

-- Statut affichage intervention
CREATE OR REPLACE FUNCTION get_intervention_display_status(p_intervention_id UUID)
RETURNS TABLE (
    status_code TEXT,
    status_text TEXT,
    status_emoji TEXT,
    can_update BOOLEAN,
    previous_info TEXT
) AS $$
DECLARE
    v_intervention interventions%ROWTYPE;
    v_project_id UUID;
    v_order_index INTEGER;
    v_previous_not_done INTEGER;
    v_previous_name TEXT;
    v_previous_progress INTEGER;
BEGIN
    SELECT * INTO v_intervention FROM interventions WHERE id = p_intervention_id;
    IF NOT FOUND THEN
        RETURN QUERY SELECT 'error'::TEXT, 'Intervention non trouvee'::TEXT, '?'::TEXT, FALSE, NULL::TEXT;
        RETURN;
    END IF;

    v_project_id := v_intervention.project_id;
    v_order_index := v_intervention.order_index;

    IF v_intervention.status = 'done' THEN
        RETURN QUERY SELECT 'done'::TEXT, 'Termine'::TEXT, '?'::TEXT, TRUE, NULL::TEXT;
        RETURN;
    END IF;

    IF v_intervention.progress > 0 THEN
        RETURN QUERY SELECT 'active'::TEXT, 'En cours'::TEXT, '?'::TEXT, TRUE, NULL::TEXT;
        RETURN;
    END IF;

    SELECT COUNT(*),
           (SELECT name FROM interventions WHERE project_id = v_project_id AND order_index < v_order_index AND status != 'done' ORDER BY order_index LIMIT 1),
           (SELECT progress FROM interventions WHERE project_id = v_project_id AND order_index < v_order_index AND status != 'done' ORDER BY order_index LIMIT 1)
    INTO v_previous_not_done, v_previous_name, v_previous_progress
    FROM interventions WHERE project_id = v_project_id AND order_index < v_order_index AND status != 'done';

    IF v_previous_not_done = 0 OR v_order_index = 1 THEN
        RETURN QUERY SELECT 'ready'::TEXT, 'C''est votre tour'::TEXT, '?'::TEXT, TRUE, NULL::TEXT;
        RETURN;
    END IF;

    RETURN QUERY SELECT 'waiting'::TEXT, 'En attente'::TEXT, '?'::TEXT, TRUE,
        format('%s en cours (%s%%)', v_previous_name, COALESCE(v_previous_progress, 0))::TEXT;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- PARTIE 11: FONCTIONS API PUBLIQUES
-- =============================================

-- Projet par token
CREATE OR REPLACE FUNCTION get_project_by_token(p_token TEXT)
RETURNS TABLE (
    id UUID, name TEXT, client_name TEXT, coordinator_name TEXT, coordinator_phone TEXT,
    progress INTEGER, status TEXT, total_steps INTEGER, completed_steps INTEGER, estimated_end DATE
) AS $$
BEGIN
    UPDATE projects SET client_viewed = true, client_viewed_at = NOW() WHERE share_token = p_token;

    RETURN QUERY
    SELECT p.id, p.name, p.client_name, a.name, a.phone, p.progress, p.status,
           COUNT(i.id)::INTEGER, COUNT(CASE WHEN i.status = 'done' THEN 1 END)::INTEGER, p.estimated_end
    FROM projects p
    LEFT JOIN artisans a ON p.coordinator_id = a.id
    LEFT JOIN interventions i ON p.id = i.project_id
    WHERE p.share_token = p_token
    GROUP BY p.id, a.name, a.phone;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Interventions par token
CREATE OR REPLACE FUNCTION get_interventions_by_token(p_token TEXT)
RETURNS TABLE (
    id UUID, name TEXT, order_index INTEGER, status intervention_status,
    progress INTEGER, enterprise_name TEXT, last_message TEXT,
    last_update_at TIMESTAMP WITH TIME ZONE, status_emoji TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT i.id, i.name, i.order_index, i.status, i.progress, e.name, i.last_message, i.last_update_at,
           CASE WHEN i.status = 'done' THEN '?' WHEN i.progress > 0 THEN '?' ELSE '?' END
    FROM interventions i
    LEFT JOIN enterprises e ON i.enterprise_id = e.id
    WHERE i.project_id = (SELECT id FROM projects WHERE share_token = p_token)
    ORDER BY i.order_index;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Updates par token
CREATE OR REPLACE FUNCTION get_project_updates_by_token(p_token TEXT, p_limit INTEGER DEFAULT 10)
RETURNS TABLE (
    id UUID, intervention_name TEXT, message TEXT, new_progress INTEGER,
    photo_url TEXT, created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT iu.id, i.name, iu.message, iu.progress, iu.photo_url, iu.created_at
    FROM intervention_updates iu
    JOIN interventions i ON iu.intervention_id = i.id
    WHERE i.project_id = (SELECT id FROM projects WHERE share_token = p_token)
    ORDER BY iu.created_at DESC LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Projet complet par token (optimise)
CREATE OR REPLACE FUNCTION get_full_project_by_token(p_token TEXT)
RETURNS JSON AS $$
DECLARE
    v_project RECORD;
    v_interventions JSON;
    v_result JSON;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM projects
        WHERE share_token = p_token
        AND (share_token_expires_at IS NULL OR share_token_expires_at > NOW())
    ) THEN
        RETURN NULL;
    END IF;

    UPDATE projects SET client_viewed = true, client_viewed_at = NOW(),
        client_view_count = COALESCE(client_view_count, 0) + 1
    WHERE share_token = p_token;

    SELECT p.id, p.name, p.client_name, p.progress, p.status, p.estimated_end,
           a.name as coordinator_name, a.phone as coordinator_phone
    INTO v_project
    FROM projects p LEFT JOIN artisans a ON p.coordinator_id = a.id
    WHERE p.share_token = p_token;

    IF NOT FOUND THEN RETURN NULL; END IF;

    SELECT json_agg(json_build_object(
        'id', i.id, 'name', i.name, 'order_index', i.order_index,
        'status', i.status, 'progress', i.progress, 'enterprise_name', e.name,
        'last_message', i.last_message, 'last_update_at', i.last_update_at
    ) ORDER BY i.order_index) INTO v_interventions
    FROM interventions i LEFT JOIN enterprises e ON i.enterprise_id = e.id
    WHERE i.project_id = v_project.id;

    v_result := json_build_object(
        'project', json_build_object(
            'id', v_project.id, 'name', v_project.name, 'client_name', v_project.client_name,
            'progress', v_project.progress, 'status', v_project.status,
            'estimated_end', v_project.estimated_end, 'coordinator_name', v_project.coordinator_name,
            'coordinator_phone', v_project.coordinator_phone
        ),
        'interventions', COALESCE(v_interventions, '[]'::JSON)
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- PARTIE 12: TRIGGERS
-- =============================================

-- Drop triggers existants pour eviter erreurs
DROP TRIGGER IF EXISTS trigger_update_project_progress ON interventions;
DROP TRIGGER IF EXISTS trigger_update_intervention ON intervention_updates;
DROP TRIGGER IF EXISTS trigger_notify_next_team ON interventions;
DROP TRIGGER IF EXISTS trigger_notify_coordinator_done ON interventions;

-- Trigger: Maj progression projet
CREATE OR REPLACE FUNCTION update_project_progress()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE projects SET progress = calculate_project_progress(NEW.project_id), updated_at = NOW()
    WHERE id = NEW.project_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_project_progress
AFTER INSERT OR UPDATE ON interventions
FOR EACH ROW EXECUTE FUNCTION update_project_progress();

-- Trigger: Maj intervention sur update
CREATE OR REPLACE FUNCTION update_intervention_on_update()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE interventions SET
        progress = COALESCE(NEW.progress, progress),
        last_message = COALESCE(NEW.message, NEW.title, last_message),
        last_update_at = NOW(),
        status = CASE
            WHEN NEW.progress >= 100 THEN 'done'::intervention_status
            WHEN NEW.progress > 0 THEN 'active'::intervention_status
            ELSE status
        END,
        actual_start = CASE WHEN actual_start IS NULL AND NEW.progress > 0 THEN NOW() ELSE actual_start END,
        actual_end = CASE WHEN NEW.progress >= 100 THEN NOW() ELSE actual_end END,
        updated_at = NOW()
    WHERE id = NEW.intervention_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_intervention
AFTER INSERT ON intervention_updates
FOR EACH ROW EXECUTE FUNCTION update_intervention_on_update();

-- Trigger: Notifier equipe suivante
CREATE OR REPLACE FUNCTION notify_next_team()
RETURNS TRIGGER AS $$
DECLARE
    v_next_intervention interventions%ROWTYPE;
    v_next_user_id UUID;
    v_project_name TEXT;
BEGIN
    IF NEW.status = 'done' AND (OLD.status IS NULL OR OLD.status != 'done') THEN
        BEGIN
            SELECT * INTO v_next_intervention FROM interventions
            WHERE project_id = NEW.project_id AND order_index > NEW.order_index AND status != 'done'
            ORDER BY order_index LIMIT 1;

            IF FOUND AND v_next_intervention.enterprise_id IS NOT NULL THEN
                SELECT id INTO v_next_user_id FROM artisans
                WHERE enterprise_id = v_next_intervention.enterprise_id LIMIT 1;

                SELECT name INTO v_project_name FROM projects WHERE id = NEW.project_id;

                IF v_next_user_id IS NOT NULL THEN
                    INSERT INTO notifications (user_id, type, title, message, project_id, intervention_id)
                    VALUES (v_next_user_id, 'turn', 'C''est votre tour !',
                        format('%s sur %s - L''equipe precedente a termine', v_next_intervention.name, v_project_name),
                        NEW.project_id, v_next_intervention.id);
                END IF;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'notify_next_team failed: %', SQLERRM;
        END;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_next_team
AFTER UPDATE ON interventions
FOR EACH ROW EXECUTE FUNCTION notify_next_team();

-- Trigger: Notifier coordinateur
CREATE OR REPLACE FUNCTION notify_coordinator_done()
RETURNS TRIGGER AS $$
DECLARE
    v_coordinator_id UUID;
    v_project_name TEXT;
    v_enterprise_name TEXT;
BEGIN
    IF NEW.status = 'done' AND (OLD.status IS NULL OR OLD.status != 'done') THEN
        SELECT p.coordinator_id, p.name INTO v_coordinator_id, v_project_name
        FROM projects p WHERE p.id = NEW.project_id;

        SELECT name INTO v_enterprise_name FROM enterprises WHERE id = NEW.enterprise_id;

        INSERT INTO notifications (user_id, type, title, message, project_id, intervention_id)
        VALUES (v_coordinator_id, 'done', format('%s termine !', NEW.name),
            format('%s a termine son intervention sur %s', COALESCE(v_enterprise_name, 'L''equipe'), v_project_name),
            NEW.project_id, NEW.id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notify_coordinator_done
AFTER UPDATE ON interventions
FOR EACH ROW EXECUTE FUNCTION notify_coordinator_done();

-- =============================================
-- PARTIE 13: POLITIQUES RLS
-- =============================================

-- Activer RLS
ALTER TABLE enterprises ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE interventions ENABLE ROW LEVEL SECURITY;
ALTER TABLE intervention_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Supprimer policies existantes pour eviter erreurs
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname, tablename FROM pg_policies
              WHERE tablename IN ('enterprises', 'projects', 'interventions',
                                  'intervention_updates', 'project_invitations', 'notifications'))
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.policyname, r.tablename);
    END LOOP;
END $$;

-- Policies enterprises
CREATE POLICY "enterprises_select" ON enterprises FOR SELECT TO authenticated USING (true);
CREATE POLICY "enterprises_all" ON enterprises FOR ALL TO authenticated
USING (id IN (SELECT enterprise_id FROM artisans WHERE id = auth.uid()));

-- Policies projects
CREATE POLICY "projects_select" ON projects FOR SELECT TO authenticated
USING (coordinator_id = auth.uid() OR id IN (
    SELECT project_id FROM interventions WHERE enterprise_id IN (
        SELECT enterprise_id FROM artisans WHERE id = auth.uid()
    )
));
CREATE POLICY "projects_all" ON projects FOR ALL TO authenticated USING (coordinator_id = auth.uid());

-- Policies interventions
CREATE POLICY "interventions_select" ON interventions FOR SELECT TO authenticated
USING (project_id IN (SELECT id FROM projects WHERE coordinator_id = auth.uid())
    OR enterprise_id IN (SELECT enterprise_id FROM artisans WHERE id = auth.uid()));
CREATE POLICY "interventions_update" ON interventions FOR UPDATE TO authenticated
USING (enterprise_id IN (SELECT enterprise_id FROM artisans WHERE id = auth.uid()));
CREATE POLICY "interventions_all" ON interventions FOR ALL TO authenticated
USING (project_id IN (SELECT id FROM projects WHERE coordinator_id = auth.uid()));

-- Policies intervention_updates
CREATE POLICY "updates_select" ON intervention_updates FOR SELECT TO authenticated
USING (intervention_id IN (
    SELECT id FROM interventions WHERE project_id IN (SELECT id FROM projects WHERE coordinator_id = auth.uid())
) OR intervention_id IN (
    SELECT id FROM interventions WHERE enterprise_id IN (SELECT enterprise_id FROM artisans WHERE id = auth.uid())
));
CREATE POLICY "updates_insert" ON intervention_updates FOR INSERT TO authenticated
WITH CHECK (intervention_id IN (
    SELECT id FROM interventions WHERE enterprise_id IN (SELECT enterprise_id FROM artisans WHERE id = auth.uid())
) OR intervention_id IN (
    SELECT id FROM interventions WHERE project_id IN (SELECT id FROM projects WHERE coordinator_id = auth.uid())
));

-- Policies notifications
CREATE POLICY "notifications_select" ON notifications FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "notifications_update" ON notifications FOR UPDATE TO authenticated USING (user_id = auth.uid());

-- =============================================
-- PARTIE 14: VUES
-- =============================================

DROP VIEW IF EXISTS v_projects_with_progress;
CREATE VIEW v_projects_with_progress AS
SELECT p.*, a.name as coordinator_name, a.phone as coordinator_phone,
       COUNT(i.id) as total_interventions,
       COUNT(CASE WHEN i.status = 'done' THEN 1 END) as completed_interventions,
       calculate_project_progress(p.id) as calculated_progress
FROM projects p
LEFT JOIN artisans a ON p.coordinator_id = a.id
LEFT JOIN interventions i ON p.id = i.project_id
GROUP BY p.id, a.name, a.phone;

DROP VIEW IF EXISTS v_interventions_display;
CREATE VIEW v_interventions_display AS
SELECT i.*, e.name as enterprise_name, e.contact_phone as enterprise_phone,
       e.color as enterprise_color, e.trade_type, p.name as project_name, p.client_name,
       ds.status_code, ds.status_text, ds.status_emoji, ds.can_update, ds.previous_info
FROM interventions i
LEFT JOIN enterprises e ON i.enterprise_id = e.id
LEFT JOIN projects p ON i.project_id = p.id
LEFT JOIN LATERAL get_intervention_display_status(i.id) ds ON true;

-- =============================================
-- FIN - MESSAGE DE CONFIRMATION
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'INSTALLATION TERMINEE AVEC SUCCES !';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Tables creees: enterprises, projects, interventions,';
    RAISE NOTICE '               intervention_updates, project_invitations,';
    RAISE NOTICE '               notifications, project_templates';
    RAISE NOTICE '';
    RAISE NOTICE 'Fonctions API: get_project_by_token, get_interventions_by_token,';
    RAISE NOTICE '               get_full_project_by_token, get_project_updates_by_token';
    RAISE NOTICE '';
    RAISE NOTICE 'Triggers: progression auto, notifications auto';
    RAISE NOTICE 'RLS: Active sur toutes les tables';
    RAISE NOTICE '==============================================';
END $$;
