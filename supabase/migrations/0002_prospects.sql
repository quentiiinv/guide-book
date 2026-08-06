-- =====================================================================
-- SolvIA — Prospection + enrichissement
-- Table `prospects` (privée) alimentée par le pipeline de scraping,
-- table d'exclusion des chaînes, et liaison vers le guidebook.
-- Règles : on accumule (jamais d'écrasement), tout nullable, jsonb pour
-- le brut et les valeurs multi-sources.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Exclusions chaînes / franchises (maintenable)
-- ---------------------------------------------------------------------
create table if not exists prospect_chains (
  id         uuid primary key default gen_random_uuid(),
  pattern    text not null,            -- match insensible à la casse sur hotel_name
  created_at timestamptz not null default now()
);

insert into prospect_chains (pattern) values
  ('ibis'), ('mercure'), ('novotel'), ('accor'), ('b&b'), ('b and b'),
  ('campanile'), ('kyriad'), ('premiere classe'), ('première classe'),
  ('formule 1'), ('formule1'), ('hotelf1'), ('best western'), ('greet'),
  ('sure hotel'), ('logis')
on conflict do nothing;

-- ---------------------------------------------------------------------
-- 2. Prospects
-- ---------------------------------------------------------------------
create table if not exists prospects (
  id               uuid primary key default gen_random_uuid(),
  property_token   text unique not null,         -- clé de dédup Google
  hotel_name       text,
  type             text,
  status           text not null default 'scraped'
    check (status in ('scraped','enriched','previewed','contacted','replied','customer','lost','excluded')),

  -- localisation (Source 1 + BAN Source 2)
  gps_lat          double precision,
  gps_lng          double precision,
  address_full     text,
  street           text,
  postcode         text,
  city             text,
  address_score    numeric,
  address_source   text,

  -- entreprise (Source 3)
  siren                     text,
  raison_sociale            text,
  etat_administratif        text,           -- A / F / C
  company_match_distance_m  numeric,        -- écart GPS siège vs Google (<100m = fiable)
  dirigeant_primary         text,
  dirigeant_status          text check (dirigeant_status in ('found','not_found','unreliable_match')),
  dirigeant_all             jsonb,

  -- email (jamais généré ; on garde le meilleur trouvé ; pas de flag verified)
  email_primary    text,
  email_source     text,                    -- 'google_search' | 'site'
  email_all        jsonb,                   -- [{value, source, score}]

  -- téléphone
  phone_primary    text,
  phone_source     text,
  phone_all        jsonb,                   -- [{value, source}]

  -- réseaux sociaux (Source 5, on prend tout)
  instagram_url    text,
  facebook_url     text,
  linkedin_url     text,
  twitter_url      text,
  youtube_url      text,
  tiktok_url       text,

  -- prospection
  website_link     text,
  overall_rating   numeric,
  reviews_count    int,
  rate_per_night   numeric,
  price_segment    text check (price_segment in ('budget','mid','premium')),
  priority_score   numeric,

  -- brut destiné au guidebook (transformé plus tard vers hotels & co)
  checkin_time     text,
  checkout_time    text,
  amenities_raw    jsonb,
  nearby_raw       jsonb,
  images_raw       jsonb,

  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index if not exists idx_prospects_status   on prospects(status);
create index if not exists idx_prospects_city      on prospects(city);
create index if not exists idx_prospects_siren     on prospects(siren);
create index if not exists idx_prospects_priority  on prospects(priority_score desc);
create index if not exists idx_prospects_email     on prospects(email_primary);

-- ---------------------------------------------------------------------
-- 3. updated_at auto
-- ---------------------------------------------------------------------
create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_prospects_updated on prospects;
create trigger trg_prospects_updated before update on prospects
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------------
-- 4. Liaison prospects -> guidebook
--    Un prospect donne au plus 1 guidebook (hotels).
-- ---------------------------------------------------------------------
alter table hotels add column if not exists prospect_id uuid references prospects(id);
create index if not exists idx_hotels_prospect on hotels(prospect_id);

-- ---------------------------------------------------------------------
-- 5. RLS : données de prospection PRIVÉES (aucune policy publique).
--    Seul le service role (n8n) y accède ; l'anon ne lit rien.
-- ---------------------------------------------------------------------
alter table prospects       enable row level security;
alter table prospect_chains enable row level security;
