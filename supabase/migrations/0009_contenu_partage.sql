-- =====================================================================
-- Contenu partagé (« modèles par défaut ») pour éviter la duplication.
--   hotel_id NULL  = modèle par défaut, hérité par TOUS les hôtels.
--   hotel_id défini = spécifique à un hôtel : surcharge le modèle (par clé),
--                     ou le masque (actif=false).
-- Clés de fusion : facilities.type, extras.code, infos.icone.
-- =====================================================================

-- 1. hotel_id devient optionnel
alter table hotel_facilities alter column hotel_id drop not null;
alter table hotel_infos      alter column hotel_id drop not null;
alter table hotel_extras     alter column hotel_id drop not null;

-- 2. Clé de fusion pour les extras
alter table hotel_extras add column if not exists code text;
update hotel_extras set code='champagne' where code is null and nom ilike '%champagne%';
update hotel_extras set code='panier'    where code is null and nom ilike '%panier%';
update hotel_extras set code='fleurs'    where code is null and nom ilike '%fleur%';

-- 3. RLS : les modèles partagés (hotel_id null) sont lisibles publiquement,
--    en plus des lignes des hôtels publiés.
drop policy if exists "public read facilities of published hotels" on hotel_facilities;
create policy "public read facilities (partagé ou publié)" on hotel_facilities
  for select using (hotel_id is null or exists (select 1 from hotels h where h.id = hotel_id and h.publie));

drop policy if exists "public read infos of published hotels" on hotel_infos;
create policy "public read infos (partagé ou publié)" on hotel_infos
  for select using (hotel_id is null or exists (select 1 from hotels h where h.id = hotel_id and h.publie));

drop policy if exists "public read extras of published hotels" on hotel_extras;
create policy "public read extras (partagé ou publié)" on hotel_extras
  for select using (hotel_id is null or exists (select 1 from hotels h where h.id = hotel_id and h.publie));

-- 4. Migration des données L'Harmony -> modèles partagés
--    (son contenu spa/piscine/sauna, infos et catalogue extras est générique).

-- 4a. Facilities & infos : deviennent des modèles partagés
update hotel_facilities set hotel_id = null
  where hotel_id in (select id from hotels where slug='lharmony');
update hotel_infos set hotel_id = null
  where hotel_id in (select id from hotels where slug='lharmony');

-- 4b. Extras : le catalogue devient partagé et actif ; on recrée l'exception
--     « panier masqué chez L'Harmony » comme surcharge spécifique.
update hotel_extras set hotel_id = null, actif = true
  where hotel_id in (select id from hotels where slug='lharmony');

insert into hotel_extras (hotel_id, code, nom, prix, emoji, actif, ordre)
select h.id, 'panier', 'Panier de bienvenue', 29, '🧺', false, 2
from hotels h where h.slug='lharmony';
