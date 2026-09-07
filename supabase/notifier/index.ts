/* Prévient la réception qu'une commande vient d'arriver.

   Appelée par la base juste après l'enregistrement, avec un secret partagé
   rangé dans app_settings : sans ce secret, personne ne peut déclencher
   d'envoi depuis l'extérieur. L'adresse destinataire est celle que l'hôtelier
   a saisie dans ses intégrations, qui reste privée.

   Sans clé Resend configurée, la fonction ne casse rien : elle répond
   qu'aucun envoi n'est possible, et la commande reste enregistrée.
*/
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPA = Deno.env.get("SUPABASE_URL");
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

function repondre(corps, statut = 200) {
  return new Response(JSON.stringify(corps), {
    status: statut,
    headers: { "content-type": "application/json" },
  });
}

async function base(chemin) {
  const r = await fetch(SUPA + "/rest/v1/" + chemin, {
    headers: { apikey: SERVICE, authorization: "Bearer " + SERVICE },
  });
  const t = await r.text();
  if (!r.ok) throw new Error("base " + r.status + " " + t.slice(0, 200));
  return t ? JSON.parse(t) : null;
}

/* Comparaison à durée constante : ne pas laisser deviner le secret. */
function memeSecret(a, b) {
  if (!a || !b || a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

function euros(n) {
  return (Math.round(Number(n || 0) * 100) / 100).toFixed(2).replace(".", ",") + " €";
}
function propre(s) {
  return String(s == null ? "" : s)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

Deno.serve(async (req) => {
  try {
    const q = await req.json().catch(() => null);
    if (!q || !q.commande_id) return repondre({ erreur: "commande_id manquant" }, 400);

    /* Seul un appelant porteur du secret partagé peut déclencher un envoi. */
    const attendu = (await base("app_settings?select=value&key=eq.notif_secret&limit=1"))[0];
    if (!attendu || !memeSecret(req.headers.get("x-solvia-secret") || "", attendu.value)) {
      return repondre({ erreur: "non autorisé" }, 401);
    }

    const c = (await base("commandes?select=*,commande_lignes(*)&id=eq." +
      encodeURIComponent(q.commande_id) + "&limit=1"))[0];
    if (!c) return repondre({ erreur: "commande introuvable" }, 404);

    const h = (await base("hotels?select=nom,slug&id=eq." + c.hotel_id + "&limit=1"))[0];
    const dest = (await base("hotel_integrations?select=valeur&hotel_id=eq." + c.hotel_id +
      "&code=eq.email_commandes&actif=is.true&limit=1"))[0];
    if (!dest || !dest.valeur) return repondre({ envoye: false, raison: "aucune adresse configurée" });

    const CLE = Deno.env.get("RESEND_API_KEY");
    if (!CLE) return repondre({ envoye: false, raison: "service d'envoi non configuré" });

    const lignes = (c.commande_lignes || []).map((l) => {
      const q2 = l.type === "pdj"
        ? l.nb_adulte + " adulte(s)" + (l.nb_enfant ? ", " + l.nb_enfant + " enfant(s)" : "")
        : "x" + l.quantite;
      const quand = l.date_service
        ? new Date(l.date_service + "T00:00:00").toLocaleDateString("fr-FR",
            { weekday: "long", day: "numeric", month: "long" })
        : "";
      return "<tr><td style='padding:6px 0'>" + propre(l.libelle) + " · " + propre(q2) +
        (quand ? " · <b>" + propre(quand) + "</b>" : "") +
        (l.heure_service ? " à " + propre(l.heure_service) : "") +
        "</td><td style='padding:6px 0;text-align:right;white-space:nowrap'>" +
        euros(l.total) + "</td></tr>";
    }).join("");

    const paye = c.paye_le
      ? "<p style='margin:14px 0 0;color:#2f7d5b;font-weight:700'>Déjà réglé en ligne</p>"
      : "<p style='margin:14px 0 0;color:#8a6524;font-weight:700'>À encaisser sur place</p>";

    /* Un numéro de chambre saisi par le client n'est pas une preuve : on le dit
       quand rien ne le confirme, pour que la réception vérifie avant de servir. */
    const doute = c.chambre_verifiee === false
      ? "<p style='margin:14px 0 0;padding:10px 12px;background:#fbeceb;border-radius:8px;" +
        "color:#a3372f;font-weight:700'>Chambre à confirmer : elle n'apparaît pas dans " +
        "vos arrivées du jour. Vérifiez avant de servir.</p>"
      : "";

    const html =
      "<div style=\"font-family:system-ui,-apple-system,Segoe UI,sans-serif;max-width:520px;" +
      "color:#2a2118;line-height:1.6\">" +
      "<p style='margin:0 0 4px;font-size:13px;color:#9b9184'>" + propre(h && h.nom) + "</p>" +
      "<h2 style='margin:0 0 2px;font-size:20px'>Chambre " + propre(c.chambre || "?") + "</h2>" +
      "<p style='margin:0 0 16px;font-size:13px;color:#9b9184'>Commande " + propre(c.reference) + "</p>" +
      "<table style='width:100%;border-collapse:collapse;font-size:14px'>" + lignes +
      "<tr><td style='padding:10px 0 0;border-top:1px solid #e8e2d9;font-weight:700'>Total</td>" +
      "<td style='padding:10px 0 0;border-top:1px solid #e8e2d9;text-align:right;font-weight:700'>" +
      euros(c.total) + "</td></tr></table>" + doute + paye +
      (c.nom || c.email
        ? "<p style='margin:16px 0 0;font-size:13px;color:#6b6154'>" +
          propre([c.nom, c.prenom].filter(Boolean).join(" ")) +
          (c.email ? " · " + propre(c.email) : "") + "</p>"
        : "") +
      (c.note ? "<p style='margin:10px 0 0;font-size:13px;color:#6b6154'>" + propre(c.note) + "</p>" : "") +
      "<p style='margin:22px 0 0;font-size:12px;color:#9b9184'>" +
      "<a href='https://guide.solvia.pro/espace/' style='color:#5b4a35'>Ouvrir mon espace</a></p></div>";

    const env = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { authorization: "Bearer " + CLE, "content-type": "application/json" },
      body: JSON.stringify({
        from: Deno.env.get("RESEND_FROM") || "SolvIA <commandes@solvia.pro>",
        to: [dest.valeur],
        subject: (c.chambre_verifiee === false ? "[à confirmer] " : "") +
          "Chambre " + (c.chambre || "?") + " · " + euros(c.total) + " · " + c.reference,
        html: html,
      }),
    });
    if (!env.ok) {
      const d = await env.text();
      console.error("resend", env.status, d.slice(0, 300));
      return repondre({ envoye: false, raison: "envoi refusé" }, 502);
    }
    return repondre({ envoye: true });
  } catch (e) {
    console.error("notifier", String((e && e.message) || e));
    return repondre({ erreur: "erreur interne" }, 500);
  }
});
