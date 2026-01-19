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
    async signUp(email, password, name) {
        const { data, error } = await supabaseClient.auth.signUp({
            email,
            password,
            options: {
                data: { name }
            }
        });

        if (error) throw error;

        // Créer le profil artisan
        if (data.user) {
            await supabaseClient.from('artisans').insert({
                id: data.user.id,
                email: email,
                name: name,
                initials: name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
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
        const { data, error } = await supabaseClient
            .rpc('get_chantier_by_token', { token });

        if (error) throw error;
        return data?.[0] || null;
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
// EXPORT
// =============================================

window.SuiviTravauxAPI = {
    init: initSupabase,
    Auth,
    Chantiers,
    Updates,
    ClientAPI,
    Storage,
    config: SUPABASE_CONFIG
};

console.log('🔧 SuiviTravaux API chargée. Initialiser avec: SuiviTravauxAPI.init()');
