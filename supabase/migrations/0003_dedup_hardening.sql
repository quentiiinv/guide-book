-- =====================================================================
-- Audit / durcissement anti-doublons du CRM
-- =====================================================================

-- 1 prospect = au plus 1 guidebook (empêche deux hotels sur le même prospect)
alter table hotels add constraint uq_hotels_prospect_id unique (prospect_id);

-- Supprimer un prospect délie son guidebook (au lieu de bloquer / d'orphaner)
alter table hotels drop constraint if exists hotels_prospect_id_fkey;
alter table hotels add constraint hotels_prospect_id_fkey
  foreign key (prospect_id) references prospects(id) on delete set null;

-- Index sur les clés étrangères opérationnelles (perf des jointures)
create index if not exists idx_commandes_reservation on commandes_pdj(reservation_id);
create index if not exists idx_lignes_commande        on lignes_pdj(commande_id);
