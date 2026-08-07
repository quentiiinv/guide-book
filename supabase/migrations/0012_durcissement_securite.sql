-- =====================================================================
-- Durcissement sécurité (audit RLS).
-- Vérifié : les tables sensibles (chambres/codes, prospects, reservations,
-- commandes_pdj, lignes_pdj, prospect_chains) ont RLS actif SANS aucune
-- policy => illisibles et non modifiables via la clé publique (anon).
-- Aucune policy d'écriture publique nulle part.
-- Ici : on retire les policies de lecture en double et on fige le
-- search_path de la fonction trigger.
-- =====================================================================

drop policy if exists "read extras" on hotel_extras;
drop policy if exists "read facil" on hotel_facilities;
drop policy if exists "read infos" on hotel_infos;

alter function public.set_updated_at() set search_path = '';
