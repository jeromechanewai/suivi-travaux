-- =============================================
-- ACTIVER LE REALTIME SUPABASE
-- =============================================
-- Exécutez ce script dans Supabase > SQL Editor
-- pour activer la synchronisation en temps réel
-- =============================================

-- Activer Realtime sur la table chantiers
ALTER PUBLICATION supabase_realtime ADD TABLE chantiers;

-- Activer Realtime sur la table updates
ALTER PUBLICATION supabase_realtime ADD TABLE updates;

-- Note: Le plan gratuit Supabase inclut le Realtime
-- Les changements seront automatiquement poussés aux clients connectés

-- Pour vérifier que c'est activé:
-- SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
