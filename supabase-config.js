// =============================================
// CONFIGURATION SUPABASE - SuiviTravaux.app
// =============================================
//
// INSTRUCTIONS DE CONFIGURATION :
// 1. Créer un compte sur https://supabase.com
// 2. Créer un nouveau projet
// 3. Aller dans Settings > API
// 4. Copier l'URL et la clé anon publique ci-dessous
// 5. Exécuter le fichier supabase-schema.sql dans l'éditeur SQL
//
// =============================================

const SUPABASE_CONFIG = {
    // Configuration Supabase - SuiviTravaux.app
    url: 'https://xschodvxoodyhakmeoxu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhzY2hvZHZ4b29keWhha21lb3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg2NTc0NTMsImV4cCI6MjA4NDIzMzQ1M30.IKcZvhcQuoqOaq7uOgvJgPQxv5DXaBJsyC6HU_tHda8'
};

// =============================================
// CLIENT SUPABASE
// =============================================

let supabaseClient = null;

function initSupabase() {
    if (!window.supabase) {
        console.error('Supabase SDK non chargé');
        return null;
    }
    supabaseClient = window.supabase.createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey);
    console.log('✅ Supabase initialisé');
    return supabaseClient;
}

// =============================================
// AUTHENTIFICATION
// =============================================

const Auth = {
    // Inscription
    async signUp(email, password, name, phone = null) {
        const { data, error } = await supabaseClient.auth.signUp({
            email,
            password,
            options: {
                data: { name, phone }
            }
        });

        if (error) throw error;

        // Créer le profil artisan avec le téléphone et la date de début d'essai
        if (data.user) {
            await supabaseClient.from('artisans').insert({
                id: data.user.id,
                email: email,
                name: name,
                phone: phone,
                initials: name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2),
                trial_start: new Date().toISOString(),
                subscription_status: 'trial'
            });
        }

        return data;
    },

    // Connexion
    async signIn(email, password) {
        const { data, error } = await supabaseClient.auth.signInWithPassword({
            email,
            password
        });
        if (error) throw error;
        return data;
    },

    // Déconnexion
    async signOut() {
        const { error } = await supabaseClient.auth.signOut();
        if (error) throw error;
    },

    // Obtenir l'utilisateur actuel
    async getCurrentUser() {
        const { data: { user } } = await supabaseClient.auth.getUser();
        return user;
    },

    // Obtenir le profil artisan
    async getProfile() {
        const user = await this.getCurrentUser();
        if (!user) return null;

        const { data, error } = await supabaseClient
            .from('artisans')
            .select('*')
            .eq('id', user.id)
            .maybeSingle(); // Utilise maybeSingle() au lieu de single() pour ne pas erreur si pas de résultat

        if (error) throw error;
        return data; // Retourne null si pas trouvé
    },

    // Créer le profil artisan (si pas encore créé)
    async createProfile(userData) {
        const user = await this.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        const { data, error } = await supabaseClient
            .from('artisans')
            .insert({
                id: user.id,
                email: user.email,
                name: userData.name,
                initials: userData.name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
            })
            .select()
            .single();

        if (error) throw error;
        return data;
    },

    // Mettre à jour le profil (ou le créer s'il n'existe pas)
    async updateProfile(updates) {
        const user = await this.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        // Vérifier si le profil existe déjà
        const existingProfile = await this.getProfile();

        if (existingProfile) {
            // Mettre à jour le profil existant
            const { data, error } = await supabaseClient
                .from('artisans')
                .update(updates)
                .eq('id', user.id)
                .select()
                .single();

            if (error) throw error;
            return data;
        } else {
            // Créer un nouveau profil
            const { data, error } = await supabaseClient
                .from('artisans')
                .insert({
                    id: user.id,
                    email: user.email,
                    name: updates.name || user.email.split('@')[0],
                    initials: (updates.initials || updates.name?.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)) || 'AR',
                    phone: updates.phone || null
                })
                .select()
                .single();

            if (error) throw error;
            return data;
        }
    },

    // Écouter les changements d'auth
    onAuthStateChange(callback) {
        return supabaseClient.auth.onAuthStateChange(callback);
    }
};

// =============================================
// GESTION DES CHANTIERS
// =============================================

const Chantiers = {
    // Récupérer tous les chantiers de l'artisan
    async getAll() {
        const user = await Auth.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        const { data, error } = await supabaseClient
            .from('chantiers')
            .select('*')
            .eq('artisan_id', user.id)
            .eq('archived', false)
            .order('updated_at', { ascending: false });

        if (error) throw error;
        return data;
    },

    // Récupérer les chantiers archivés
    async getArchived() {
        const user = await Auth.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        const { data, error } = await supabaseClient
            .from('chantiers')
            .select('*')
            .eq('artisan_id', user.id)
            .eq('archived', true)
            .order('archived_at', { ascending: false });

        if (error) throw error;
        return data;
    },

    // Récupérer un chantier par ID
    async getById(id) {
        const { data, error } = await supabaseClient
            .from('chantiers')
            .select('*')
            .eq('id', id)
            .single();

        if (error) throw error;
        return data;
    },

    // Créer un nouveau chantier
    async create(chantier) {
        const user = await Auth.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        const { data, error } = await supabaseClient
            .from('chantiers')
            .insert({
                artisan_id: user.id,
                name: chantier.name,
                client_name: chantier.client_name,
                client_phone: chantier.client_phone || null,
                estimated_end: chantier.estimated_end || null,
                progress: 0,
                stage: 'preparation',
                status: 'Préparation'
            })
            .select()
            .single();

        if (error) throw error;

        // Créer l'entrée dans l'historique
        await Updates.create(data.id, {
            title: 'Chantier créé',
            progress: 0,
            stage: 'preparation'
        });

        return data;
    },

    // Mettre à jour un chantier
    async update(id, updates) {
        const { data, error } = await supabaseClient
            .from('chantiers')
            .update(updates)
            .eq('id', id)
            .select()
            .single();

        if (error) throw error;
        return data;
    },

    // Archiver un chantier
    async archive(id) {
        return this.update(id, {
            archived: true,
            archived_at: new Date().toISOString()
        });
    },

    // Restaurer un chantier
    async restore(id) {
        return this.update(id, {
            archived: false,
            archived_at: null
        });
    },

    // Supprimer un chantier
    async delete(id) {
        const { error } = await supabaseClient
            .from('chantiers')
            .delete()
            .eq('id', id);

        if (error) throw error;
    },

    // Obtenir le lien de partage
    getShareUrl(shareToken) {
        const baseUrl = window.location.origin;
        return `${baseUrl}/client.html?t=${shareToken}`;
    }
};

// =============================================
// GESTION DES MISES À JOUR
// =============================================

const Updates = {
    // Récupérer l'historique d'un chantier
    async getByChantier(chantierId) {
        const { data, error } = await supabaseClient
            .from('updates')
            .select('*')
            .eq('chantier_id', chantierId)
            .order('created_at', { ascending: false });

        if (error) throw error;
        return data;
    },

    // Créer une mise à jour
    async create(chantierId, update) {
        const { data, error } = await supabaseClient
            .from('updates')
            .insert({
                chantier_id: chantierId,
                title: update.title,
                message: update.message || null,
                progress: update.progress,
                stage: update.stage,
                photo_url: update.photo_url || null,
                voice_url: update.voice_url || null
            })
            .select()
            .single();

        if (error) throw error;

        // Mettre à jour le chantier
        const stageStatus = {
            'preparation': 'Préparation',
            'en_cours': 'En cours',
            'finitions': 'Finitions',
            'livre': 'Terminé !'
        };

        await Chantiers.update(chantierId, {
            progress: update.progress,
            stage: update.stage,
            status: stageStatus[update.stage] || update.stage,
            last_message: update.message || update.title,
            client_viewed: false
        });

        return data;
    }
};

// =============================================
// API CLIENT (PUBLIC - pour les clients via share_token)
// =============================================

const ClientAPI = {
    // Récupérer un chantier par token (marque aussi comme vu)
    async getChantierByToken(token) {
        // Récupérer le chantier avec ses équipes et le nom de l'artisan
        const { data, error } = await supabaseClient
            .from('chantiers')
            .select('*, equipes, artisan:artisans(name, phone)')
            .eq('share_token', token)
            .single();

        if (error) throw error;
        if (!data) return null;

        // Ajouter artisan_name et artisan_phone au niveau racine pour compatibilité
        if (data.artisan) {
            data.artisan_name = data.artisan.name;
            data.artisan_phone = data.artisan.phone || data.artisan_phone;
        }

        // Marquer comme vu (en arrière-plan)
        supabaseClient
            .from('chantiers')
            .update({ client_viewed: true })
            .eq('share_token', token)
            .then(() => console.log('Client view marked'))
            .catch(() => {});

        return data;
    },

    // Récupérer l'historique par token
    async getUpdatesByToken(token) {
        // D'abord récupérer le chantier_id
        const { data: chantier } = await supabaseClient
            .from('chantiers')
            .select('id')
            .eq('share_token', token)
            .single();

        if (!chantier) return [];

        const { data, error } = await supabaseClient
            .from('updates')
            .select('*')
            .eq('chantier_id', chantier.id)
            .order('created_at', { ascending: false });

        if (error) throw error;
        return data;
    },

    // Soumettre le feedback client
    async submitFeedback(token, feedback) {
        const { data, error } = await supabaseClient
            .rpc('submit_client_feedback', { token, feedback });

        if (error) throw error;
        return data;
    }
};

// =============================================
// API EQUIPE (PUBLIC - sans auth, via token)
// =============================================

const EquipeAPI = {
    // Récupérer les données d'un chantier par token d'équipe
    async getByToken(token) {
        const { data, error } = await supabaseClient
            .rpc('get_chantier_by_equipe_token', { p_token: token });

        if (error) throw error;
        return data; // JSONB: { chantier, equipe, otherEquipes, coordinatorPhone }
    },

    // Mettre à jour l'étape d'une équipe par son token
    async updateStage(token, stage, message = null, photos = []) {
        const { data, error } = await supabaseClient
            .rpc('update_equipe_by_token', {
                p_token: token,
                p_stage: stage,
                p_message: message,
                p_photos: photos
            });

        if (error) throw error;
        return data; // boolean: true si mis à jour
    }
};

// =============================================
// STORAGE (Photos & Vocaux)
// =============================================

const Storage = {
    // Upload une photo
    async uploadPhoto(chantierId, file) {
        const user = await Auth.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        const fileExt = file.name.split('.').pop();
        const fileName = `${chantierId}/${Date.now()}.${fileExt}`;

        const { error } = await supabaseClient.storage
            .from('chantier-photos')
            .upload(fileName, file);

        if (error) throw error;

        // Obtenir l'URL publique
        const { data: { publicUrl } } = supabaseClient.storage
            .from('chantier-photos')
            .getPublicUrl(fileName);

        return publicUrl;
    },

    // Upload un message vocal
    async uploadVoice(chantierId, blob) {
        const user = await Auth.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        const fileName = `${chantierId}/${Date.now()}.webm`;

        const { error } = await supabaseClient.storage
            .from('chantier-voices')
            .upload(fileName, blob, {
                contentType: 'audio/webm'
            });

        if (error) throw error;

        // Obtenir l'URL publique
        const { data: { publicUrl } } = supabaseClient.storage
            .from('chantier-voices')
            .getPublicUrl(fileName);

        return publicUrl;
    },

    // Récupérer les photos d'un chantier
    async getPhotos(chantierId) {
        const { data, error } = await supabaseClient
            .from('photos')
            .select('*')
            .eq('chantier_id', chantierId)
            .order('created_at', { ascending: false });

        if (error) throw error;
        return data;
    }
};

// =============================================
// REALTIME - Mise à jour automatique
// =============================================

const Realtime = {
    subscription: null,

    // S'abonner aux changements des chantiers de l'artisan
    subscribeToChantiers(userId, onUpdate) {
        if (this.subscription) {
            this.subscription.unsubscribe();
        }

        this.subscription = supabaseClient
            .channel('chantiers-changes')
            .on(
                'postgres_changes',
                {
                    event: '*', // INSERT, UPDATE, DELETE
                    schema: 'public',
                    table: 'chantiers',
                    filter: `artisan_id=eq.${userId}`
                },
                (payload) => {
                    console.log('🔄 Changement détecté:', payload.eventType);
                    if (onUpdate) onUpdate(payload);
                }
            )
            .on(
                'postgres_changes',
                {
                    event: '*',
                    schema: 'public',
                    table: 'updates'
                },
                (payload) => {
                    console.log('🔄 Nouvelle mise à jour:', payload.eventType);
                    if (onUpdate) onUpdate(payload);
                }
            )
            .subscribe((status) => {
                console.log('📡 Realtime status:', status);
            });

        return this.subscription;
    },

    // Se désabonner
    unsubscribe() {
        if (this.subscription) {
            this.subscription.unsubscribe();
            this.subscription = null;
        }
    }
};

// =============================================
// GESTION DES ENTREPRISES
// =============================================

const Enterprises = {
    // Récupérer l'entreprise de l'utilisateur
    async getMine() {
        const user = await Auth.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        const profile = await Auth.getProfile();
        if (!profile?.enterprise_id) return null;

        const { data, error } = await supabaseClient
            .from('enterprises')
            .select('*')
            .eq('id', profile.enterprise_id)
            .single();

        if (error) throw error;
        return data;
    },

    // Créer une entreprise (pour artisan solo)
    async create(enterprise) {
        const user = await Auth.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        const { data, error } = await supabaseClient
            .from('enterprises')
            .insert({
                name: enterprise.name,
                trade_type: enterprise.trade_type || 'general',
                contact_name: enterprise.contact_name,
                contact_phone: enterprise.contact_phone,
                contact_email: enterprise.contact_email || user.email,
                color: enterprise.color || '#3b82f6'
            })
            .select()
            .single();

        if (error) throw error;

        // Lier l'entreprise au profil
        await supabaseClient
            .from('artisans')
            .update({ enterprise_id: data.id })
            .eq('id', user.id);

        return data;
    },

    // Mettre à jour l'entreprise
    async update(id, updates) {
        const { data, error } = await supabaseClient
            .from('enterprises')
            .update({ ...updates, updated_at: new Date().toISOString() })
            .eq('id', id)
            .select()
            .single();

        if (error) throw error;
        return data;
    },

    // Rechercher des entreprises (pour inviter)
    async search(query) {
        const { data, error } = await supabaseClient
            .from('enterprises')
            .select('id, name, trade_type, contact_phone, color')
            .ilike('name', `%${query}%`)
            .limit(10);

        if (error) throw error;
        return data;
    }
};

// =============================================
// GESTION DES PROJETS MULTI-ÉQUIPES
// =============================================

const Projects = {
    // Récupérer tous les projets (en tant que coordinateur ou équipe)
    async getAll() {
        const user = await Auth.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        const profile = await Auth.getProfile();

        // Projets où je suis coordinateur
        const { data: coordProjects, error: err1 } = await supabaseClient
            .from('projects')
            .select(`
                *,
                interventions (id, name, status, progress, order_index)
            `)
            .eq('coordinator_id', user.id)
            .neq('status', 'archived')
            .order('updated_at', { ascending: false });

        if (err1) throw err1;

        // Projets où mon entreprise intervient
        let teamProjects = [];
        if (profile?.enterprise_id) {
            const { data, error: err2 } = await supabaseClient
                .from('projects')
                .select(`
                    *,
                    interventions!inner (id, name, status, progress, order_index, enterprise_id)
                `)
                .eq('interventions.enterprise_id', profile.enterprise_id)
                .neq('status', 'archived')
                .order('updated_at', { ascending: false });

            if (!err2) teamProjects = data || [];
        }

        // Fusionner et dédupliquer
        const allProjects = [...coordProjects];
        teamProjects.forEach(p => {
            if (!allProjects.find(cp => cp.id === p.id)) {
                allProjects.push(p);
            }
        });

        return allProjects;
    },

    // Récupérer un projet par ID avec ses interventions
    async getById(id) {
        const { data, error } = await supabaseClient
            .from('projects')
            .select(`
                *,
                interventions (
                    *,
                    enterprise:enterprises (id, name, color, contact_phone, trade_type)
                )
            `)
            .eq('id', id)
            .single();

        if (error) throw error;

        // Trier les interventions par order_index
        if (data?.interventions) {
            data.interventions.sort((a, b) => a.order_index - b.order_index);
        }

        return data;
    },

    // Créer un nouveau projet
    async create(project) {
        const user = await Auth.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        const { data, error } = await supabaseClient
            .from('projects')
            .insert({
                name: project.name,
                description: project.description || null,
                address: project.address || null,
                client_name: project.client_name,
                client_phone: project.client_phone || null,
                client_email: project.client_email || null,
                coordinator_id: user.id,
                start_date: project.start_date || null,
                estimated_end: project.estimated_end || null,
                status: 'active'
            })
            .select()
            .single();

        if (error) throw error;
        return data;
    },

    // Mettre à jour un projet
    async update(id, updates) {
        const { data, error } = await supabaseClient
            .from('projects')
            .update({ ...updates, updated_at: new Date().toISOString() })
            .eq('id', id)
            .select()
            .single();

        if (error) throw error;
        return data;
    },

    // Archiver un projet
    async archive(id) {
        return this.update(id, { status: 'archived' });
    },

    // Récupérer les templates de projets
    async getTemplates() {
        const { data, error } = await supabaseClient
            .from('project_templates')
            .select('*')
            .order('name');

        if (error) throw error;
        return data;
    },

    // Créer un projet à partir d'un template
    async createFromTemplate(templateId, projectData) {
        // Récupérer le template
        const { data: template, error: err1 } = await supabaseClient
            .from('project_templates')
            .select('*')
            .eq('id', templateId)
            .single();

        if (err1) throw err1;

        // Créer le projet
        const project = await this.create(projectData);

        // Créer les interventions depuis le template
        const interventions = template.interventions || [];
        for (const intervention of interventions) {
            await Interventions.create(project.id, {
                name: intervention.name,
                order_index: intervention.order
            });
        }

        return this.getById(project.id);
    },

    // Obtenir le lien de partage client
    getShareUrl(shareToken) {
        if (window.location.protocol === 'file:') {
            const currentPath = window.location.pathname;
            const folderPath = currentPath.substring(0, currentPath.lastIndexOf('/') + 1);
            return 'file://' + folderPath + 'client-project.html?t=' + shareToken;
        }
        return window.location.origin + '/client-project.html?t=' + shareToken;
    }
};

// =============================================
// GESTION DES INTERVENTIONS
// =============================================

const Interventions = {
    // Récupérer les interventions d'un projet
    async getByProject(projectId) {
        const { data, error } = await supabaseClient
            .from('interventions')
            .select(`
                *,
                enterprise:enterprises (id, name, color, contact_phone, trade_type)
            `)
            .eq('project_id', projectId)
            .order('order_index');

        if (error) throw error;
        return data;
    },

    // Récupérer MES interventions (pour une équipe)
    async getMine() {
        const user = await Auth.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        const profile = await Auth.getProfile();
        if (!profile?.enterprise_id) return [];

        const { data, error } = await supabaseClient
            .from('interventions')
            .select(`
                *,
                project:projects (id, name, client_name, coordinator_id, share_token)
            `)
            .eq('enterprise_id', profile.enterprise_id)
            .neq('status', 'done')
            .order('updated_at', { ascending: false });

        if (error) throw error;
        return data;
    },

    // Créer une intervention
    async create(projectId, intervention) {
        // Déterminer le prochain order_index
        const { data: existing } = await supabaseClient
            .from('interventions')
            .select('order_index')
            .eq('project_id', projectId)
            .order('order_index', { ascending: false })
            .limit(1);

        const nextOrder = (existing?.[0]?.order_index || 0) + 1;

        const { data, error } = await supabaseClient
            .from('interventions')
            .insert({
                project_id: projectId,
                name: intervention.name,
                description: intervention.description || null,
                order_index: intervention.order_index || nextOrder,
                enterprise_id: intervention.enterprise_id || null,
                estimated_start: intervention.estimated_start || null,
                estimated_end: intervention.estimated_end || null
            })
            .select(`
                *,
                enterprise:enterprises (id, name, color, contact_phone)
            `)
            .single();

        if (error) throw error;
        return data;
    },

    // Mettre à jour une intervention
    async update(id, updates) {
        const { data, error } = await supabaseClient
            .from('interventions')
            .update({ ...updates, updated_at: new Date().toISOString() })
            .eq('id', id)
            .select()
            .single();

        if (error) throw error;
        return data;
    },

    // Assigner une entreprise à une intervention
    async assign(interventionId, enterpriseId) {
        return this.update(interventionId, { enterprise_id: enterpriseId });
    },

    // Mettre à jour la progression (action principale pour les équipes)
    async updateProgress(id, progress, message = null) {
        const user = await Auth.getCurrentUser();

        // Mettre à jour l'intervention
        const newStatus = progress >= 100 ? 'done' : progress > 0 ? 'active' : 'waiting';

        const { data: intervention, error } = await supabaseClient
            .from('interventions')
            .update({
                progress: Math.min(100, Math.max(0, progress)),
                status: newStatus,
                last_message: message || null,
                last_update_at: new Date().toISOString(),
                actual_start: null, // Sera mis par le trigger si premier update
                actual_end: progress >= 100 ? new Date().toISOString() : null,
                updated_at: new Date().toISOString()
            })
            .eq('id', id)
            .select()
            .single();

        if (error) throw error;

        // Créer l'entrée dans l'historique
        await InterventionUpdates.create(id, {
            progress,
            message,
            user_id: user?.id
        });

        return intervention;
    },

    // Marquer comme terminé (action "J'ai terminé")
    async markDone(id, message = null, photoUrl = null) {
        const user = await Auth.getCurrentUser();

        // Mettre à jour l'intervention
        const { data: intervention, error } = await supabaseClient
            .from('interventions')
            .update({
                progress: 100,
                status: 'done',
                last_message: message || 'Intervention terminée',
                last_update_at: new Date().toISOString(),
                actual_end: new Date().toISOString(),
                updated_at: new Date().toISOString()
            })
            .eq('id', id)
            .select()
            .single();

        if (error) throw error;

        // Créer l'entrée dans l'historique
        await InterventionUpdates.create(id, {
            title: 'Intervention terminée',
            progress: 100,
            message,
            photo_url: photoUrl,
            user_id: user?.id
        });

        return intervention;
    },

    // Supprimer une intervention
    async delete(id) {
        const { error } = await supabaseClient
            .from('interventions')
            .delete()
            .eq('id', id);

        if (error) throw error;
    },

    // Réordonner les interventions
    async reorder(orderedIds) {
        // Mettre à jour chaque intervention avec son nouvel ordre
        for (let i = 0; i < orderedIds.length; i++) {
            await supabaseClient
                .from('interventions')
                .update({ order_index: i + 1 })
                .eq('id', orderedIds[i]);
        }
    },

    // Obtenir le statut d'affichage (utilise la fonction SQL)
    async getDisplayStatus(id) {
        const { data, error } = await supabaseClient
            .rpc('get_intervention_display_status', { p_intervention_id: id });

        if (error) throw error;
        return data?.[0] || null;
    }
};

// =============================================
// MISES À JOUR D'INTERVENTIONS
// =============================================

const InterventionUpdates = {
    // Récupérer l'historique d'une intervention
    async getByIntervention(interventionId) {
        const { data, error } = await supabaseClient
            .from('intervention_updates')
            .select(`
                *,
                user:artisans (id, name, initials)
            `)
            .eq('intervention_id', interventionId)
            .order('created_at', { ascending: false });

        if (error) throw error;
        return data;
    },

    // Créer une mise à jour
    async create(interventionId, update) {
        const user = await Auth.getCurrentUser();

        const { data, error } = await supabaseClient
            .from('intervention_updates')
            .insert({
                intervention_id: interventionId,
                user_id: user?.id || update.user_id,
                title: update.title || null,
                message: update.message || null,
                progress: update.progress,
                photo_url: update.photo_url || null,
                photo_urls: update.photo_urls || [],
                voice_url: update.voice_url || null
            })
            .select()
            .single();

        if (error) throw error;
        return data;
    }
};

// =============================================
// INVITATIONS
// =============================================

const Invitations = {
    // Inviter une entreprise sur un projet
    async invite(projectId, interventionId, contact) {
        const user = await Auth.getCurrentUser();

        const { data, error } = await supabaseClient
            .from('project_invitations')
            .insert({
                project_id: projectId,
                intervention_id: interventionId,
                invite_email: contact.email || null,
                invite_phone: contact.phone || null,
                enterprise_id: contact.enterprise_id || null,
                invited_by: user.id
            })
            .select()
            .single();

        if (error) throw error;
        return data;
    },

    // Accepter une invitation
    async accept(inviteToken) {
        const user = await Auth.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        const profile = await Auth.getProfile();

        // Récupérer l'invitation
        const { data: invitation, error: err1 } = await supabaseClient
            .from('project_invitations')
            .select('*, intervention:interventions(*)')
            .eq('invite_token', inviteToken)
            .single();

        if (err1) throw err1;
        if (!invitation) throw new Error('Invitation non trouvée');

        // Mettre à jour l'invitation
        await supabaseClient
            .from('project_invitations')
            .update({
                status: 'accepted',
                enterprise_id: profile?.enterprise_id,
                responded_at: new Date().toISOString()
            })
            .eq('id', invitation.id);

        // Assigner l'entreprise à l'intervention
        if (invitation.intervention_id && profile?.enterprise_id) {
            await Interventions.assign(invitation.intervention_id, profile.enterprise_id);
        }

        return invitation;
    },

    // Récupérer mes invitations en attente
    async getPending() {
        const user = await Auth.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        const profile = await Auth.getProfile();

        const { data, error } = await supabaseClient
            .from('project_invitations')
            .select(`
                *,
                project:projects (id, name, client_name),
                intervention:interventions (id, name)
            `)
            .eq('status', 'pending')
            .or(`invite_email.eq.${user.email},enterprise_id.eq.${profile?.enterprise_id}`);

        if (error) throw error;
        return data;
    }
};

// =============================================
// API CLIENT PROJETS (PUBLIC)
// =============================================

const ClientProjectAPI = {
    // Récupérer projet + interventions en une seule requête (optimisé)
    async getProjectByToken(token) {
        const { data, error } = await supabaseClient
            .rpc('get_full_project_by_token', { p_token: token });

        if (error) throw error;
        return data || null;
    },

    // Récupérer un projet par token (méthode simple)
    async getByToken(token) {
        const { data, error } = await supabaseClient
            .rpc('get_project_by_token', { p_token: token });

        if (error) throw error;
        return data?.[0] || null;
    },

    // Récupérer les interventions par token
    async getInterventionsByToken(token) {
        const { data, error } = await supabaseClient
            .rpc('get_interventions_by_token', { p_token: token });

        if (error) throw error;
        return data || [];
    },

    // Récupérer les dernières mises à jour
    async getRecentUpdates(token, limit = 10) {
        const { data, error } = await supabaseClient
            .rpc('get_project_updates_by_token', { p_token: token, p_limit: limit });

        if (error) throw error;
        return data || [];
    }
};

// =============================================
// NOTIFICATIONS
// =============================================

const Notifications = {
    // Récupérer mes notifications
    async getAll(unreadOnly = false) {
        const user = await Auth.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        let query = supabaseClient
            .from('notifications')
            .select(`
                *,
                project:projects (id, name),
                intervention:interventions (id, name)
            `)
            .eq('user_id', user.id)
            .order('created_at', { ascending: false })
            .limit(50);

        if (unreadOnly) {
            query = query.eq('read', false);
        }

        const { data, error } = await query;
        if (error) throw error;
        return data;
    },

    // Compter les non lues
    async countUnread() {
        const user = await Auth.getCurrentUser();
        if (!user) return 0;

        const { count, error } = await supabaseClient
            .from('notifications')
            .select('*', { count: 'exact', head: true })
            .eq('user_id', user.id)
            .eq('read', false);

        if (error) throw error;
        return count || 0;
    },

    // Marquer comme lue
    async markAsRead(notificationId) {
        const { error } = await supabaseClient
            .from('notifications')
            .update({ read: true, read_at: new Date().toISOString() })
            .eq('id', notificationId);

        if (error) throw error;
    },

    // Marquer toutes comme lues
    async markAllAsRead() {
        const user = await Auth.getCurrentUser();
        if (!user) throw new Error('Non connecté');

        const { error } = await supabaseClient
            .from('notifications')
            .update({ read: true, read_at: new Date().toISOString() })
            .eq('user_id', user.id)
            .eq('read', false);

        if (error) throw error;
    },

    // Écouter les nouvelles notifications en temps réel
    subscribe(callback) {
        return supabaseClient
            .channel('notifications')
            .on(
                'postgres_changes',
                {
                    event: 'INSERT',
                    schema: 'public',
                    table: 'notifications'
                },
                (payload) => {
                    callback(payload.new);
                }
            )
            .subscribe();
    },

    // Se désabonner
    unsubscribe(subscription) {
        if (subscription) {
            supabaseClient.removeChannel(subscription);
        }
    }
};

// =============================================
// EXPORT
// =============================================

window.SuiviTravauxAPI = {
    init: initSupabase,
    Auth,
    // Ancien système (compatible)
    Chantiers,
    Updates,
    ClientAPI,
    EquipeAPI,
    // Nouveau système multi-équipes
    Enterprises,
    Projects,
    Interventions,
    InterventionUpdates,
    Invitations,
    ClientProjectAPI,
    Notifications,
    // Commun
    Storage,
    Realtime,
    config: SUPABASE_CONFIG
};

console.log('🔧 SuiviTravaux API v2.0 chargée (multi-équipes)');
console.log('   Ancien système: Chantiers, Updates, ClientAPI');
console.log('   Nouveau système: Projects, Interventions, Enterprises, Notifications');
