-- =====================================================================
-- SolvIA Guidebook — schéma multi-hôtel
-- Une base centrale qui décrit chaque hôtel prospecté : identité, contenu,
-- et les sections activées (cases oui/non). Le guidebook lit cette base
-- et se construit tout seul pour chaque hôtel.
--
-- Séparation volontaire :
--   - Tables "hotel_*"  = contenu PUBLIC de l'hôtel (lisible par le guidebook).
--   - Table  "guests"   = données PERSONNELLES par client (chambre, code…),
--                         jamais exposées publiquement (servies via n8n).
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- 1. HÔTELS — une ligne par hôtel prospecté
-- ---------------------------------------------------------------------
create table if not exists hotels (
  id                  uuid primary key default gen_random_uuid(),
  slug                text unique not null,          -- identifiant URL : ?hotel=lharmony
  nom                 text not null,
  lieu                text,
  -- identité visuelle
  couleur_principale  text default '#1F3B2D',
  couleur_accent      text default '#C9A961',
  logo_url            text,
  -- infos pratiques
  checkin             text default '15:00',
  checkout_std        text default '11:00',
  wifi_reseau         text,
  wifi_motdepasse     text,
  telephone           text,
  adresse_maps        text,
  video_url           text,
  -- petit-déjeuner (prix)
  pdj_prix_adulte     numeric,
  pdj_prix_enfant     numeric,
  -- 👇 TOGGLES DE SECTIONS (cases oui/non). Arrivée + WiFi toujours présents.
  a_petit_dej         boolean not null default true,
  a_restaurant        boolean not null default true,
  a_piscine           boolean not null default false,
  a_spa               boolean not null default false,
  a_sauna             boolean not null default false,
  a_extras            boolean not null default true,
  a_recos             boolean not null default true,
  a_avis              boolean not null default true,
  a_late_checkout     boolean not null default true,
  -- publication
  publie              boolean not null default false, -- true = visible par le guidebook
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 2. EXTRAS — petites attentions payantes (champagne, panier, fleurs…)
-- ---------------------------------------------------------------------
create table if not exists hotel_extras (
  id          uuid primary key default gen_random_uuid(),
  hotel_id    uuid not null references hotels(id) on delete cascade,
  slug        text,
  nom         text not null,
  description text,
  prix        numeric,
  emoji       text,
  photo_url   text,
  ordre       int not null default 0,
  actif       boolean not null default true
);
create index if not exists idx_extras_hotel on hotel_extras(hotel_id);

-- ---------------------------------------------------------------------
-- 3. BIEN-ÊTRE — Spa / Piscine / Sauna (composant InfoBlock générique)
-- ---------------------------------------------------------------------
create table if not exists hotel_facilities (
  id          uuid primary key default gen_random_uuid(),
  hotel_id    uuid not null references hotels(id) on delete cascade,
  type        text not null,             -- 'spa' | 'piscine' | 'sauna' (extensible : 'golf'…)
  titre       text,
  emoji       text,
  photo_url   text,
  description text,
  horaires    text,
  acces       text,
  a_prevoir   text,
  maps_url    text
);
create index if not exists idx_facilities_hotel on hotel_facilities(hotel_id);

-- ---------------------------------------------------------------------
-- 4. RECOMMANDATIONS LOCALES — liste répétable, sans limite
-- ---------------------------------------------------------------------
create table if not exists hotel_recos (
  id          uuid primary key default gen_random_uuid(),
  hotel_id    uuid not null references hotels(id) on delete cascade,
  nom         text not null,
  categorie   text,                      -- 'Restaurant' | 'Activité' | 'Visite'
  description text,
  emoji       text,
  photo_url   text,
  maps_url    text,
  ordre       int not null default 0
);
create index if not exists idx_recos_hotel on hotel_recos(hotel_id);

-- ---------------------------------------------------------------------
-- 5. LATE CHECK-OUT — créneaux + suppléments configurables
-- ---------------------------------------------------------------------
create table if not exists hotel_late_checkout (
  id          uuid primary key default gen_random_uuid(),
  hotel_id    uuid not null references hotels(id) on delete cascade,
  heure       text not null,             -- '13h00'
  prix        numeric not null,          -- 20
  ordre       int not null default 0
);
create index if not exists idx_lco_hotel on hotel_late_checkout(hotel_id);

-- ---------------------------------------------------------------------
-- 6. CLIENTS — données personnelles par séjour (NON publiques)
--    Remplace/centralise ce que NocoDB stocke aujourd'hui.
-- ---------------------------------------------------------------------
create table if not exists guests (
  id                  uuid primary key default gen_random_uuid(),
  hotel_id            uuid not null references hotels(id) on delete cascade,
  token               text unique not null,   -- lien perso : ?token=...
  prenom              text,
  chambre             text,
  code_acces          text,
  pdj_restant_adulte  int not null default 0,
  pdj_restant_enfant  int not null default 0,
  created_at          timestamptz not null default now()
);
create index if not exists idx_guests_hotel on guests(hotel_id);

-- =====================================================================
-- RLS — le contenu hôtel est PUBLIC (le guidebook est ouvert),
-- mais uniquement pour les hôtels publiés. Les données clients ne sont
-- JAMAIS lisibles publiquement (servies par n8n avec la service key).
-- =====================================================================
alter table hotels                enable row level security;
alter table hotel_extras          enable row level security;
alter table hotel_facilities      enable row level security;
alter table hotel_recos           enable row level security;
alter table hotel_late_checkout   enable row level security;
alter table guests                enable row level security;

create policy "public read published hotels"
  on hotels for select using (publie = true);

create policy "public read extras of published hotels"
  on hotel_extras for select
  using (exists (select 1 from hotels h where h.id = hotel_id and h.publie));

create policy "public read facilities of published hotels"
  on hotel_facilities for select
  using (exists (select 1 from hotels h where h.id = hotel_id and h.publie));

create policy "public read recos of published hotels"
  on hotel_recos for select
  using (exists (select 1 from hotels h where h.id = hotel_id and h.publie));

create policy "public read late_checkout of published hotels"
  on hotel_late_checkout for select
  using (exists (select 1 from hotels h where h.id = hotel_id and h.publie));

-- guests : aucune policy de lecture publique -> table verrouillée côté client.
