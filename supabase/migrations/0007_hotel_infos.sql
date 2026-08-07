-- =====================================================================
-- INFOS PRATIQUES (équipements) — une ligne par info.
-- Remplies automatiquement à partir des amenities Google/Apify du prospect :
--   free parking      -> Parking gratuit
--   pet-friendly      -> Animaux acceptés
--   air conditioning  -> Climatisation
--   smoke-free        -> Non-fumeur
--   room service      -> Room service
--   airport shuttle   -> Navette aéroport
-- (breakfast/restaurant/spa/pool/sauna -> activent les SECTIONS, pas les infos ;
--  free wifi -> alimente l'écran WiFi). Table publique comme les autres hotel_*.
-- =====================================================================

create table if not exists hotel_infos (
  id        uuid primary key default gen_random_uuid(),
  hotel_id  uuid not null references hotels(id) on delete cascade,
  icone     text,                -- 'parking'|'animaux'|'clim'|'nonfumeur'|'roomservice'|'navette'|'wifi'
  titre     text not null,
  texte     text,
  ordre     int not null default 0
);
create index if not exists idx_infos_hotel on hotel_infos(hotel_id);

alter table hotel_infos enable row level security;
drop policy if exists "public read infos of published hotels" on hotel_infos;
create policy "public read infos of published hotels"
  on hotel_infos for select
  using (exists (select 1 from hotels h where h.id = hotel_id and h.publie));

-- Seed L'Harmony (démo)
insert into hotel_infos (hotel_id, icone, titre, texte, ordre)
select h.id, v.icone, v.titre, v.texte, v.ordre
from hotels h
cross join (values
  ('parking','Parking gratuit','En face de l''hôtel',1),
  ('animaux','Animaux acceptés','Supplément de 8€ par séjour',2),
  ('nonfumeur','Non-fumeur','Interdit de fumer dans la chambre',3)
) as v(icone,titre,texte,ordre)
where h.slug='lharmony'
  and not exists (select 1 from hotel_infos hi where hi.hotel_id=h.id);
