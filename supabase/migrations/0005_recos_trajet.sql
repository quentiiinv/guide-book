-- =====================================================================
-- Recommandations : format aligné sur les nearby_places (Apify).
-- Chaque reco porte un trajet = durée + mode (à pied / voiture / transports),
-- le trajet le plus court (Walking prioritaire). Les hubs de transport
-- (aéroports, gares) sont EXCLUS à l'ingestion, pas stockés ici.
-- =====================================================================

alter table hotel_recos add column if not exists trajet_mode  text;   -- 'pied' | 'voiture' | 'transports'
alter table hotel_recos add column if not exists trajet_duree text;   -- '6 min'
