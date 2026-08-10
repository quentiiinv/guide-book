-- =====================================================================
-- Email de contact de l'hôtel (bouton mailto de l'écran Infos pratiques).
-- Le téléphone (telephone) et le lien d'avis (lien_avis) existaient déjà ;
-- le guidebook les lit maintenant depuis la ligne (avant : en dur).
-- =====================================================================

alter table hotels add column if not exists email text;

update hotels set email = coalesce(email, 'contact@lharmony-yvelines.fr')
 where slug = 'lharmony';
