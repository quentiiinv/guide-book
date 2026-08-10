-- =====================================================================
-- Réseaux sociaux (un lien par réseau) + drapeau « Exemple » pour les Extras.
-- Instagram & Facebook s'affichent toujours (placeholder si vide) ; les
-- autres réseaux n'apparaissent que si un lien est renseigné.
-- extras_exemple : les « Petites attentions » sont un exemple de ce qu'on
-- peut proposer tant que l'hôtel ne les a pas activées pour de vrai.
-- =====================================================================

alter table hotels add column if not exists extras_exemple   boolean not null default true;
alter table hotels add column if not exists social_instagram text;
alter table hotels add column if not exists social_facebook  text;
alter table hotels add column if not exists social_linkedin  text;
alter table hotels add column if not exists social_youtube   text;
alter table hotels add column if not exists social_tiktok    text;
alter table hotels add column if not exists social_twitter   text;

update hotels
   set social_instagram = coalesce(social_instagram, 'https://www.instagram.com/lharmony_yvelines/'),
       social_facebook  = coalesce(social_facebook,  'https://www.facebook.com/lharmony.yvelines'),
       extras_exemple   = true
 where slug = 'lharmony';
