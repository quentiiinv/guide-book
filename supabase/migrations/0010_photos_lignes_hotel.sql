-- =====================================================================
-- Photos par hôtel, directement dans la ligne hôtel (liste de liens).
--   pdj_images / resto_images : tableaux jsonb de liens (autant qu'on veut).
-- Priorité : si la liste contient au moins un lien -> on l'utilise ;
--            sinon fallback sur le bucket Storage partagé (petit-dejeuner /
--            restaurant). Les photos d'extras restent par ligne (photo_url).
-- =====================================================================

alter table hotels add column if not exists pdj_images   jsonb not null default '[]'::jsonb;
alter table hotels add column if not exists resto_images jsonb not null default '[]'::jsonb;
