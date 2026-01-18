// =============================================
// SERVICE WORKER - SuiviTravaux.app
// =============================================
// Cache les ressources statiques pour le mode offline
// et améliore les performances de chargement

const CACHE_NAME = 'suivitravaux-v1';
const STATIC_ASSETS = [
    '/',
    '/index.html',
    '/preview.html',
    '/client.html',
    '/favicon.svg',
    '/manifest.json',
    '/supabase-config.js'
];

// Installation - mise en cache des ressources statiques
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then((cache) => {
                console.log('Cache ouvert');
                return cache.addAll(STATIC_ASSETS);
            })
            .catch((error) => {
                console.error('Erreur lors du cache:', error);
            })
    );
    // Activer immédiatement le nouveau service worker
    self.skipWaiting();
});

// Activation - nettoyage des anciens caches
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames
                    .filter((cacheName) => cacheName !== CACHE_NAME)
                    .map((cacheName) => caches.delete(cacheName))
            );
        })
    );
    // Prendre le contrôle de toutes les pages immédiatement
    self.clients.claim();
});

// Stratégie de fetch: Network First avec fallback sur le cache
self.addEventListener('fetch', (event) => {
    // Ignorer les requêtes non-GET et les requêtes vers Supabase
    if (event.request.method !== 'GET') return;
    if (event.request.url.includes('supabase.co')) return;
    if (event.request.url.includes('cdn.')) return;

    event.respondWith(
        // Essayer le réseau d'abord
        fetch(event.request)
            .then((response) => {
                // Si succès, mettre en cache et retourner
                if (response.status === 200) {
                    const responseToCache = response.clone();
                    caches.open(CACHE_NAME)
                        .then((cache) => {
                            cache.put(event.request, responseToCache);
                        });
                }
                return response;
            })
            .catch(() => {
                // Si échec réseau, chercher dans le cache
                return caches.match(event.request)
                    .then((cachedResponse) => {
                        if (cachedResponse) {
                            return cachedResponse;
                        }
                        // Si pas en cache et offline, retourner une page offline
                        if (event.request.destination === 'document') {
                            return caches.match('/preview.html');
                        }
                    });
            })
    );
});

// Message pour forcer la mise à jour
self.addEventListener('message', (event) => {
    if (event.data === 'skipWaiting') {
        self.skipWaiting();
    }
});
