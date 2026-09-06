/* Paiement par carte sur le compte Stripe de l'hotel.

   Appelee par le livret d'un client, donc sans jeton : tout ce qu'elle recoit
   est traite comme non fiable. Le montant n'est jamais lu dans la requete, il
   est relu en base a partir de la reference. La cle Stripe de l'hotel ne quitte
   jamais cette fonction.

   creer    { slug, reference } -> { url }  page de paiement Stripe
   verifier { slug, reference } -> { paye } au retour du client
*/
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPA = Deno.env.get("SUPABASE_URL");
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

function repondre(corps, statut = 200) {
  return new Response(JSON.stringify(corps), {
    status: statut,
    headers: Object.assign({ "content-type": "application/json" }, CORS),
  });
}

/* Acces en service_role : le RLS ne s'applique pas, chaque requete est donc
   bornee explicitement a l'hotel et a la commande demandes. */
async function base(chemin, opt) {
  opt = opt || {};
  const r = await fetch(SUPA + "/rest/v1/" + chemin, {
    method: opt.method || "GET",
    headers: Object.assign({
      apikey: SERVICE,
      authorization: "Bearer " + SERVICE,
      "content-type": "application/json",
    }, opt.headers || {}),
    body: opt.body,
  });
  const t = await r.text();
  if (!r.ok) throw new Error("base: " + t.slice(0, 200));
  return t ? JSON.parse(t) : null;
}

async function stripe(cle, chemin, corps) {
  const r = await fetch("https://api.stripe.com/v1/" + chemin, {
    method: corps ? "POST" : "GET",
    headers: {
      authorization: "Bearer " + cle,
      "content-type": "application/x-www-form-urlencoded",
    },
    body: corps ? corps.toString() : undefined,
  });
  const d = await r.json().catch(() => null);
  if (!r.ok) {
    const m = (d && d.error && d.error.message) || "Stripe a refusé la demande";
    throw new Error(m);
  }
  return d;
}

/* Retrouve la commande et l'hotel, et refuse tout ce qui ne colle pas. */
async function contexte(slug, reference) {
  if (!slug || !reference) throw new Error("Requête incomplète");
  const h = await base("hotels?select=id,nom,slug&slug=eq." +
    encodeURIComponent(slug) + "&publie=is.true&limit=1");
  if (!h || !h.length) throw new Error("Établissement introuvable");
  const c = await base("commandes?select=id,reference,total,statut,email,paye_le,paiement_session" +
    "&hotel_id=eq." + h[0].id + "&reference=eq." + encodeURIComponent(reference) + "&limit=1");
  if (!c || !c.length) throw new Error("Commande introuvable");
  return { hotel: h[0], commande: c[0] };
}

async function cleDe(hotelId) {
  const s = await base("hotel_secrets?select=valeur&hotel_id=eq." + hotelId + "&code=eq.stripe_cle&limit=1");
  if (!s || !s.length || !s[0].valeur) throw new Error("Cet établissement n'encaisse pas par carte");
  return s[0].valeur;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const q = await req.json();
    const { hotel, commande } = await contexte(q.slug, q.reference);

    if (q.action === "verifier") {
      if (commande.paye_le) return repondre({ paye: true });
      if (!commande.paiement_session) return repondre({ paye: false });
      const cle = await cleDe(hotel.id);
      const s = await stripe(cle, "checkout/sessions/" + commande.paiement_session);
      const paye = s && s.payment_status === "paid";
      if (paye) {
        await base("commandes?id=eq." + commande.id, {
          method: "PATCH",
          body: JSON.stringify({ paye_le: new Date().toISOString(), statut: "nouvelle" }),
        });
      }
      return repondre({ paye: !!paye });
    }

    /* creer */
    if (commande.paye_le) return repondre({ erreur: "Cette commande est déjà réglée" }, 409);
    const montant = Math.round(Number(commande.total || 0) * 100);
    if (!(montant > 0)) return repondre({ erreur: "Montant introuvable" }, 400);

    const cle = await cleDe(hotel.id);
    const retour = (q.retour && String(q.retour).indexOf("https://") === 0)
      ? String(q.retour).split("?")[0] : "https://guide.solvia.pro/";

    const p = new URLSearchParams();
    p.set("mode", "payment");
    p.set("client_reference_id", commande.reference);
    p.set("line_items[0][quantity]", "1");
    p.set("line_items[0][price_data][currency]", "eur");
    p.set("line_items[0][price_data][unit_amount]", String(montant));
    p.set("line_items[0][price_data][product_data][name]",
      hotel.nom + " · commande " + commande.reference);
    p.set("metadata[commande_id]", commande.id);
    p.set("success_url", retour + "?paiement=ok&ref=" + encodeURIComponent(commande.reference));
    p.set("cancel_url", retour + "?paiement=annule&ref=" + encodeURIComponent(commande.reference));
    if (commande.email) p.set("customer_email", commande.email);

    const s = await stripe(cle, "checkout/sessions", p);
    await base("commandes?id=eq." + commande.id, {
      method: "PATCH",
      body: JSON.stringify({ paiement_session: s.id, mode_paiement: "en_ligne" }),
    });
    return repondre({ url: s.url });
  } catch (e) {
    return repondre({ erreur: String((e && e.message) || e) }, 400);
  }
});
