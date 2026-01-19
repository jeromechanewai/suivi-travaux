# Guide de déploiement - SuiviTravaux.app

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Frontend      │────▶│   Supabase      │────▶│   PostgreSQL    │
│   (Netlify)     │     │   (Backend)     │     │   (Database)    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
     │                         │
     │                         │
     ▼                         ▼
┌─────────────────┐     ┌─────────────────┐
│   preview.html  │     │   Auth          │
│   client.html   │     │   Storage       │
│   *.js          │     │   Realtime      │
└─────────────────┘     └─────────────────┘
```

## Étape 1 : Configurer Supabase

### 1.1 Créer un compte Supabase

1. Aller sur [https://supabase.com](https://supabase.com)
2. Créer un compte gratuit (GitHub ou email)
3. Créer un nouveau projet :
   - **Name** : `suivitravaux`
   - **Database Password** : Générer un mot de passe fort (le sauvegarder !)
   - **Region** : `West EU (Paris)` pour la France

### 1.2 Configurer la base de données

1. Aller dans **SQL Editor** (menu gauche)
2. Cliquer sur **New Query**
3. Copier-coller le contenu de `supabase-schema.sql`
4. Cliquer sur **Run** (ou Ctrl+Enter)
5. Vérifier que toutes les tables sont créées dans **Table Editor**

### 1.3 Configurer le Storage (photos)

1. Aller dans **Storage** (menu gauche)
2. Créer un nouveau bucket :
   - **Name** : `chantier-photos`
   - **Public** : Oui
3. Ajouter une policy pour l'upload (Settings > Policies) :
   ```sql
   CREATE POLICY "Authenticated users can upload"
   ON storage.objects FOR INSERT
   TO authenticated
   WITH CHECK (bucket_id = 'chantier-photos');
   ```

### 1.4 Récupérer les clés API

1. Aller dans **Settings** > **API**
2. Noter :
   - **Project URL** : `https://xxxxx.supabase.co`
   - **anon public key** : `eyJhbGciOiJIUzI1NiIs...`

### 1.5 Configurer l'application

1. Ouvrir `supabase-config.js`
2. Remplacer les valeurs :
   ```javascript
   const SUPABASE_CONFIG = {
       url: 'https://VOTRE_PROJECT_URL.supabase.co',
       anonKey: 'VOTRE_ANON_KEY'
   };
   ```

---

## Étape 2 : Déployer le Frontend

### Option A : Netlify (Recommandé)

1. Aller sur [https://netlify.com](https://netlify.com)
2. Créer un compte gratuit
3. Cliquer sur **Add new site** > **Deploy manually**
4. Glisser-déposer le dossier contenant :
   - `preview.html` (renommer en `index.html` pour la page d'accueil)
   - `client.html`
   - `favicon.svg`
   - `manifest.json`
   - `supabase-config.js`
5. Netlify génère une URL : `https://xxxxx.netlify.app`

### Option B : Vercel

1. Aller sur [https://vercel.com](https://vercel.com)
2. Créer un compte
3. **New Project** > **Upload**
4. Uploader les fichiers

### Option C : GitHub Pages

1. Créer un repo GitHub
2. Pusher les fichiers
3. Settings > Pages > Deploy from branch (main)

---

## Étape 3 : Configurer le domaine personnalisé

### 3.1 Acheter le domaine

Acheter `suivitravaux.app` sur :
- [Namecheap](https://namecheap.com) (~15€/an)
- [OVH](https://ovh.com)
- [Google Domains](https://domains.google)

### 3.2 Configurer les DNS

Sur Netlify :
1. **Domain settings** > **Add custom domain**
2. Ajouter : `suivitravaux.app` et `www.suivitravaux.app`
3. Configurer les DNS chez le registrar :
   ```
   Type    Name    Value
   A       @       75.2.60.5
   CNAME   www     xxxxx.netlify.app
   ```

### 3.3 Activer HTTPS

Netlify active automatiquement Let's Encrypt SSL gratuit.

---

## Étape 4 : Mettre à jour les liens

### Dans `supabase-config.js` :
```javascript
// Mettre à jour les URLs de partage
getShareUrl(shareToken) {
    return `https://suivitravaux.app/client.html?t=${shareToken}`;
}
```

### Dans `preview.html` :
Mettre à jour les méta-tags OG :
```html
<meta property="og:url" content="https://suivitravaux.app/">
<meta property="og:image" content="https://suivitravaux.app/og-image.png">
```

---

## Structure des fichiers finale

```
suivitravaux.app/
├── index.html          (renommer preview.html)
├── client.html         (page vue client)
├── favicon.svg
├── manifest.json
├── supabase-config.js
├── supabase-schema.sql (ne pas déployer, juste pour référence)
├── DEPLOY.md           (ne pas déployer)
└── og-image.png        (à créer pour les réseaux sociaux)
```

---

## Checklist de déploiement

- [ ] Compte Supabase créé
- [ ] Base de données configurée (schema SQL exécuté)
- [ ] Storage bucket créé (`chantier-photos`)
- [ ] Clés API copiées dans `supabase-config.js`
- [ ] Frontend déployé sur Netlify/Vercel
- [ ] Domaine personnalisé configuré (optionnel)
- [ ] HTTPS activé
- [ ] Test de création de compte
- [ ] Test de création de chantier
- [ ] Test du lien client partageable

---

## Coûts estimés

| Service | Gratuit | Payant |
|---------|---------|--------|
| Supabase | 500MB DB, 1GB storage | $25/mois pour plus |
| Netlify | 100GB/mois bandwidth | $19/mois pour plus |
| Domaine | - | ~15€/an |

**Total pour démarrer : ~15€/an** (juste le domaine)

---

## Support

- Supabase Docs : https://supabase.com/docs
- Netlify Docs : https://docs.netlify.com
- GitHub Issues : (votre repo)
