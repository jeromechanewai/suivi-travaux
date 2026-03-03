-- =============================================
-- FONCTIONS RPC POUR equipe.html
-- À exécuter dans Supabase SQL Editor
-- =============================================

-- 1. LECTURE : Récupérer un chantier par token d'équipe
-- Retourne les infos du chantier + l'équipe correspondante + les autres équipes (sans leurs tokens)
CREATE OR REPLACE FUNCTION get_chantier_by_equipe_token(p_token TEXT)
RETURNS JSONB AS $$
DECLARE
    chantier_row RECORD;
    equipe_elem JSONB;
    other_equipes JSONB;
    coordinator_phone TEXT;
    i INT;
BEGIN
    -- Chercher dans tous les chantiers actifs
    FOR chantier_row IN
        SELECT c.id, c.name, c.client_name, c.equipes, c.progress, c.stage, c.artisan_id
        FROM chantiers c
        WHERE c.equipes IS NOT NULL
          AND jsonb_array_length(c.equipes) > 0
          AND c.archived = false
    LOOP
        -- Parcourir chaque équipe du chantier
        FOR i IN 0..jsonb_array_length(chantier_row.equipes) - 1
        LOOP
            equipe_elem := chantier_row.equipes->i;

            IF equipe_elem->>'token' = p_token THEN
                -- Récupérer le téléphone du coordinateur
                SELECT a.phone INTO coordinator_phone
                FROM artisans a
                WHERE a.id = chantier_row.artisan_id;

                -- Construire la liste des autres équipes (SANS leurs tokens)
                SELECT COALESCE(jsonb_agg(
                    jsonb_build_object(
                        'id', eq->>'id',
                        'name', eq->>'name',
                        'stage', COALESCE(eq->>'stage', 'preparation'),
                        'color', COALESCE(eq->>'color', '#94a3b8')
                    )
                ), '[]'::jsonb)
                INTO other_equipes
                FROM jsonb_array_elements(chantier_row.equipes) eq
                WHERE eq->>'token' != p_token;

                -- Retourner le résultat complet
                RETURN jsonb_build_object(
                    'chantier', jsonb_build_object(
                        'id', chantier_row.id,
                        'name', chantier_row.name,
                        'client', chantier_row.client_name,
                        'progress', chantier_row.progress,
                        'stage', chantier_row.stage
                    ),
                    'equipe', jsonb_build_object(
                        'id', equipe_elem->>'id',
                        'token', equipe_elem->>'token',
                        'name', equipe_elem->>'name',
                        'entreprise', equipe_elem->>'entreprise',
                        'color', COALESCE(equipe_elem->>'color', '#3b82f6'),
                        'stage', COALESCE(equipe_elem->>'stage', 'preparation'),
                        'phone', equipe_elem->>'phone',
                        'history', COALESCE(equipe_elem->'history', '[]'::jsonb)
                    ),
                    'otherEquipes', other_equipes,
                    'coordinatorPhone', coordinator_phone
                );
            END IF;
        END LOOP;
    END LOOP;

    -- Token non trouvé
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. ÉCRITURE : Mettre à jour l'étape d'une équipe par son token
-- Scopé au strict minimum : seuls stage, message et photos de l'équipe identifiée sont modifiables
CREATE OR REPLACE FUNCTION update_equipe_by_token(
    p_token TEXT,
    p_stage TEXT,
    p_message TEXT DEFAULT NULL,
    p_photos JSONB DEFAULT '[]'::jsonb
)
RETURNS BOOLEAN AS $$
DECLARE
    chantier_row RECORD;
    equipe_elem JSONB;
    updated_equipes JSONB;
    new_history_entry JSONB;
    existing_history JSONB;
    i INT;
BEGIN
    -- Valider le stage
    IF p_stage NOT IN ('preparation', 'en_cours', 'finitions', 'livre') THEN
        RETURN FALSE;
    END IF;

    -- Chercher le chantier contenant cette équipe
    FOR chantier_row IN
        SELECT c.id, c.equipes
        FROM chantiers c
        WHERE c.equipes IS NOT NULL
          AND jsonb_array_length(c.equipes) > 0
          AND c.archived = false
    LOOP
        FOR i IN 0..jsonb_array_length(chantier_row.equipes) - 1
        LOOP
            equipe_elem := chantier_row.equipes->i;

            IF equipe_elem->>'token' = p_token THEN
                -- Créer l'entrée d'historique
                new_history_entry := jsonb_build_object(
                    'stage', p_stage,
                    'message', p_message,
                    'date', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
                    'photos', p_photos
                );

                -- Récupérer l'historique existant et ajouter en premier (unshift)
                existing_history := COALESCE(equipe_elem->'history', '[]'::jsonb);
                existing_history := jsonb_build_array(new_history_entry) || existing_history;

                -- Mettre à jour l'équipe
                equipe_elem := jsonb_set(equipe_elem, '{stage}', to_jsonb(p_stage));
                equipe_elem := jsonb_set(equipe_elem, '{history}', existing_history);
                equipe_elem := jsonb_set(equipe_elem, '{updatedAt}', to_jsonb(to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));

                IF p_message IS NOT NULL AND p_message != '' THEN
                    equipe_elem := jsonb_set(equipe_elem, '{lastMessage}', to_jsonb(p_message));
                END IF;

                -- Reconstruire le tableau d'équipes avec l'équipe mise à jour
                updated_equipes := chantier_row.equipes;
                updated_equipes := jsonb_set(updated_equipes, ARRAY[i::text], equipe_elem);

                -- Sauvegarder dans la BDD (updated_at sera auto-mis à jour par le trigger)
                UPDATE chantiers
                SET equipes = updated_equipes
                WHERE id = chantier_row.id;

                RETURN TRUE;
            END IF;
        END LOOP;
    END LOOP;

    -- Token non trouvé
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Permissions : autoriser les appels anonymes (sans auth)
GRANT EXECUTE ON FUNCTION get_chantier_by_equipe_token(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION update_equipe_by_token(TEXT, TEXT, TEXT, JSONB) TO anon;
