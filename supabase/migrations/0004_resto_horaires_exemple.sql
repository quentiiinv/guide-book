-- =====================================================================
-- Restaurant : phrase d'horaires personnalisable par hôtel + drapeaux
-- « Exemple » (contenu illustratif tant que l'hôtel n'a pas fourni le
-- vrai contenu, pour la démo de prospection — toujours étiqueté « Exemple »).
-- Ajoute aussi a_infos (toggle référencé par le guidebook mais absent du 0001).
-- =====================================================================

alter table hotels add column if not exists resto_horaires text;
alter table hotels add column if not exists resto_exemple  boolean not null default true;
alter table hotels add column if not exists pdj_exemple     boolean not null default true;
alter table hotels add column if not exists a_infos         boolean not null default true;

-- Démo L'Harmony : phrase d'exemple identique à l'actuelle
update hotels
   set resto_horaires = coalesce(resto_horaires, 'Mer → Sam midi & soir · Dim midi'),
       resto_exemple  = true
 where slug = 'lharmony';
