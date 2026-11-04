const ECUS = "/assets/ecusson.png";
const PRESIDENT = "Moïse-Son Sorel Cezil";

function el(tag, className, text) {
  const n = document.createElement(tag);
  if (className) n.className = className;
  if (text != null) n.textContent = text;
  return n;
}

function bands(root) {
  ["band-tr-navy", "band-tr-red", "band-bl-navy", "band-bl-red"].forEach((c) => {
    root.append(el("div", "band " + c));
  });
}

export function dateFR(iso, mode) {
  if (!iso) return "—";
  const brut = String(iso).slice(0, 10);
  const d = new Date(brut + "T12:00:00");
  if (Number.isNaN(d.getTime())) return "—";
  if (mode === "slash") {
    return d.toLocaleDateString("fr-FR", { day: "2-digit", month: "2-digit", year: "numeric" });
  }
  return d.toLocaleDateString("fr-FR", { day: "numeric", month: "long", year: "numeric" });
}

export function vueMembre(m) {
  const src = m || {};
  const prenom = (src.prenom || "").trim();
  const nom = (src.nom || "").trim();
  const numero = src.numero_membre || src.matricule || "";
  const photo = src.photoUrl || "";
  const adresse = src.adresse || src.quartier || "Santo 13, Croix-des-Bouquets, Haïti";
  return {
    prenom,
    nom,
    nomComplet: [prenom, nom].filter(Boolean).join(" ") || "—",
    grade: (src.grade || "—").toString(),
    fonction: (src.fonction || "—").toString(),
    numero,
    email: src.email || "",
    telephone: src.telephone || "+509 39 18 0332",
    adresse,
    photo: typeof photo === "string" && (photo.startsWith("http") || photo.startsWith("data:")) ? photo : "",
    adhesion: src.date_adhesion || "",
    validite: src.date_validite || "",
    emission: src.date_emission || new Date().toISOString().slice(0, 10),
    statut: src.statut || ""
  };
}

export function certificatAutorise(m) {
  const v = vueMembre(m);
  return !!v.numero && (m.statut === "actif" || m.statut === "honoraire");
}

function photoBox(url) {
  const box = el("div", "photo");
  if (url) {
    const img = document.createElement("img");
    img.alt = "Photo du membre";
    img.src = url;
    img.crossOrigin = "anonymous";
    box.append(img);
  } else {
    box.append(el("span", "photo-vide", "PHOTO"));
  }
  return box;
}

function enteteMarque() {
  const head = el("div", "carte-head");
  const img = document.createElement("img");
  img.src = ECUS;
  img.alt = "Écusson ACHUS";
  img.className = "ecusson";
  const txt = el("div");
  txt.append(el("div", "wordmark", "ACHUS"));
  txt.append(el("div", "orgline", "Association Corps d'Honneur Universel"));
  head.append(img, txt);
  return head;
}

export function carteRecto(m) {
  const v = vueMembre(m);
  const root = el("article", "doc-carte");
  root.dataset.face = "recto";
  bands(root);
  root.append(enteteMarque());
  root.append(el("div", "rule rule-top"));
  const main = el("div", "carte-main");
  const id = el("div", "identite");
  const titre = el("h2");
  if (v.prenom) titre.append(v.prenom.toUpperCase(), document.createElement("br"));
  titre.append((v.nom || v.nomComplet).toUpperCase());
  id.append(titre);
  const g = el("p", "gv");
  g.append("Grade : ", el("b", null, v.grade.toUpperCase()));
  const f = el("p", "gv");
  f.append("Fonction : ", el("b", null, v.fonction.toUpperCase()));
  id.append(g, f);
  main.append(photoBox(v.photo), id);
  root.append(main);
  root.append(el("div", "rule rule-bot"));
  const foot = el("div", "carte-foot");
  foot.append(el("div", "num", "N° de membre : " + (v.numero || "en attente")));
  foot.append(el("div", "kind", "CARTE DE MEMBRE"));
  root.append(foot);
  return root;
}

export function carteVerso(m) {
  const v = vueMembre(m);
  const root = el("article", "doc-carte");
  root.dataset.face = "verso";
  bands(root);
  root.append(el("div", "rule rule-top"));
  root.append(el("div", "rule rule-bot"));
  const head = el("div", "v-head");
  head.append(el("div", "wordmark", "ACHUS"));
  head.append(el("div", "orgline", "Association Corps d'Honneur Universel de Santo"));
  const body = el("div", "v-body");
  const lignes = [
    ["Titulaire", v.nomComplet],
    ["N° de membre", v.numero || "—"],
    ["Valide jusqu'au", v.validite ? dateFR(v.validite, "slash") : "—"],
    ["Téléphone", v.telephone],
    ["Courriel", v.email || "achushaiti@gmail.com"],
    ["Adresse", v.adresse]
  ];
  lignes.forEach(([k, val]) => {
    const row = el("div", "v-row");
    row.append(el("div", "v-k", k), el("div", "v-v", val));
    body.append(row);
  });
  root.append(head, body, el("div", "v-slogan", "« Lajenès se lavni peyi an »"));
  return root;
}

export function certificat(m) {
  const v = vueMembre(m);
  const root = el("article", "doc-cert");
  bands(root);
  const inner = el("div", "cert-inner");
  const head = el("div", "cert-head");
  const img = document.createElement("img");
  img.src = ECUS;
  img.alt = "Écusson ACHUS";
  const ht = el("div");
  ht.append(el("div", "wordmark", "ACHUS"));
  ht.append(el("div", "orgline", "Association Corps d'Honneur Universel"));
  head.append(img, ht);
  inner.append(head, el("hr", "cert-rule"));
  inner.append(el("h2", "cert-title", "CERTIFICAT DE MEMBRE"));
  inner.append(el("hr", "cert-title-line"));
  inner.append(el("p", "cert-intro", "Le Comité Central d'ACHUS certifie que"));
  inner.append(el("div", "cert-nom", v.nomComplet));
  inner.append(el(
    "p",
    "cert-par",
    "est reconnu(e) comme membre officiel(le) de l'Association Corps d'Honneur Universel de Santo et s'engage à servir la patrie haïtienne avec honneur, discipline et dévouement."
  ));
  const faits = el("div", "cert-faits");
  [
    ["Grade", v.grade.toUpperCase()],
    ["Fonction", v.fonction.toUpperCase()],
    ["N° de membre", v.numero || "—"],
    ["Membre depuis le", v.adhesion ? dateFR(v.adhesion).toUpperCase() : "—"]
  ].forEach(([k, val]) => {
    const d = el("div");
    d.append(el("small", null, k), el("strong", null, val));
    faits.append(d);
  });
  inner.append(faits);
  inner.append(el("p", "cert-fait", "Fait à Santo, le " + dateFR(v.emission)));
  const sign = el("div", "cert-sign");
  const gauche = el("div", "sign");
  gauche.append(el("div", "ligne"), el("strong", null, PRESIDENT), el("span", null, "Président du Comité Central"));
  const sceau = el("div", "sceau");
  const simg = document.createElement("img");
  simg.src = ECUS;
  simg.alt = "";
  sceau.append(simg);
  const droite = el("div", "sign");
  droite.append(el("div", "ligne"), el("span", null, "Secrétaire général(e)"));
  sign.append(gauche, sceau, droite);
  const bas = el("div", "cert-bas");
  bas.append(sign);
  const foot = el("div", "cert-foot");
  foot.append(el("div", "cert-slogan", "« Lajenès se lavni peyi an »"));
  const refNum = (v.numero || "ACHUS-000").replace(/^ACHUS-/, "");
  foot.append(el("div", "cert-ref", "Réf. CERT-ACHUS-" + refNum));
  bas.append(foot);
  bas.append(el("div", "cert-contact", "+509 39 18 0332 · achushaiti@gmail.com · Santo 13, Croix-des-Bouquets, Haïti"));
  inner.append(bas);
  root.append(inner);
  return root;
}

async function raster(node, widthMm, ratio) {
  const { toPng } = await import("https://cdn.jsdelivr.net/npm/html-to-image@1.11.13/+esm");
  const sandbox = document.createElement("div");
  sandbox.style.cssText = "position:fixed;left:0;top:0;opacity:0;pointer-events:none;z-index:-1;background:#fff";
  const clone = node.cloneNode(true);
  clone.style.width = widthMm;
  clone.style.maxWidth = "none";
  sandbox.append(clone);
  document.body.append(sandbox);
  if (document.fonts && document.fonts.ready) await document.fonts.ready;
  try {
    return await toPng(clone, {
      pixelRatio: ratio,
      backgroundColor: "#ffffff",
      cacheBust: true
    });
  } finally {
    sandbox.remove();
  }
}

function sauverLien(href, nom) {
  const a = document.createElement("a");
  a.href = href;
  a.download = nom;
  document.body.append(a);
  a.click();
  a.remove();
}

export async function telechargerCartePng(m) {
  const v = vueMembre(m);
  const recto = await raster(carteRecto(m), "85.6mm", 4);
  const verso = await raster(carteVerso(m), "85.6mm", 4);
  const base = "carte-" + (v.numero || "membre");
  sauverLien(recto, base + "-recto.png");
  await new Promise((r) => setTimeout(r, 250));
  sauverLien(verso, base + "-verso.png");
}

export async function telechargerCartePdf(m) {
  const { jsPDF } = await import("https://cdn.jsdelivr.net/npm/jspdf@2.5.2/+esm");
  const v = vueMembre(m);
  const recto = await raster(carteRecto(m), "85.6mm", 4);
  const verso = await raster(carteVerso(m), "85.6mm", 4);
  const pdf = new jsPDF({ unit: "mm", format: [85.6, 54], orientation: "landscape" });
  const w = pdf.internal.pageSize.getWidth();
  const h = pdf.internal.pageSize.getHeight();
  pdf.addImage(recto, "PNG", 0, 0, w, h, undefined, "FAST");
  pdf.addPage([85.6, 54], "landscape");
  pdf.addImage(verso, "PNG", 0, 0, w, h, undefined, "FAST");
  pdf.save("carte-" + (v.numero || "membre") + ".pdf");
}

export async function telechargerCertificatPdf(m) {
  const { jsPDF } = await import("https://cdn.jsdelivr.net/npm/jspdf@2.5.2/+esm");
  const v = vueMembre(m);
  const png = await raster(certificat(m), "297mm", 3.5);
  const pdf = new jsPDF({ orientation: "landscape", unit: "mm", format: "a4" });
  pdf.addImage(png, "PNG", 0, 0, 297, 210, undefined, "FAST");
  const ref = (v.numero || "ACHUS-000").replace(/^ACHUS-/, "");
  pdf.save("CERT-ACHUS-" + ref + ".pdf");
}

export function imprimerCertificat(m) {
  let root = document.getElementById("print-root");
  if (!root) {
    root = document.createElement("div");
    root.id = "print-root";
    document.body.append(root);
  }
  const node = certificat(m);
  node.style.width = "297mm";
  node.style.maxWidth = "none";
  root.replaceChildren(node);
  document.body.classList.add("printing-cert");
  const fin = () => document.body.classList.remove("printing-cert");
  window.addEventListener("afterprint", fin, { once: true });
  window.print();
  setTimeout(fin, 1500);
}

export const EXEMPLE = {
  prenom: "Moïse-Son Sorel",
  nom: "Cezil",
  grade: "Général",
  fonction: "Président",
  numero_membre: "ACHUS-001",
  telephone: "+509 39 18 0332",
  email: "achushaiti@gmail.com",
  adresse: "Santo 13, Croix-des-Bouquets, Haïti",
  date_adhesion: "2005-01-15",
  date_validite: "2027-12-31",
  date_emission: "2026-05-18",
  statut: "actif",
  photoUrl: ""
};
