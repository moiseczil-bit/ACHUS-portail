import { creerCommunaute } from "./communaute.js";
import { creerCollaboration } from "./collaboration.js";
import {
  carteRecto, carteVerso, certificat, certificatAutorise, dateFR,
  telechargerCartePng, telechargerCartePdf, telechargerCertificatPdf, imprimerCertificat,
  EXEMPLE
} from "./documents.js";

const SUPA_URL = "https://hyktpddailftuwmbakdm.supabase.co";
const SUPA_KEY = "sb_publishable_9B8gTwnHPR5PtJokvusYVQ_3wSw0Mjr";

const STATUTS = [
  ["en_attente", "En attente"],
  ["actif", "Actif"],
  ["inactif", "Inactif"],
  ["suspendu", "Suspendu"],
  ["honoraire", "Honoraire"],
  ["refuse", "Refusé"]
];
const ROLES = [
  ["membre", "Membre"],
  ["bureau", "Bureau"],
  ["president", "Président"]
];

let supabase = null;
let session = null;
let profil = null;
let page = "accueil";
let affichageGeneration = 0;
let messagesTimer = null;
const collaboration = creerCollaboration({
  client: () => supabase, profil: () => profil, estBureau, libelleStatut, libelleRole,
  toast, sauverBlob, ouvrirDocuments,
  actualiser: async (id) => {
    await chargerProfil();
    remplirQui();
    construireNav();
    await afficher(id);
  }
});

const communaute = creerCommunaute({ client: () => supabase, profil: () => profil, estBureau, toast });

const $ = (id) => document.getElementById(id);

function texteErreur(e) {
  if (!e) return "Erreur inconnue.";
  if (typeof e === "string") return e;
  return e.message || e.error_description || e.details || "Erreur inconnue.";
}

let toastTimer = null;
function toast(msg, type) {
  const t = $("toast");
  t.hidden = false;
  t.className = "toast " + (type === "error" ? "err" : "ok");
  t.textContent = msg;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { t.hidden = true; }, 5000);
}

function msg(id, text, type) {
  const n = $(id);
  n.hidden = !text;
  n.className = "msg " + (type || "info");
  n.textContent = text || "";
}

function estBureau(p) {
  return !!p && p.statut === "actif" && (p.role === "president" || p.role === "bureau");
}

function libelleStatut(s) {
  return (STATUTS.find((x) => x[0] === s) || [s, s || "—"])[1];
}
function libelleRole(r) {
  return (ROLES.find((x) => x[0] === r) || [r, r || "Membre"])[1];
}

function el(tag, className, text) {
  const n = document.createElement(tag);
  if (className) n.className = className;
  if (text != null) n.textContent = text;
  return n;
}

function champ(label, node) {
  const w = el("label", "champ");
  w.append(el("span", null, label), node);
  return w;
}

function input(opts) {
  const n = document.createElement(opts.rows ? "textarea" : "input");
  if (!opts.rows) n.type = opts.type || "text";
  n.value = opts.value || "";
  if (opts.placeholder) n.placeholder = opts.placeholder;
  if (opts.id) n.id = opts.id;
  return n;
}

function select(options, value) {
  const n = document.createElement("select");
  options.forEach(([v, l]) => {
    const o = document.createElement("option");
    o.value = v;
    o.textContent = l;
    if (v === value) o.selected = true;
    n.append(o);
  });
  return n;
}

async function avecPhoto(m) {
  const copie = { ...m, photoUrl: "" };
  const path = m && m.photo_url;
  if (!path || !supabase) return copie;
  if (String(path).startsWith("http") || String(path).startsWith("data:")) {
    copie.photoUrl = path;
    return copie;
  }
  const { data, error } = await supabase.storage.from("photos-membres").createSignedUrl(path, 3600);
  if (error) {
    toast("Photo : " + texteErreur(error), "error");
    return copie;
  }
  copie.photoUrl = data.signedUrl;
  return copie;
}

function outilsCarte(m, opts) {
  const bar = el("div", "doc-outils");
  const png = el("button", "btn btn-ghost btn-sm", "Télécharger PNG");
  const pdf = el("button", "btn btn-navy btn-sm", "Télécharger PDF");
  png.style.width = "auto";
  pdf.style.width = "auto";
  png.onclick = () => telechargerCartePng(m).catch((e) => toast(texteErreur(e), "error"));
  pdf.onclick = () => telechargerCartePdf(m).catch((e) => toast(texteErreur(e), "error"));
  bar.append(png, pdf);
  if (opts && opts.impression && certificatAutorise(m)) {
    const pr = el("button", "btn btn-ghost btn-sm", "Imprimer le certificat");
    pr.onclick = () => imprimerCertificat(m);
    bar.append(pr);
  }
  return bar;
}

function samedis(n) {
  const out = [];
  const start = new Date();
  for (let i = 0; i < 70 && out.length < n; i++) {
    const d = new Date(start.getTime() + i * 86400000);
    const wd = new Intl.DateTimeFormat("en-US", { timeZone: "America/Port-au-Prince", weekday: "short" }).format(d);
    if (wd === "Sat") out.push(d);
  }
  return out;
}

function prochain18Mai() {
  const annee = Number(new Intl.DateTimeFormat("en-US", { timeZone: "America/Port-au-Prince", year: "numeric" }).format(new Date()));
  const aujourd = new Intl.DateTimeFormat("fr-CA", { timeZone: "America/Port-au-Prince" }).format(new Date());
  const cette = annee + "-05-18";
  return aujourd <= cette ? cette : (annee + 1) + "-05-18";
}

function blocAgenda(evenements) {
  const wrap = el("div");
  const items = [];
  const connus = new Set((evenements || []).map((e) => e.titre));
  samedis(6).forEach((d) => {
    items.push({
      quand: d.toLocaleDateString("fr-FR", { weekday: "long", day: "numeric", month: "long", year: "numeric" }) + " · 9 h 00",
      titre: "Réunion hebdomadaire",
      lieu: "Santo 13, Croix-des-Bouquets",
      detail: "Chaque samedi à 9 h."
    });
  });
  const mai = prochain18Mai();
  items.push({
    quand: dateFR(mai) + " · 9 h 00",
    titre: "Fête du Drapeau",
    lieu: "Santo 13, Croix-des-Bouquets",
    detail: "Célébration annuelle, le 18 mai."
  });
  (evenements || []).forEach((e) => {
    if (e.titre === "Fête du Drapeau" || e.titre === "Réunion hebdomadaire") return;
    items.push({
      quand: e.date_debut ? dateFR(e.date_debut) : (e.recurrence || ""),
      titre: e.titre,
      lieu: e.lieu || "",
      detail: e.description || ""
    });
  });
  if (!connus.size) {
    /* les deux rendez-vous fixes sont déjà affichés */
  }
  items.forEach((it) => {
    const c = el("article", "carte-info");
    c.append(el("div", "meta", it.quand), el("h3", null, it.titre));
    if (it.lieu) c.append(el("div", "meta", it.lieu));
    if (it.detail) c.append(el("p", null, it.detail));
    wrap.append(c);
  });
  return wrap;
}

function contactsNode() {
  const c = el("div", "contacts");
  c.append(el("h2", null, "Contacter l'ACHUS"));
  const tel = document.createElement("a");
  tel.href = "https://wa.me/50939180332";
  tel.target = "_blank";
  tel.rel = "noopener";
  tel.textContent = "WhatsApp · +509 39 18 0332";
  const mail = document.createElement("a");
  mail.href = "mailto:achushaiti@gmail.com";
  mail.textContent = "achushaiti@gmail.com";
  c.append(tel, mail);
  c.append(el("p", "meta", "Santo 13, Croix-des-Bouquets, Haïti"));
  return c;
}

async function chargerEvenements() {
  if (!supabase) return [];
  const { data, error } = await supabase.from("evenements").select("*").order("date_debut", { ascending: true });
  if (error) {
    toast("Agenda : " + texteErreur(error), "error");
    return [];
  }
  return data || [];
}

async function pageAccueil() {
  const root = el("div");
  if (!profil) {
    const b = el("div", "msg info", "Aucune fiche n'est liée à ce compte. Écrivez au bureau : achushaiti@gmail.com.");
    root.append(b, contactsNode());
    return root;
  }
  if (profil.statut === "en_attente") {
    root.append(el("div", "msg info", "Votre demande d'adhésion est en attente. Le bureau la verra dans le tableau des demandes. Vous serez prévenu après la décision."));
  } else if (profil.statut === "refuse") {
    root.append(el("div", "msg err", "Votre demande a été refusée. Vous pouvez écrire au bureau pour en parler."));
  } else if (profil.statut === "suspendu" || profil.statut === "inactif") {
    root.append(el("div", "msg info", "Votre statut actuel : " + libelleStatut(profil.statut) + "."));
  }
  const grille = el("div", "grille grille-2");
  const gauche = el("div", "carte-info");
  gauche.append(el("h3", null, "Ma situation"));
  gauche.append(el("p", null, (profil.prenom || "") + " " + (profil.nom || "")));
  const badges = el("p");
  const b = el("span", "badge b-" + (profil.statut || "inactif"), libelleStatut(profil.statut));
  badges.append(b, " · " + libelleRole(profil.role));
  gauche.append(badges);
  gauche.append(el("p", null, "N° " + (profil.numero_membre || "pas encore attribué")));
  gauche.append(el("p", "meta", (profil.grade || "") + (profil.fonction ? " · " + profil.fonction : "")));
  const droit = el("div");
  droit.append(el("h3", null, "Prochains rendez-vous"));
  const ev = await chargerEvenements();
  droit.append(blocAgenda(ev));
  grille.append(gauche, droit);
  root.append(grille, contactsNode());
  return root;
}

async function pageProfil() {
  const root = el("div");
  if (!profil) {
    root.append(el("div", "msg err", "Fiche introuvable."));
    return root;
  }
  const form = el("form", "panneau");
  const prenom = input({ value: profil.prenom || "" });
  const nom = input({ value: profil.nom || "" });
  const tel = input({ value: profil.telephone || "", type: "tel" });
  const wa = input({ value: profil.whatsapp || "", type: "tel" });
  const quartier = input({ value: profil.quartier || "" });
  const adresse = input({ value: profil.adresse || "" });
  const programme = input({ value: profil.programme_interet || "" });
  const motivation = input({ value: profil.motivation || "", rows: 4 });
  form.append(
    champ("Prénom", prenom),
    champ("Nom", nom),
    champ("Téléphone", tel),
    champ("WhatsApp", wa),
    champ("Quartier", quartier),
    champ("Adresse", adresse),
    champ("Programme d'intérêt", programme),
    champ("Motivation", motivation)
  );
  const sauver = el("button", "btn btn-navy", "Enregistrer");
  sauver.type = "submit";
  form.append(sauver);
  form.onsubmit = async (e) => {
    e.preventDefault();
    const payload = {
      prenom: prenom.value.trim(),
      nom: nom.value.trim(),
      telephone: tel.value.trim(),
      whatsapp: wa.value.trim(),
      quartier: quartier.value.trim(),
      adresse: adresse.value.trim(),
      programme_interet: programme.value.trim(),
      motivation: motivation.value.trim()
    };
    const { data, error } = await supabase.from("membres").update(payload).eq("id", profil.id).select("*").maybeSingle();
    if (error) {
      toast(texteErreur(error), "error");
      return;
    }
    profil = data || { ...profil, ...payload };
    toast("Profil enregistré.");
    remplirQui();
  };
  const photoForm = el("div", "panneau");
  photoForm.style.marginTop = "12px";
  photoForm.append(el("h3", null, "Photo pour la carte"));
  const file = input({ type: "file" });
  file.accept = "image/*";
  const go = el("button", "btn btn-ghost", "Envoyer la photo");
  go.type = "button";
  go.style.marginTop = "8px";
  go.onclick = () => envoyerPhoto(file);
  photoForm.append(file, go);
  const lecture = el("div", "carte-info");
  lecture.style.marginTop = "12px";
  lecture.append(
    el("p", null, "Statut : " + libelleStatut(profil.statut)),
    el("p", null, "Numéro : " + (profil.numero_membre || "en attente d'approbation")),
    el("p", null, "Grade : " + (profil.grade || "—") + " · Fonction : " + (profil.fonction || "—")),
    el("p", null, "Membre depuis le : " + (profil.date_adhesion ? dateFR(profil.date_adhesion) : "—")),
    el("p", null, "Carte valable jusqu'au : " + (profil.date_validite ? dateFR(profil.date_validite, "slash") : "—"))
  );
  const riche = await avecPhoto(profil);
  const docs = el("div");
  docs.style.marginTop = "16px";
  docs.append(el("h3", null, "Carte de membre"));
  docs.append(outilsCarte(riche));
  docs.append(carteRecto(riche), el("div", null), carteVerso(riche));
  docs.append(el("h3", null, "Certificat"));
  if (certificatAutorise(profil)) {
    const pdf = el("button", "btn btn-navy btn-sm", "Télécharger le certificat (PDF)");
    pdf.onclick = () => telechargerCertificatPdf(riche).catch((e) => toast(texteErreur(e), "error"));
    docs.append(pdf, certificat(riche));
  } else {
    docs.append(el("p", "meta", "Le certificat est disponible pour les membres actifs ou honoraires qui ont un numéro."));
  }
  if (["actif", "honoraire"].includes(profil.statut) && profil.type_compte !== "parent") {
    const gradeForm = el("form", "panneau");
    gradeForm.style.marginBottom = "12px";
    gradeForm.append(el("h3", null, "Mon grade"));
    const grade = input({ value: profil.grade || "" });
    grade.required = true; grade.maxLength = 80; grade.placeholder = "Ex. : Sergent";
    gradeForm.append(champ("Grade à afficher sur ma carte", grade),
      el("p", "meta", "Indiquez votre grade ACHUS. Après enregistrement, votre carte et votre certificat sont actualisés. Ce choix ne change pas vos droits dans le portail."));
    const enregistrerGrade = el("button", "btn btn-navy", "Enregistrer mon grade");
    enregistrerGrade.type = "submit"; gradeForm.append(enregistrerGrade);
    gradeForm.onsubmit = async e => {
      e.preventDefault(); enregistrerGrade.disabled = true;
      try {
        const { error } = await supabase.rpc("modifier_mon_grade", { p_grade: grade.value.trim() });
        if (error) throw error;
        await chargerProfil();
        if (gradeForm.isConnected && page === "profil") await afficher("profil");
        toast("Grade enregistré. Votre carte est actualisée.");
      } catch (e) { toast(texteErreur(e), "error"); }
      finally { enregistrerGrade.disabled = false; }
    };
    root.append(gradeForm);
  }
  root.append(form, photoForm, lecture, docs);
  return root;
}

async function envoyerPhoto(fileInput) {
  const file = fileInput.files && fileInput.files[0];
  if (!file) {
    toast("Choisissez une image.", "error");
    return;
  }
  if (file.size > 5 * 1024 * 1024) {
    toast("Image trop lourde (maximum 5 Mo).", "error");
    return;
  }
  const ext = (file.name.split(".").pop() || "jpg").toLowerCase().replace(/[^a-z0-9]/g, "") || "jpg";
  const path = session.user.id + "/" + Date.now() + "." + ext;
  const up = await supabase.storage.from("photos-membres").upload(path, file, {
    upsert: true,
    contentType: file.type || "image/jpeg"
  });
  if (up.error) {
    toast("Envoi impossible : " + texteErreur(up.error), "error");
    return;
  }
  const { data, error } = await supabase.from("membres").update({ photo_url: path }).eq("id", profil.id).select("*").maybeSingle();
  if (error) {
    toast(texteErreur(error), "error");
    return;
  }
  profil = data || profil;
  profil.photo_url = path;
  toast("Photo enregistrée.");
  await afficher("profil");
}

async function pageAgenda() {
  const root = el("div");
  root.append(el("p", "meta", "Les réunions ont lieu chaque samedi à 9 h. La Fête du Drapeau est le 18 mai."));
  root.append(blocAgenda(await chargerEvenements()));
  return root;
}

function carteDemande(m, apercu) {
  const c = el("article", "demande");
  c.append(el("h3", null, ((m.prenom || "") + " " + (m.nom || "")).trim() || "Sans nom"));
  c.append(el("p", "meta", (m.email || "") + (m.telephone ? " · " + m.telephone : "")));
  c.append(el("p", null, "Quartier : " + (m.quartier || "—")));
  c.append(el("p", null, "Programme : " + (m.programme_interet || "—")));
  c.append(el("p", null, "Motivation : " + (m.motivation || "—")));
  c.append(el("p", "meta", m.created_at ? dateFR(m.created_at) : ""));
  const bar = el("div", "ligne-btns");
  const ok = el("button", "btn btn-ok btn-sm", "Approuver");
  const no = el("button", "btn btn-red btn-sm", "Refuser");
  ok.onclick = () => decider("approuver_membre", m, apercu);
  no.onclick = () => decider("refuser_membre", m, apercu);
  bar.append(ok, no);
  c.append(bar);
  return c;
}

async function decider(fn, m, apercu) {
  if (apercu) {
    toast("Aperçu seulement — rien n'est envoyé.");
    return;
  }
  const { error } = await supabase.rpc(fn, { p_id: m.id });
  if (error) {
    toast(texteErreur(error), "error");
    return;
  }
  toast(fn === "approuver_membre" ? "Membre approuvé. Un numéro ACHUS lui a été donné." : "Demande refusée.");
  await afficher("demandes");
}

async function pageDemandes(apercu) {
  const root = el("div");
  let rows = [];
  if (apercu) {
    rows = [
      {
        id: "apercu-1", prenom: "Marie", nom: "Joseph", email: "marie.joseph@example.com",
        telephone: "+509 3456 7890", quartier: "Santo 13", programme_interet: "Leadership",
        motivation: "Je veux servir la jeunesse de Santo avec discipline et honneur.",
        created_at: "2026-11-02", statut: "en_attente"
      },
      {
        id: "apercu-2", prenom: "Pierre", nom: "Louis", email: "pierre.louis@example.com",
        telephone: "+509 4123 0000", quartier: "Croix-des-Bouquets", programme_interet: "Musique",
        motivation: "Rejoindre la fanfare et les cérémonies du drapeau.",
        created_at: "2026-11-03", statut: "en_attente"
      }
    ];
  } else {
    const { data, error } = await supabase.from("membres").select("*").eq("statut", "en_attente").order("created_at", { ascending: true });
    if (error) {
      root.append(el("div", "msg err", texteErreur(error)));
      return root;
    }
    rows = data || [];
  }
  const badge = $("pastille");
  if (badge) badge.textContent = String(rows.length);
  if (!rows.length) root.append(el("p", "meta", "Aucune demande en attente."));
  rows.forEach((m) => root.append(carteDemande(m, apercu)));
  return root;
}

function sauverBlob(blob, nom) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = nom;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

async function ouvrirDocuments(m) {
  const riche = await avecPhoto(m);
  const modal = $("modal");
  const corps = el("div", "modal-carte");
  const fermer = el("button", "btn btn-ghost btn-sm", "Fermer");
  fermer.onclick = () => { modal.hidden = true; modal.replaceChildren(); };
  corps.append(el("h3", null, riche.prenom + " " + riche.nom), fermer, outilsCarte(riche, { impression: true }));
  corps.append(carteRecto(riche), carteVerso(riche));
  if (certificatAutorise(m)) {
    const pdf = el("button", "btn btn-navy btn-sm", "Télécharger le certificat (PDF)");
    const imp = el("button", "btn btn-ghost btn-sm", "Imprimer");
    pdf.onclick = () => telechargerCertificatPdf(riche).catch((e) => toast(texteErreur(e), "error"));
    imp.onclick = () => imprimerCertificat(riche);
    const bar = el("div", "doc-outils");
    bar.append(pdf, imp);
    corps.append(el("h3", null, "Certificat"), bar, certificat(riche));
  } else {
    corps.append(el("p", "meta", "Certificat réservé aux membres actifs ou honoraires ayant un numéro."));
  }
  modal.replaceChildren(corps);
  modal.hidden = false;
}

async function pageAnnonces() {
  const root = el("div");
  const form = el("form", "panneau");
  const titre = input({ placeholder: "Titre" });
  const contenu = input({ rows: 4, placeholder: "Texte de l'annonce" });
  const go = el("button", "btn btn-navy", "Publier");
  go.type = "submit";
  form.append(champ("Titre", titre), champ("Contenu", contenu), go);
  const liste = el("div");
  form.onsubmit = async (e) => {
    e.preventDefault();
    if (!titre.value.trim() || !contenu.value.trim()) {
      toast("Titre et contenu sont obligatoires.", "error");
      return;
    }
    const { error } = await supabase.from("annonces").insert({
      titre: titre.value.trim(),
      contenu: contenu.value.trim(),
      auteur_id: profil.id
    });
    if (error) {
      toast(texteErreur(error), "error");
      return;
    }
    toast("Annonce publiée.");
    await afficher("annonces");
  };
  const { data, error } = await supabase.from("annonces").select("*").order("created_at", { ascending: false });
  if (error) liste.append(el("div", "msg err", texteErreur(error)));
  if (!error && !data?.length) liste.append(el("p", "meta", "Aucune annonce publiée pour le moment."));
  (data || []).forEach((a) => {
    const c = el("article", "carte-info");
    c.append(el("h3", null, a.titre), el("p", null, a.contenu || ""), el("p", "meta", a.created_at ? dateFR(a.created_at) : ""));
    const del = el("button", "btn btn-red btn-sm", "Supprimer");
    del.onclick = async () => {
      const res = await supabase.from("annonces").delete().eq("id", a.id);
      if (res.error) toast(texteErreur(res.error), "error");
      else { toast("Annonce supprimée."); await afficher("annonces"); }
    };
    if (estBureau(profil)) c.append(del);
    liste.append(c);
  });
  if (estBureau(profil)) root.append(form);
  root.append(liste);
  return root;
}

async function pageAgendaAdmin() {
  const root = el("div");
  const form = el("form", "panneau");
  const titre = input({ placeholder: "Titre" });
  const description = input({ rows: 3 });
  const date = input({ type: "datetime-local" });
  const lieu = input({ value: "Santo 13, Croix-des-Bouquets" });
  const recurrence = select([
    ["", "Une seule fois"],
    ["hebdomadaire:samedi:09:00", "Chaque samedi à 9 h"],
    ["annuelle:05-18", "Chaque 18 mai"]
  ], "");
  const go = el("button", "btn btn-navy", "Ajouter à l'agenda");
  go.type = "submit";
  form.append(
    champ("Titre", titre),
    champ("Description", description),
    champ("Date et heure", date),
    champ("Lieu", lieu),
    champ("Répétition", recurrence),
    go
  );
  form.onsubmit = async (e) => {
    e.preventDefault();
    if (!titre.value.trim()) {
      toast("Indiquez un titre.", "error");
      return;
    }
    const { error } = await supabase.from("evenements").insert({
      titre: titre.value.trim(),
      description: description.value.trim(),
      date_debut: date.value ? new Date(date.value).toISOString() : null,
      lieu: lieu.value.trim(),
      recurrence: recurrence.value || null
    });
    if (error) {
      toast(texteErreur(error), "error");
      return;
    }
    toast("Événement ajouté.");
    await afficher("agenda-admin");
  };
  const { data, error } = await supabase.from("evenements").select("*").order("titre");
  const liste = el("div");
  if (error) liste.append(el("div", "msg err", texteErreur(error)));
  (data || []).forEach((ev) => {
    const c = el("article", "carte-info");
    c.append(el("h3", null, ev.titre), el("p", null, ev.description || ""), el("p", "meta", (ev.lieu || "") + (ev.recurrence ? " · " + ev.recurrence : "")));
    const del = el("button", "btn btn-red btn-sm", "Supprimer");
    del.onclick = async () => {
      const res = await supabase.from("evenements").delete().eq("id", ev.id);
      if (res.error) toast(texteErreur(res.error), "error");
      else { toast("Événement supprimé."); await afficher("agenda-admin"); }
    };
    c.append(del);
    liste.append(c);
  });
  root.append(form, liste);
  return root;
}

const TITRES = {
  fil: ["Communauté ACHUS", "Publications et échanges entre membres"],
  appels: ["Appels audio et vidéo", "Invitations privées et conversation sur Jitsi"],
  reunions: ["Réunions en ligne", "Retrouver les membres et les responsables"],
  famille: ["Espace parents", "Liens familiaux et suivi des présences"],
  accueil: ["Accueil", "Association Corps d'Honneur Universel de Santo"],
  profil: ["Mon profil", "Vos informations, votre photo, votre carte"],
  agenda: ["Agenda", "Samedi 9 h et 18 mai"],
  presences: ["Mes présences", "Déclaration et suivi des validations"],
  messages: ["Messagerie", "Échanges privés entre membres actifs"],
  "presences-admin": ["Valider les présences", "Par réunion et par membre"],
  journal: ["Journal du bureau", "Historique des actions administratives"],
  demandes: ["Demandes", "Adhésions en attente"],
  registre: ["Registre", "Statuts, grades, export"],
  annonces: ["Annonces", "Messages aux membres"],
  "agenda-admin": ["Gérer l'agenda", "Rendez-vous"]
};

async function afficher(id) {
  const generation = ++affichageGeneration;
  if (["demandes", "registre", "agenda-admin", "presences-admin", "journal"].includes(id) && !estBureau(profil)) id = "accueil";
  page = id;
  document.querySelectorAll(".nav-btn").forEach((b) => b.classList.toggle("actif", b.dataset.page === id));
  const t = TITRES[id] || [id, ""];
  $("titre-page").textContent = t[0];
  $("sous-titre").textContent = t[1];
  const contenu = $("contenu");
  contenu.setAttribute("aria-busy", "true");
  contenu.replaceChildren(el("p", "meta", "Chargement…"));
  try {
    let node;
    if (id === "accueil") node = await pageAccueil();
    else if (id === "profil") node = await pageProfil();
    else if (id === "agenda") node = await pageAgenda();
    else if (["fil", "appels", "reunions", "famille"].includes(id)) node = await communaute[id]();
    else if (id === "presences") node = await collaboration.presences();
    else if (id === "messages") node = await collaboration.messages();
    else if (id === "presences-admin") node = await collaboration.presencesAdmin();
    else if (id === "journal") node = await collaboration.journal();
    else if (id === "demandes") node = await pageDemandes(false);
    else if (id === "registre") node = await collaboration.registre();
    else if (id === "annonces") node = await pageAnnonces();
    else if (id === "agenda-admin") node = await pageAgendaAdmin();
    else node = el("p", null, "Page inconnue.");
    if (generation !== affichageGeneration) return;
    contenu.replaceChildren(node);
    contenu.setAttribute("aria-busy", "false");
    collaboration.badgeMessages();
    communaute.badgeAppels();
  } catch (e) {
    if (generation === affichageGeneration) {
      contenu.replaceChildren(el("div", "msg err", texteErreur(e)));
      contenu.setAttribute("aria-busy", "false");
    }
  }
}

function remplirQui() {
  const nom = profil ? ((profil.prenom || "") + " " + (profil.nom || "")).trim() : (session ? session.user.email : "");
  $("qui-nom").textContent = nom || "Membre";
  $("qui-role").textContent = profil ? (libelleRole(profil.role) + " · " + libelleStatut(profil.statut)) : "Sans fiche";
}

function construireNav() {
  const nav = $("nav");
  nav.replaceChildren();
  const items = [
    ["Principal", [["accueil", "Accueil"], ["profil", "Mon profil"], ["agenda", "Agenda"], ["presences", "Mes présences"]]]
  ];
  if (["actif", "honoraire"].includes(profil?.statut)) {
    items[0][1].push(["fil", "Communauté"], ["reunions", "Réunions en ligne"]);
    if (profil.statut === "actif") items[0][1].push(["appels", "Appels audio et vidéo"]);
    if (profil.type_compte === "parent" || estBureau(profil)) items[0][1].push(["famille", "Espace parents"]);
  }
  if (profil?.statut === "actif") items[0][1].push(["messages", "Messagerie"]);
  if (["actif", "honoraire"].includes(profil?.statut) && !estBureau(profil)) items[0][1].push(["annonces", "Annonces du bureau"]);
  if (estBureau(profil)) {
    items.push(["Bureau", [
      ["demandes", "Demandes"],
      ["registre", "Registre des membres"],
      ["presences-admin", "Valider les présences"],
      ["journal", "Journal du bureau"],
      ["annonces", "Annonces"],
      ["agenda-admin", "Gérer l'agenda"]
    ]]);
  }
  items.forEach(([sec, liens]) => {
    nav.append(el("div", "nav-sec", sec));
    liens.forEach(([id, label]) => {
      const b = el("button", "nav-btn", label);
      b.dataset.page = id;
      b.type = "button";
      if (id === "demandes") {
        const pastille = el("span", "badge b-en_attente", "0");
        pastille.id = "pastille";
        pastille.style.marginLeft = "8px";
        b.append(pastille);
      }
      if (id === "appels") {
        const badge = el("span", "badge b-en_attente", "0");
        badge.id = "appels-entrants"; badge.hidden = true; b.append(badge);
      }
      if (id === "messages") {
        const badge = el("span", "badge b-en_attente", "0");
        badge.id = "non-lus";
        badge.hidden = true;
        b.append(badge);
      }
      b.onclick = () => afficher(id);
      nav.append(b);
    });
  });
}

async function chargerProfil() {
  const { data, error } = await supabase.from("membres").select("*").eq("user_id", session.user.id).maybeSingle();
  if (error) throw error;
  profil = data;
}

async function entrer() {
  await chargerProfil();
  $("ecran-auth").hidden = true;
  $("ecran-app").hidden = false;
  remplirQui();
  construireNav();
  await afficher("accueil");
  clearInterval(messagesTimer);
  messagesTimer = setInterval(() => {
    if (session && document.visibilityState === "visible") { collaboration.badgeMessages(); communaute.badgeAppels(); }
  }, 60000);
  if (estBureau(profil)) {
    const { count, error } = await supabase.from("membres").select("id", { count: "exact", head: true }).eq("statut", "en_attente");
    const pastille = $("pastille");
    if (pastille && !error) pastille.textContent = String(count || 0);
  }
}

async function sortir() {
  clearInterval(messagesTimer);
  ++affichageGeneration;
  document.querySelectorAll("dialog.dialog-portail").forEach(d => d.close());
  $("contenu").replaceChildren();
  $("modal").hidden = true;
  $("modal").replaceChildren();
  if (supabase) await supabase.auth.signOut();
  session = null;
  profil = null;
  $("ecran-app").hidden = true;
  $("ecran-auth").hidden = false;
}

function traduireAuth(message) {
  const m = message || "";
  if (/invalid login/i.test(m)) return "E-mail ou mot de passe incorrect.";
  if (/already registered/i.test(m)) return "Un compte existe déjà avec cet e-mail. Connectez-vous.";
  if (/password/i.test(m) && /6|least/i.test(m)) return "Le mot de passe doit contenir au moins 6 caractères.";
  if (/email not confirmed/i.test(m)) return "Confirmez d'abord votre e-mail (regardez aussi les courriers indésirables), puis connectez-vous.";
  return m;
}

function lierAuth() {
  $("tab-login").onclick = () => {
    $("form-login").hidden = false;
    $("form-adhesion").hidden = true;
    $("tab-login").classList.add("actif");
    $("tab-adhesion").classList.remove("actif");
  };
  $("tab-adhesion").onclick = () => {
    $("form-login").hidden = true;
    $("form-adhesion").hidden = false;
    $("tab-adhesion").classList.add("actif");
    $("tab-login").classList.remove("actif");
  };
  $("form-login").onsubmit = async (e) => {
    e.preventDefault();
    msg("login-msg", "Connexion…", "info");
    const { data, error } = await supabase.auth.signInWithPassword({
      email: $("login-email").value.trim(),
      password: $("login-password").value
    });
    if (error) {
      msg("login-msg", traduireAuth(texteErreur(error)), "err");
      return;
    }
    session = data.session;
    msg("login-msg", "", "info");
    try {
      await entrer();
    } catch (err) {
      msg("login-msg", texteErreur(err), "err");
    }
  };
  $("form-adhesion").onsubmit = async (e) => {
    e.preventDefault();
    const prenom = $("reg-prenom").value.trim();
    const nom = $("reg-nom").value.trim();
    const email = $("reg-email").value.trim();
    const password = $("reg-password").value;
    const telephone = $("reg-tel").value.trim();
    const quartier = $("reg-quartier").value.trim();
    const programme = $("reg-programme").value.trim();
    const motivation = $("reg-motivation").value.trim();
    if (!prenom || !nom || !email || !password || !telephone || !quartier) {
      msg("reg-msg", "Remplissez le prénom, le nom, le téléphone, l'e-mail, le mot de passe et le quartier.", "err");
      return;
    }
    if (password.length < 6) {
      msg("reg-msg", "Le mot de passe doit contenir au moins 6 caractères.", "err");
      return;
    }
    msg("reg-msg", "Envoi de la demande…", "info");
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          prenom,
          nom,
          telephone,
          quartier,
          programme_interet: programme,
          motivation,
          type_compte: $("reg-parent").checked ? "parent" : "membre"
        }
      }
    });
    if (error) {
      msg("reg-msg", traduireAuth(texteErreur(error)), "err");
      return;
    }
    if (data.session) {
      session = data.session;
      msg("reg-msg", "Demande enregistrée. Elle est en attente de validation par le bureau.", "ok");
      try { await entrer(); } catch (err) { msg("reg-msg", texteErreur(err), "err"); }
      return;
    }
    msg("reg-msg", "Demande enregistrée. Ouvrez le message de confirmation envoyé à votre e-mail (vérifiez les indésirables), puis connectez-vous. Le bureau verra votre demande même avant cette confirmation.", "ok");
  };
  $("btn-logout").onclick = () => sortir();
}

function montrerAdhesion() {
  $("form-login").hidden = true;
  $("form-adhesion").hidden = false;
  $("tab-adhesion").classList.add("actif");
  $("tab-login").classList.remove("actif");
}

async function apercu() {
  const h = location.hash.replace("#", "");
  $("ecran-auth").hidden = true;
  $("ecran-app").hidden = true;
  if (h === "apercu-adhesion") {
    $("ecran-auth").hidden = false;
    montrerAdhesion();
    return;
  }
  if (h === "apercu-demandes") {
    $("ecran-app").hidden = false;
    $("qui-nom").textContent = "Moïse-Son Sorel Cezil";
    $("qui-role").textContent = "Président · Actif";
    const nav = $("nav");
    nav.replaceChildren(el("div", "nav-sec", "Bureau"));
    const b = el("button", "nav-btn actif", "Demandes");
    const pastille = el("span", "badge b-en_attente", "2");
    pastille.id = "pastille";
    pastille.style.marginLeft = "8px";
    b.append(pastille);
    nav.append(b);
    $("titre-page").textContent = "Demandes";
    $("sous-titre").textContent = "Adhésions en attente";
    $("contenu").replaceChildren(await pageDemandes(true));
    return;
  }
  const zone = el("div", "apercu-page");
  document.body.append(zone);
  if (h === "apercu-carte-recto") {
    zone.append(el("h2", null, "Carte — recto"), carteRecto(EXEMPLE));
  } else if (h === "apercu-carte-verso") {
    zone.append(el("h2", null, "Carte — verso"), carteVerso(EXEMPLE));
  } else if (h === "apercu-certificat") {
    zone.append(el("h2", null, "Certificat"), certificat(EXEMPLE));
  }
}

async function demarrer() {
  if (location.hash.startsWith("#apercu")) {
    await apercu();
    return;
  }
  document.querySelectorAll("[data-mot-de-passe]").forEach(bouton => {
    bouton.onclick = () => {
      const controle = document.getElementById(bouton.dataset.motDePasse);
      const visible = controle.type === "password";
      controle.type = visible ? "text" : "password";
      bouton.textContent = visible ? "Masquer le mot de passe" : "Afficher le mot de passe";
      bouton.setAttribute("aria-pressed", String(visible));
    };
  });
  lierAuth();
  if (location.hash === "#adhesion") montrerAdhesion();
  const { createClient } = await import("https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.49.4/+esm");
  supabase = createClient(SUPA_URL, SUPA_KEY, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true
    }
  });
  const { data, error } = await supabase.auth.getSession();
  if (error) {
    msg("login-msg", texteErreur(error), "err");
    return;
  }
  if (data.session) {
    session = data.session;
    try { await entrer(); }
    catch (err) { msg("login-msg", texteErreur(err), "err"); }
  }
}

demarrer().catch((e) => {
  const t = $("toast");
  if (t) {
    t.hidden = false;
    t.className = "toast err";
    t.textContent = texteErreur(e);
  }
});
