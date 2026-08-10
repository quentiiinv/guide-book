-- =====================================================================
-- Restaurant : un lien par bouton (Réserver / Voir le menu).
-- On colle le lien trouvé (Booking, TheFork, site de l'hôtel…). Le bouton
-- s'affiche si le lien est présent, se cache si vide. Aucune URL inventée.
-- =====================================================================

alter table hotels add column if not exists resto_lien_reservation text;
alter table hotels add column if not exists resto_lien_menu         text;

update hotels
   set resto_lien_reservation = coalesce(resto_lien_reservation, 'https://bookings.zenchef.com/results?rid=375884'),
       resto_lien_menu        = coalesce(resto_lien_menu, 'https://lharmony-yvelines.fr/restaurant')
 where slug = 'lharmony';
