// Écrans ajoutés au portail : aucun secret ni service payant.
export const STATUTS_PRESENCE = { en_attente: 'En attente', approuvee: 'Approuvée', refusee: 'Refusée' };
const ZONE = 'America/Port-au-Prince';
export function jourHaiti(date = new Date()) {
  const parts = new Intl.DateTimeFormat('fr-CA', { timeZone: ZONE, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(date);
  return ['year', 'month', 'day'].map(k => parts.find(p => p.type === k).value).join('-');
}
export function decalerJour(jour, ecart) {
  const d = new Date(jour + 'T12:00:00Z');
  d.setUTCDate(d.getUTCDate() + ecart);
  return d.toISOString().slice(0, 10);
}
export function csvTexte(entetes, lignes) {
  const cellule = value => {
    let texte = String(value ?? '');
    if (/^[\s]*[=+@-]/u.test(texte)) texte = "'" + texte;
    return '"' + texte.replace(/"/g, '""') + '"';
  };
  return '\uFEFF' + [entetes, ...lignes].map(ligne => ligne.map(cellule).join(';')).join('\r\n');
}
export function filtrerMembres(membres, { recherche = '', statut = '', grade = '', fonction = '', validite = '', tri = 'nom', sens = 'asc', aujourd = jourHaiti() } = {}) {
  const normaliser = valeur => String(valeur ?? '').normalize('NFD').replace(/\p{Diacritic}/gu, '').toLocaleLowerCase('fr');
  const texte = normaliser(recherche.trim());
  return membres.filter(m => (!statut || m.statut === statut) && (!grade || m.grade === grade)
    && (!fonction || m.fonction === fonction)
    && (!texte || normaliser([m.nom, m.prenom, m.numero_membre, m.grade, m.fonction].join(' ')).includes(texte))
    && (!validite || (validite === 'valide' ? m.date_validite >= aujourd : validite === 'expiree' ? m.date_validite && m.date_validite < aujourd : !m.date_validite)))
    .sort((a, b) => {
      const valeur = m => tri === 'nom' ? [m.nom, m.prenom].join(' ') : m[tri];
      return String(valeur(a) ?? '').localeCompare(String(valeur(b) ?? ''), 'fr', { numeric: true, sensitivity: 'base' }) * (sens === 'desc' ? -1 : 1);
    });
}

const n = (tag, classe, texte) => {
  const node = document.createElement(tag);
  if (classe) node.className = classe;
  if (texte != null) node.textContent = texte;
  return node;
};
let compteurChamp = 0;
const champ = (label, controle) => {
  const node = n('label', 'champ');
  const libelle = n('span', '', label);
  libelle.id = 'libelle-collaboration-' + (++compteurChamp);
  controle.setAttribute('aria-labelledby', libelle.id);
  node.append(libelle, controle);
  return node;
};
const saisie = (type = 'text', valeur = '') => {
  const node = n(type === 'textarea' ? 'textarea' : 'input');
  if (type !== 'textarea') node.type = type;
  node.value = valeur ?? '';
  return node;
};
const choix = (options, valeur = '') => {
  const node = n('select');
  options.forEach(([val, texte]) => {
    const option = n('option', '', texte);
    option.value = val;
    node.append(option);
  });
  node.value = valeur;
  return node;
};
const bouton = (texte, action, classe = 'btn-ghost') => {
  const node = n('button', 'btn btn-sm ' + classe, texte);
  node.type = 'button';
  if (action) node.onclick = action;
  return node;
};
const nomComplet = m => [m?.prenom, m?.nom].filter(Boolean).join(' ') || 'Ancien membre';
const nomNumero = m => nomComplet(m) + (m?.numero_membre ? ' · ' + m.numero_membre : '');
const dateCourte = date => date ? new Date(date.length === 10 ? date + 'T12:00:00Z' : date).toLocaleDateString('fr-HT', { timeZone: ZONE }) : '—';
const dateHeure = date => new Date(date).toLocaleString('fr-HT', { timeZone: ZONE, dateStyle: 'medium', timeStyle: 'short' });

function tableau(entetes, lignes, legende) {
  const wrap = n('div', 'table-wrap');
  wrap.tabIndex = 0;
  wrap.setAttribute('role', 'region');
  wrap.setAttribute('aria-label', legende);
  const table = n('table', 'table-collaboration');
  const caption = n('caption', 'sr-only', legende);
  const head = n('thead');
  const tr = n('tr');
  entetes.forEach(titre => { const th = n('th', '', titre); th.scope = 'col'; tr.append(th); });
  head.append(tr);
  const body = n('tbody');
  lignes.forEach(ligne => {
    const row = n('tr');
    ligne.forEach(val => { const td = n('td'); if (val instanceof Node) td.append(val); else td.textContent = val ?? '—'; row.append(td); });
    body.append(row);
  });
  table.append(caption, head, body);
  wrap.append(table);
  return wrap;
}

function fenetre(titre) {
  const dialog = n('dialog', 'dialog-portail');
  dialog.setAttribute('aria-label', titre);
  const fermer = bouton('Fermer', () => dialog.close());
  const header = n('div', 'ligne-btns dialog-titre');
  header.append(n('h3', '', titre), fermer);
  const corps = n('div');
  dialog.append(header, corps);
  dialog.addEventListener('close', () => dialog.remove(), { once: true });
  document.body.append(dialog);
  dialog.showModal();
  return { corps, fermer: () => dialog.close() };
}

export function creerCollaboration({ client, profil, estBureau, libelleStatut, libelleRole, toast, sauverBlob, actualiser, ouvrirDocuments }) {
  const db = () => client();
  const actif = () => profil()?.statut === 'actif';
  const bureau = () => estBureau(profil());
  const president = () => bureau() && profil().role === 'president';
  const erreur = error => {
    if (error?.code === '23505') return 'Cette déclaration existe déjà. Actualisez la liste.';
    if (['23503', '23001'].includes(error?.code)) return 'Cet élément a un historique de présence et doit être conservé.';
    if (['42P01', 'PGRST202', 'PGRST205'].includes(error?.code)) return 'Cette fonction attend la mise à jour de la base. Contactez le président.';
    if (error?.code === '42501' && !/[éèàêôî]/.test(error.message || '')) return 'Votre compte ne permet pas cette action. Actualisez votre session.';
    if (error?.message && /[éèàêôî]|membre|présence|motif|statut|Choisissez|Utilisez/.test(error.message)) return error.message;
    return 'Action impossible pour le moment. Vérifiez votre connexion et réessayez.';
  };
  const verifier = resultat => { if (resultat.error) throw resultat.error; return resultat.data; };
  const executer = async (controle, action) => {
    if (controle.disabled) return;
    controle.disabled = true;
    try { await action(); } catch (error) { toast(erreur(error), 'error'); }
    finally { controle.disabled = false; }
  };
  async function tous(construire) {
    const resultat = [];
    for (let debut = 0; ; debut += 500) {
      const tranche = verifier(await construire().range(debut, debut + 499)) || [];
      resultat.push(...tranche);
      if (tranche.length < 500) return resultat;
    }
  }
  function exporter(nom, titres, lignes) {
    sauverBlob(new Blob([csvTexte(titres, lignes)], { type: 'text/csv;charset=utf-8' }), nom);
    toast('Fichier CSV téléchargé.');
  }
  function interdit(texte = 'Cette page est réservée au bureau.') { return n('div', 'msg info', texte); }

  async function badgeMessages() {
    const badge = document.getElementById('non-lus');
    if (!badge || !actif()) return;
    const membre = profil().id;
    try {
      const res = await db().from('messages').select('id', { count: 'exact', head: true }).eq('destinataire', membre).eq('lu', false);
      if (res.error || profil()?.id !== membre || !badge.isConnected) return;
      const compte = res.count || 0;
      badge.textContent = String(compte);
      badge.hidden = !compte;
      badge.setAttribute('aria-label', compte + ' message(s) non lu(s)');
    } catch { /* Une coupure réseau ne doit pas interrompre la navigation. */ }
  }

  async function messages() {
    if (!actif()) return interdit('La messagerie est réservée aux membres actifs.');
    const root = n('div', 'espace-collaboration');
    const contacts = await tous(() => db().rpc('contacts_messagerie'));
    const parId = new Map(contacts.map(m => [m.id, m]));
    const outils = n('div', 'ligne-btns');
    const mode = choix([['recus', 'Boîte de réception'], ['envoyes', 'Messages envoyés']], 'recus');
    const nouveau = bouton('Nouveau message', () => composer(), 'btn-navy');
    const rafraichir = bouton('Actualiser', () => executer(rafraichir, charger));
    outils.append(champ('Dossier', mode), nouveau, rafraichir);
    const liste = n('div', 'liste-messages');
    const navigation = n('div', 'ligne-btns');
    let index = 0;
    let version = 0;
    async function charger() {
      const tour = ++version;
      const champId = mode.value === 'recus' ? 'destinataire' : 'expediteur';
      const res = await db().from('messages').select('*').eq(champId, profil().id)
        .order('date_envoi', { ascending: false }).order('id').range(index * 20, index * 20 + 20);
      const lignes = verifier(res) || [];
      if (tour !== version) return;
      liste.replaceChildren();
      navigation.replaceChildren();
      if (!lignes.length) liste.append(n('p', 'meta', 'Aucun message dans ce dossier.'));
      lignes.slice(0, 20).forEach(message => {
        const recu = message.destinataire === profil().id;
        const carte = n('article', 'carte-info message' + (recu && !message.lu ? ' message-nouveau' : ''));
        const titre = (recu ? 'De : ' : 'À : ') + nomNumero(parId.get(recu ? message.expediteur : message.destinataire));
        carte.append(n('h3', '', titre), n('p', 'meta', dateHeure(message.date_envoi)));
        const texte = n('p', 'texte-message', message.contenu);
        carte.append(texte, n('span', 'badge ' + (message.lu ? 'b-actif' : 'b-en_attente'), message.lu ? 'Lu' : 'Non lu'));
        const actions = n('div', 'ligne-btns');
        if (recu && !message.lu) {
          const lu = bouton('Marquer comme lu', () => executer(lu, async () => {
            const lignes = verifier(await db().from('messages').update({ lu: true }).eq('id', message.id).select('id'));
            if (!lignes?.length) throw { code: '42501' };
            await charger();
          }));
          actions.append(lu);
        }
        if (recu && parId.has(message.expediteur)) actions.append(bouton('Répondre', () => composer(message.expediteur)));
        carte.append(actions);
        liste.append(carte);
      });
      const precedent = bouton('Précédent', () => executer(precedent, async () => { index--; await charger(); }));
      precedent.disabled = index === 0;
      const suivant = bouton('Suivant', () => executer(suivant, async () => { index++; await charger(); }));
      suivant.disabled = lignes.length <= 20;
      navigation.append(precedent, n('span', 'meta', 'Page ' + (index + 1)), suivant);
      await badgeMessages();
    }
    function composer(destinataire = '') {
      const modal = fenetre('Nouveau message');
      const form = n('form');
      const cible = choix([['', 'Choisir un membre'], ...contacts.filter(m => m.id !== profil().id).map(m => [m.id, nomNumero(m)])], destinataire);
      cible.required = true;
      const contenu = saisie('textarea');
      contenu.required = true;
      contenu.maxLength = 5000;
      const go = bouton('Envoyer', null, 'btn-navy');
      go.type = 'submit';
      form.append(champ('Destinataire', cible), champ('Message (5 000 caractères maximum)', contenu), go);
      form.onsubmit = event => {
        event.preventDefault();
        executer(go, async () => {
          if (!contenu.value.trim()) { contenu.setCustomValidity('Écrivez un message.'); contenu.reportValidity(); return; }
          verifier(await db().from('messages').insert({ expediteur: profil().id, destinataire: cible.value, contenu: contenu.value.trim() }));
          modal.fermer();
          toast('Message envoyé.');
          mode.value = 'envoyes'; index = 0; await charger();
        });
      };
      contenu.oninput = () => contenu.setCustomValidity('');
      modal.corps.append(form);
    }
    mode.onchange = () => { index = 0; charger().catch(e => toast(erreur(e), 'error')); };
    root.append(outils, liste, navigation);
    await charger();
    return root;
  }

  function periode() {
    const fin = saisie('date', jourHaiti());
    const debut = saisie('date', decalerJour(fin.value, -90));
    fin.max = jourHaiti(); debut.max = jourHaiti();
    fin.required = true; debut.required = true;
    const form = n('form', 'filtres');
    const go = bouton('Afficher la période', null, 'btn-navy'); go.type = 'submit';
    form.append(champ('Du', debut), champ('Au', fin), go);
    const params = () => {
      const delta = (new Date(fin.value) - new Date(debut.value)) / 86400000;
      if (!debut.value || !fin.value || delta < 0 || delta > 365 || fin.value > jourHaiti()) throw { message: 'Choisissez une période passée de 366 jours maximum.' };
      return { p_debut: debut.value, p_fin: fin.value };
    };
    return { form, go, params };
  }

  async function presences() {
    if (!profil()) return interdit('Aucune fiche membre n’est liée à ce compte.');
    const root = n('div', 'espace-collaboration');
    const filtre = periode();
    const zone = n('div', 'espace-collaboration');
    root.append(n('p', 'meta', 'Déclarez une présence après la séance, en heure d’Haïti. Un autre responsable la vérifiera.'), filtre.form, zone);
    async function charger() {
      const params = filtre.params();
      const historique = await tous(() => db().from('presences_evenements').select('*,evenements(titre)').eq('membre_id', profil().id)
        .gte('date_session', params.p_debut).lte('date_session', params.p_fin).order('date_session', { ascending: false }).order('id'));
      zone.replaceChildren();
      if (['actif', 'honoraire'].includes(profil().statut)) {
        const sessions = await tous(() => db().rpc('sessions_presence', params));
        const deja = new Set(historique.map(p => p.evenement_id + '/' + p.date_session));
        const disponibles = sessions.filter(s => s.date_session >= profil().date_adhesion && !deja.has(s.evenement_id + '/' + s.date_session));
        const form = n('form', 'panneau');
        const seance = choix([['', 'Choisir une séance passée'], ...disponibles.map(s => [s.evenement_id + '/' + s.date_session, s.titre + ' · ' + dateCourte(s.date_session)])]);
        seance.required = true;
        const go = bouton('Déclarer ma présence', null, 'btn-navy'); go.type = 'submit';
        go.disabled = !disponibles.length;
        form.append(n('h3', '', 'Déclarer une présence'), champ('Réunion ou événement', seance), go);
        if (!disponibles.length) form.append(n('p', 'meta', 'Aucune séance à déclarer sur cette période.'));
        form.onsubmit = event => {
          event.preventDefault();
          executer(go, async () => {
            const [evenement_id, date_session] = seance.value.split('/');
            verifier(await db().from('presences_evenements').insert({ membre_id: profil().id, evenement_id, date_session }));
            toast('Présence déclarée. Elle attend la validation du bureau.'); await charger();
          });
        };
        zone.append(form);
      }
      zone.append(n('h3', '', 'Historique de mes présences'));
      if (!historique.length) zone.append(n('p', 'meta', 'Aucune déclaration sur cette période.'));
      historique.forEach(p => {
        const carte = n('article', 'carte-info');
        carte.append(n('h3', '', p.evenements?.titre || 'Événement'), n('p', 'meta', dateCourte(p.date_session)),
          n('span', 'badge b-' + (p.statut === 'approuvee' ? 'actif' : p.statut === 'refusee' ? 'refuse' : 'en_attente'), STATUTS_PRESENCE[p.statut]));
        if (p.motif_decision) carte.append(n('p', '', 'Motif : ' + p.motif_decision));
        if (p.decide_le) carte.append(n('p', 'meta', 'Décision du ' + dateHeure(p.decide_le)));
        zone.append(carte);
      });
      const archives = await tous(() => db().from('presences').select('*').eq('membre_id', profil().id)
        .gte('date_session', params.p_debut).lte('date_session', params.p_fin).order('date_session').order('id'));
      if (archives.length) {
        const details = n('details', 'carte-info');
        details.append(n('summary', '', 'Archives avant validation (' + archives.length + ')'));
        archives.forEach(p => details.append(n('p', 'meta', (p.type_activite || 'Activité') + ' · ' + dateCourte(p.date_session))));
        details.append(n('p', 'meta', 'Ces archives ne sont pas incluses dans le nouveau taux de présence.'));
        zone.append(details);
      }
    }
    filtre.form.onsubmit = event => { event.preventDefault(); executer(filtre.go, charger); };
    await charger();
    return root;
  }

  async function presencesAdmin() {
    if (!bureau()) return interdit();
    const root = n('div', 'espace-collaboration');
    const filtre = periode();
    const zone = n('div', 'espace-collaboration');
    root.append(filtre.form, zone);
    async function charger() {
      const params = filtre.params();
      const sessions = await tous(() => db().rpc('sessions_presence', params));
      const membres = await tous(() => db().from('membres').select('id,prenom,nom,numero_membre,statut,date_adhesion').order('nom').order('id'));
      const declarations = await tous(() => db().from('presences_evenements').select('*').gte('date_session', params.p_debut).lte('date_session', params.p_fin).order('date_session').order('id'));
      const stats = await tous(() => db().rpc('statistiques_presences', params));
      const seance = choix([['', 'Choisir une séance'], ...sessions.map(s => [s.evenement_id + '/' + s.date_session, s.titre + ' · ' + dateCourte(s.date_session)])]);
      const reunion = n('div');
      const parReunion = n('section', 'espace-collaboration');
      parReunion.append(n('h3', '', 'Présences par réunion'), champ('Séance', seance), reunion);
      function dessiner() {
        reunion.replaceChildren();
        if (!seance.value) { reunion.append(n('p', 'meta', 'Choisissez une séance pour voir les déclarations et les absences.')); return; }
        const [id, date] = seance.value.split('/');
        const presents = new Map(declarations.filter(p => p.evenement_id === id && p.date_session === date).map(p => [p.membre_id, p]));
        const eligibles = membres.filter(m => m.date_adhesion && m.date_adhesion <= date);
        const lignes = eligibles.map(m => {
          const presence = presents.get(m.id);
          const actions = n('div', 'ligne-btns');
          if (presence?.statut === 'en_attente' && m.id !== profil().id) {
            for (const [statut, label, classe] of [['approuvee', 'Approuver', 'btn-ok'], ['refusee', 'Refuser', 'btn-red']]) {
              const go = bouton(label, () => decision(presence, statut), classe);
              go.setAttribute('aria-label', label + ' la présence de ' + nomComplet(m)); actions.append(go);
            }
          } else if (presence?.statut === 'en_attente') actions.append(n('span', 'meta', 'À valider par un autre responsable'));
          return [m.numero_membre, nomComplet(m), presence ? STATUTS_PRESENCE[presence.statut] : 'Non déclarée', presence?.motif_decision || '—', actions];
        });
        const csv = bouton('Exporter cette réunion en CSV', () => exporter('presences-reunion-achus.csv',
          ['Séance', 'Date', 'Numéro ACHUS', 'Nom', 'Statut', 'Motif'], eligibles.map(m => {
            const p = presents.get(m.id); return [sessions.find(s => s.evenement_id === id && s.date_session === date)?.titre, date, m.numero_membre, nomComplet(m), p ? STATUTS_PRESENCE[p.statut] : 'Non déclarée', p?.motif_decision];
          })));
        reunion.append(csv, tableau(['N° ACHUS', 'Membre', 'Présence', 'Motif', 'Décision'], lignes, 'Présences par réunion'));
      }
      function decision(presence, statut) {
        const modal = fenetre(statut === 'approuvee' ? 'Approuver la présence' : 'Refuser la présence');
        const form = n('form');
        const motif = saisie('textarea'); motif.maxLength = 2000; motif.required = statut === 'refusee'; motif.minLength = statut === 'refusee' ? 3 : 0;
        const go = bouton('Confirmer la décision', null, statut === 'approuvee' ? 'btn-ok' : 'btn-red'); go.type = 'submit';
        form.append(champ(statut === 'refusee' ? 'Motif du refus (obligatoire)' : 'Commentaire (facultatif)', motif), go);
        form.onsubmit = event => {
          event.preventDefault();
          executer(go, async () => {
            verifier(await db().rpc('decider_presence', { p_id: presence.id, p_statut: statut, p_motif: motif.value.trim() }));
            modal.fermer(); toast('Décision enregistrée.'); await charger();
          });
        };
        modal.corps.append(form);
      }
      seance.onchange = dessiner;
      const selection = zone.querySelector('select')?.value;
      if (sessions.some(s => s.evenement_id + '/' + s.date_session === selection)) seance.value = selection;
      const taux = n('section', 'espace-collaboration');
      const titres = ['N° ACHUS', 'Membre', 'Séances', 'Approuvées', 'En attente', 'Refusées', 'Taux'];
      const valeurs = stats.map(s => [s.numero_membre, nomComplet(s), s.seances, s.approuvees, s.en_attente, s.refusees, s.taux == null ? '—' : Number(s.taux).toLocaleString('fr') + ' %']);
      taux.append(n('h3', '', 'Taux de présence par membre'),
        n('p', 'meta', 'Taux = présences approuvées ÷ séances passées de l’agenda depuis l’adhésion, sur la période choisie. Une séance sans déclaration compte au dénominateur. Les suspensions passées et les anciennes archives ne modifient pas ce calcul.'),
        bouton('Exporter les taux en CSV', () => exporter('taux-presence-achus.csv', titres, valeurs)),
        tableau(titres, valeurs, 'Taux de présence par membre'));
      zone.replaceChildren(parReunion, taux); dessiner();
    }
    filtre.form.onsubmit = event => { event.preventDefault(); executer(filtre.go, charger); };
    await charger(); return root;
  }

  async function registre() {
    if (!bureau()) return interdit();
    const membres = await tous(() => db().from('membres').select('*').order('nom').order('id'));
    const root = n('div', 'espace-collaboration');
    const recherche = saisie('search'); recherche.placeholder = 'Nom, numéro ACHUS, grade, fonction…';
    const statut = choix([['', 'Tous les statuts'], ['actif', 'Actif'], ['inactif', 'Inactif'], ['suspendu', 'Suspendu'], ['honoraire', 'Honoraire'], ['en_attente', 'En attente'], ['refuse', 'Refusé']], 'actif');
    const options = cle => [['', 'Tous'], ...[...new Set(membres.map(m => m[cle]).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'fr')).map(v => [v, v])];
    const grade = choix(options('grade'));
    const fonction = choix(options('fonction'));
    const validite = choix([['', 'Toutes'], ['valide', 'Valide'], ['expiree', 'Expirée'], ['absente', 'Non renseignée']]);
    const tri = choix([['nom', 'Nom'], ['numero_membre', 'Numéro ACHUS'], ['grade', 'Grade'], ['fonction', 'Fonction'], ['statut', 'Statut'], ['date_adhesion', 'Date d’adhésion'], ['date_validite', 'Validité']], 'nom');
    const sens = choix([['asc', 'Croissant'], ['desc', 'Décroissant']], 'asc');
    const filtres = n('div', 'filtres');
    filtres.append(champ('Rechercher', recherche), champ('Statut', statut), champ('Grade', grade), champ('Fonction', fonction), champ('Validité', validite), champ('Trier par', tri), champ('Ordre', sens));
    const compte = n('p', 'meta'); compte.setAttribute('aria-live', 'polite');
    const zone = n('div');
    const navigation = n('div', 'ligne-btns');
    const csv = bouton('Exporter la sélection en CSV', () => exporter('registre-achus.csv',
      ['Numéro ACHUS', 'Prénom', 'Nom', 'Grade', 'Fonction', 'Statut', 'Rôle', 'Date d’adhésion', 'Validité'],
      selection.map(m => [m.numero_membre, m.prenom, m.nom, m.grade, m.fonction, libelleStatut(m.statut), libelleRole(m.role), m.date_adhesion, m.date_validite])));
    let selection = []; let index = 0;
    function dessiner() {
      selection = filtrerMembres(membres, { recherche: recherche.value, statut: statut.value, grade: grade.value, fonction: fonction.value, validite: validite.value, tri: tri.value, sens: sens.value });
      const pages = Math.max(1, Math.ceil(selection.length / 25)); index = Math.min(index, pages - 1);
      compte.textContent = selection.length + ' membre(s) · Page ' + (index + 1) + '/' + pages;
      const lignes = selection.slice(index * 25, index * 25 + 25).map(m => [m.numero_membre, nomComplet(m), m.grade, m.fonction,
        libelleStatut(m.statut), dateCourte(m.date_adhesion), dateCourte(m.date_validite), bouton('Gérer', () => gererMembre(m))]);
      zone.replaceChildren(selection.length ? tableau(['N° ACHUS', 'Nom', 'Grade', 'Fonction', 'Statut', 'Adhésion', 'Validité', 'Actions'], lignes, 'Registre des membres') : n('p', 'meta', 'Aucun membre ne correspond à ces filtres.'));
      const avant = bouton('Précédent', () => { index--; dessiner(); }); avant.disabled = index === 0;
      const apres = bouton('Suivant', () => { index++; dessiner(); }); apres.disabled = index + 1 >= pages;
      navigation.replaceChildren(avant, apres);
    }
    [statut, grade, fonction, validite, tri, sens].forEach(controle => { controle.onchange = () => { index = 0; dessiner(); }; });
    recherche.oninput = () => { index = 0; dessiner(); };
    root.append(filtres, csv, compte, zone, navigation); dessiner(); return root;
  }

  async function gererMembre(m) {
    const modal = fenetre('Gérer ' + nomNumero(m));
    const form = n('form', 'panneau');
    const grade = saisie('text', m.grade); grade.required = true;
    const fonction = saisie('text', m.fonction); fonction.required = true;
    const validite = saisie('date', m.date_validite);
    const role = choix([['membre', 'Membre'], ['bureau', 'Bureau'], ['president', 'Président']], m.role);
    role.disabled = !president() || m.id === profil().id;
    const go = bouton('Enregistrer les informations', null, 'btn-navy'); go.type = 'submit';
    form.append(champ('Grade', grade), champ('Fonction', fonction), champ('Validité de la carte', validite), champ('Rôle', role), go);
    form.onsubmit = event => {
      event.preventDefault();
      executer(go, async () => {
        const payload = { grade: grade.value.trim(), fonction: fonction.value.trim(), date_validite: validite.value || null };
        if (!role.disabled) payload.role = role.value;
        const rows = verifier(await db().from('membres').update(payload).eq('id', m.id).select('id'));
        if (!rows?.length) throw { code: '42501' };
        modal.fermer(); toast('Informations enregistrées.'); await actualiser('registre');
      });
    };
    const statut = choix([['actif', 'Actif'], ['honoraire', 'Honoraire'], ...(!m.numero_membre ? [['en_attente', 'En attente'], ['refuse', 'Refusé']] : [])], ['actif', 'honoraire'].includes(m.statut) ? m.statut : 'actif');
    const changer = bouton('Appliquer ce statut', () => executer(changer, async () => {
      verifier(await db().rpc('changer_statut', { p_id: m.id, p_statut: statut.value }));
      modal.fermer(); toast('Statut enregistré.'); await actualiser('registre');
    }), 'btn-navy');
    const actions = n('div', 'espace-collaboration');
    actions.append(champ('Activer ou changer de statut', statut), changer);
    if (['actif', 'honoraire'].includes(m.statut)) actions.append(bouton('Carte et certificat', () => { modal.fermer(); ouvrirDocuments(m); }));
    if (m.id !== profil().id && m.role !== 'president') {
      actions.append(bouton('Retirer ou suspendre', () => { modal.fermer(); retirer(m); }, 'btn-red'));
      if (president() && ['inactif', 'suspendu'].includes(m.statut)) actions.append(bouton('Supprimer définitivement', () => { modal.fermer(); supprimer(m); }, 'btn-red'));
    }
    modal.corps.append(n('p', 'meta', 'Statut actuel : ' + libelleStatut(m.statut)), form, actions);
    try {
      const historique = await tous(() => db().from('historique_statuts').select('*').eq('membre_id', m.id).order('created_at', { ascending: false }).order('id'));
      modal.corps.append(n('h3', '', 'Historique des retraits'));
      if (!historique.length) modal.corps.append(n('p', 'meta', 'Aucun retrait enregistré.'));
      historique.forEach(h => modal.corps.append(n('p', '', dateCourte(h.date_effet) + ' · ' + libelleStatut(h.ancien_statut) + ' → ' + libelleStatut(h.nouveau_statut) + ' · ' + h.motif)));
    } catch (e) { modal.corps.append(n('p', 'msg err', erreur(e))); }
  }

  function retirer(m) {
    const modal = fenetre('Retirer ou suspendre ' + nomNumero(m));
    const form = n('form');
    const statut = choix([['inactif', 'Inactif'], ['suspendu', 'Suspendu']], 'inactif');
    const motif = saisie('textarea'); motif.required = true; motif.minLength = 3; motif.maxLength = 2000;
    const date = saisie('date', jourHaiti()); date.required = true; date.max = jourHaiti();
    const go = bouton('Confirmer le retrait', null, 'btn-red'); go.type = 'submit';
    form.append(n('p', 'meta', 'Le retrait prend effet immédiatement. La date et le motif seront conservés, ainsi que le numéro ACHUS.'),
      champ('Nouveau statut', statut), champ('Motif obligatoire', motif), champ('Date du retrait', date), go);
    form.onsubmit = event => {
      event.preventDefault();
      executer(go, async () => {
        verifier(await db().rpc('retirer_membre', { p_id: m.id, p_statut: statut.value, p_motif: motif.value.trim(), p_date: date.value }));
        modal.fermer(); toast('Retrait enregistré. Le numéro ACHUS reste réservé.'); await actualiser('registre');
      });
    };
    modal.corps.append(form);
  }

  function supprimer(m) {
    const modal = fenetre('Suppression définitive : ' + nomNumero(m));
    const cle = m.numero_membre || m.id;
    const phrase = 'SUPPRIMER DÉFINITIVEMENT';
    const etape = n('div');
    const accepte = saisie('checkbox');
    const label = n('label', 'check');
    label.append(accepte, 'Je comprends que la fiche, ses messages et ses présences seront supprimés. Les traces administratives et le numéro réservé seront conservés.');
    const continuer = bouton('Continuer vers la deuxième confirmation', () => {
      const form = n('form');
      const numero = saisie(); numero.required = true; numero.autocomplete = 'off';
      const confirmation = saisie(); confirmation.required = true; confirmation.autocomplete = 'off';
      const go = bouton('Confirmer la suppression définitive', null, 'btn-red'); go.type = 'submit';
      form.append(champ('Recopiez : ' + cle, numero), champ('Recopiez : ' + phrase, confirmation), go);
      form.onsubmit = event => {
        event.preventDefault();
        executer(go, async () => {
          if (numero.value !== cle || confirmation.value !== phrase) { toast('Les deux confirmations doivent être recopiées exactement.', 'error'); return; }
          verifier(await db().rpc('supprimer_membre', { p_id: m.id, p_numero: numero.value, p_confirmation: confirmation.value }));
          modal.fermer(); toast('Fiche supprimée. Son numéro ne sera jamais réattribué.'); await actualiser('registre');
        });
      };
      etape.replaceChildren(n('h4', '', 'Deuxième confirmation'), form);
    }, 'btn-red');
    continuer.disabled = true;
    accepte.onchange = () => { continuer.disabled = !accepte.checked; };
    etape.append(n('h4', '', 'Première confirmation'), label, continuer);
    modal.corps.append(etape);
  }

  async function journal() {
    if (!bureau()) return interdit();
    const root = n('div', 'espace-collaboration');
    const zone = n('div'); let index = 0;
    const navigation = n('div', 'ligne-btns');
    const libelles = { modification_membre: 'Fiche mise à jour', suppression_membre: 'Fiche supprimée', decision_presence: 'Présence vérifiée' };
    async function charger() {
      const rows = verifier(await db().from('journal_admin').select('*').order('created_at', { ascending: false }).order('id').range(index * 50, index * 50 + 50)) || [];
      zone.replaceChildren(tableau(['Date (Haïti)', 'Responsable', 'Membre concerné', 'Action', 'Détail'], rows.slice(0, 50).map(row => [
        dateHeure(row.created_at), row.acteur_numero || 'Intervention technique', row.cible_numero || 'Sans numéro', libelles[row.action] || 'Action administrative',
        row.action === 'decision_presence' ? (STATUTS_PRESENCE[row.details.statut] || '') + ' · ' + dateCourte(row.details.date_session)
          : row.details.ancien_statut ? libelleStatut(row.details.ancien_statut) + ' → ' + libelleStatut(row.details.nouveau_statut) : 'Suppression définitive'
      ]), 'Journal des actions administratives'));
      const avant = bouton('Précédent', () => executer(avant, async () => { index--; await charger(); }));
      const apres = bouton('Suivant', () => executer(apres, async () => { index++; await charger(); }));
      avant.disabled = index === 0; apres.disabled = rows.length <= 50;
      navigation.replaceChildren(avant, apres);
    }
    root.append(n('p', 'meta', 'Ce journal est en lecture seule. Les motifs des retraits restent dans la fiche et l’historique.'), zone, navigation);
    await charger(); return root;
  }
  const ecran = charger => async () => {
    try { return await charger(); }
    catch (error) { return n('div', 'msg err', erreur(error)); }
  };
  return { messages: ecran(messages), badgeMessages, presences: ecran(presences),
    presencesAdmin: ecran(presencesAdmin), registre: ecran(registre), journal: ecran(journal) };
}
