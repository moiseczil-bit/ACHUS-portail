// Réseau privé ACHUS. La vidéo s'ouvre chez Jitsi ; aucune clé ni abonnement.
import { jourHaiti, decalerJour } from './collaboration.js';
const n = (tag, classe, texte) => {
  const e = document.createElement(tag);
  if (classe) e.className = classe;
  if (texte != null) e.textContent = texte;
  return e;
};
const nom = m => [m?.prenom, m?.nom].filter(Boolean).join(' ') || 'Ancien contact';
const date = v => new Date(v).toLocaleString('fr-HT', { timeZone: 'America/Port-au-Prince', dateStyle: 'medium', timeStyle: 'short' });
let compteurChamp = 0;
const STATUTS = { en_attente: 'En attente', accepte: 'Accepté', refuse: 'Refusé', annule: 'Annulé', termine: 'Terminé', approuvee: 'Approuvée', refusee: 'Refusée' };
const NOTE_VIDEO = 'Service externe gratuit : Jitsi s’ouvre dans un nouvel onglet. L’organisateur doit s’y connecter pour démarrer la salle, puis activer une salle d’attente ou un mot de passe. Une personne qui reçoit le lien peut le transmettre. La capacité de 100 participants n’est pas garantie ; faites un essai avant une grande réunion.';
export function lienSalle(salle, audio = false) {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(salle)) throw new Error('Salle invalide.');
  return `https://meet.jit.si/ACHUS-${salle}#config.prejoinPageEnabled=true${audio ? '&config.startWithVideoMuted=true' : ''}`;
}
export function creerCommunaute({ client, profil, estBureau, toast }) {
  const requete = async q => { const { data, error } = await q; if (error) throw error; return data || []; };
  const rpc = (f, args = {}) => requete(client().rpc(f, args));
  const erreur = e => /42P01|42883|PGRST20[25]/.test(e?.code || '') ? 'Cette fonction attend la mise à jour de la base. Les fonctions déjà publiées restent disponibles.' : (e?.message || 'Impossible de terminer. Réessayez.');
  const action = async (b, fn) => {
    b.disabled = true;
    try { await fn(); } catch (e) { toast(erreur(e), 'error'); } finally { b.disabled = false; }
  };
  const bouton = (texte, fn, classe = 'btn-ghost') => {
    const b = n('button', `btn btn-sm ${classe}`, texte); b.type = 'button';
    b.onclick = () => action(b, fn); return b;
  };
  const champ = (form, texte, type = 'text', options) => {
    const label = n('label', 'champ'); const libelle = n('span', '', texte);
    libelle.id = 'social-champ-' + (++compteurChamp); label.append(libelle);
    const e = n(type === 'textarea' ? 'textarea' : type === 'select' ? 'select' : 'input');
    e.setAttribute('aria-labelledby', libelle.id);
    if (e.tagName === 'INPUT') e.type = type;
    options?.forEach(([v, t]) => { const o = n('option', '', t); o.value = v; e.append(o); });
    label.append(e); form.append(label); return e;
  };
  const panneau = titre => { const e = n('section', 'carte social-carte'); if (titre) e.append(n('h2', '', titre)); return e; };
  const garde = fn => async () => {
    if (!['actif', 'honoraire'].includes(profil()?.statut)) return n('p', 'msg', 'Cet espace est réservé aux comptes actifs ou honoraires.');
    try { return await fn(); } catch (e) { return n('p', 'msg err', erreur(e)); }
  };
  const tous = async table => {
    const lignes = [];
    for (let debut = 0;; debut += 500) {
      const lot = await requete(client().from(table).select('*').order('id').range(debut, debut + 499));
      lignes.push(...lot); if (lot.length < 500) return lignes;
    }
  };
  const ouvrir = (salle, audio, libelle = 'Rejoindre sur Jitsi') => {
    const a = n('a', 'btn btn-sm btn-navy', libelle); a.href = lienSalle(salle, audio); a.target = '_blank'; a.rel = 'noopener noreferrer'; return a;
  };
  const renouveler = async (node, charger) => { const resultat = await charger(); if (node.isConnected) node.replaceWith(resultat); };
  const rafraichir = (node, charger) => bouton('Actualiser', () => renouveler(node, charger));
  const noms = async lignes => {
    const ids = [...new Set(lignes.map(x => x.auteur))];
    return new Map((ids.length ? await rpc('noms_contributions', { p_ids: ids }) : []).map(m => [m.id, nom(m)]));
  };
  async function fil() {
    const root = n('div', 'social-pile');
    root.append(n('p', 'meta', 'Un espace réservé à la communauté ACHUS. Respectez les autres membres ; le bureau peut retirer une publication ou un commentaire.'));
    const composer = panneau('Partager avec la communauté'); const form = n('form');
    const texte = champ(form, 'Votre publication', 'textarea'); texte.required = true; texte.maxLength = 4000; texte.rows = 3;
    const publier = n('button', 'btn btn-navy', 'Publier'); publier.type = 'submit'; form.append(publier); composer.append(form); root.append(composer);
    const liste = n('div', 'social-pile'); const outils = n('div', 'social-actions'); let page = 0;
    const dessiner = async () => {
      const posts = await requete(client().from('publications').select('*').order('cree_le', { ascending: false }).order('id').range(page * 20, page * 20 + 19));
      const auteurs = await noms(posts); liste.replaceChildren();
      if (!posts.length) liste.append(n('p', 'meta', 'Aucune publication sur cette page.'));
      for (const p of posts) {
        const carte = panneau(); carte.append(n('p', 'meta', `${auteurs.get(p.auteur) || 'Membre'} · ${date(p.cree_le)}${p.masque ? ' · Retirée' : ''}`), n('p', 'social-texte', p.contenu));
        if (p.auteur === profil().id || estBureau(profil())) carte.append(bouton('Retirer la publication', async () => {
          if (!window.confirm('Retirer cette publication du fil ?')) return;
          await rpc('masquer_contribution', { p_id: p.id, p_commentaire: false }); await dessiner();
        }));
        const commentaires = n('div', 'social-pile');
        carte.append(bouton('Voir les commentaires', async () => {
          let curseur = 0; commentaires.replaceChildren();
          const suivant = bouton('Commentaires suivants', async () => chargerCommentaires());
          async function chargerCommentaires() {
            const lot = await requete(client().from('commentaires').select('*').eq('publication', p.id).order('cree_le').order('id').range(curseur, curseur + 19));
            curseur += lot.length; const auteursC = await noms(lot); suivant.remove();
            if (!lot.length && curseur === 0) commentaires.append(n('p', 'meta', 'Aucun commentaire.'));
            lot.forEach(c => {
              const bloc = n('div', 'social-commentaire'); bloc.append(n('p', 'meta', `${auteursC.get(c.auteur) || 'Membre'} · ${date(c.cree_le)}${c.masque ? ' · Retiré' : ''}`), n('p', 'social-texte', c.contenu));
              if (c.auteur === profil().id || estBureau(profil())) bloc.append(bouton('Retirer le commentaire', async () => {
                if (!window.confirm('Retirer ce commentaire ?')) return;
                await rpc('masquer_contribution', { p_id: c.id, p_commentaire: true }); bloc.remove();
              }));
              commentaires.append(bloc);
            });
            if (lot.length === 20) commentaires.append(suivant);
          }
          await chargerCommentaires();
        }), commentaires);
        if (!p.masque) {
          const f = n('form'); const contenu = champ(f, 'Votre commentaire', 'textarea'); contenu.maxLength = 1000; contenu.required = true; contenu.rows = 2;
          const envoyer = n('button', 'btn btn-sm btn-ghost', 'Commenter'); envoyer.type = 'submit'; f.append(envoyer);
          f.onsubmit = e => { e.preventDefault(); action(envoyer, async () => {
            await requete(client().from('commentaires').insert({ publication: p.id, auteur: profil().id, contenu: contenu.value.trim() })); contenu.value = ''; toast('Commentaire publié.'); await dessiner();
          }); }; carte.append(f);
        }
        liste.append(carte);
      }
      outils.replaceChildren();
      const precedent = bouton('Page précédente', async () => { page--; await dessiner(); }); precedent.disabled = page === 0;
      const suivant = bouton('Page suivante', async () => { page++; await dessiner(); }); suivant.disabled = posts.length < 20;
      outils.append(precedent, n('span', 'meta', `Page ${page + 1}`), suivant);
    };
    form.onsubmit = e => { e.preventDefault(); action(publier, async () => {
      await requete(client().from('publications').insert({ auteur: profil().id, contenu: texte.value.trim() })); texte.value = ''; page = 0; await dessiner(); toast('Publication partagée.');
    }); };
    root.append(bouton('Actualiser le fil', dessiner), liste, outils); await dessiner(); return root;
  }
  async function appels() {
    const root = n('div', 'social-pile'); root.append(n('p', 'msg', NOTE_VIDEO), n('p', 'meta', 'Les invitations apparaissent lorsque le portail est ouvert. Actualisez pour voir la réponse. Il n’y a pas de sonnerie en arrière-plan. Après la conversation, cliquez sur « Terminer ».'));
    if (profil().statut !== 'actif') { root.append(n('p', '', 'Les appels privés sont réservés aux comptes actifs.')); return root; }
    const contacts = await rpc('contacts_messagerie'); const annuaire = new Map(contacts.map(m => [m.id, nom(m)]));
    const carte = panneau('Inviter à un appel'); const f = n('form');
    const contact = champ(f, 'Destinataire', 'select', contacts.map(m => [m.id, `${nom(m)} · ${m.numero_membre || ''}`])); contact.required = true;
    const mode = champ(f, 'Type d’appel', 'select', [['audio', 'Audio'], ['video', 'Vidéo']]);
    const envoi = n('button', 'btn btn-navy', 'Envoyer l’invitation'); envoi.type = 'submit'; envoi.disabled = !contacts.length; f.append(envoi); carte.append(f); root.append(carte);
    f.onsubmit = e => { e.preventDefault(); action(envoi, async () => { await rpc('inviter_appel', { p_destinataire: contact.value, p_mode: mode.value }); toast('Invitation envoyée.'); await renouveler(root, appels); }); };
    root.append(rafraichir(root, appels));
    const lignes = await requete(client().from('appels').select('*').order('cree_le', { ascending: false }).order('id').range(0, 49));
    if (!lignes.length) root.append(n('p', 'meta', 'Aucun appel récent.'));
    for (const a of lignes) {
      const recu = a.destinataire === profil().id; const expire = new Date(a.expire_le) <= new Date();
      const actif = new Date(a.cree_le).getTime() > Date.now() - 12 * 3600000;
      const c = panneau(`${recu ? 'De' : 'À'} ${annuaire.get(recu ? a.expediteur : a.destinataire) || 'Ancien contact'}`);
      c.append(n('p', 'meta', `${a.mode === 'audio' ? 'Audio' : 'Vidéo'} · ${date(a.cree_le)} · ${a.statut === 'en_attente' && expire ? 'Invitation expirée' : STATUTS[a.statut]}`));
      const repondre = async p_action => { await rpc('repondre_appel', { p_id: a.id, p_action }); await renouveler(root, appels); };
      const actions = n('div', 'social-actions');
      if (a.statut === 'en_attente' && !expire) {
        if (recu) actions.append(bouton('Accepter', () => repondre('accepte'), 'btn-navy'), bouton('Refuser', () => repondre('refuse')));
        else actions.append(bouton('Annuler l’invitation', () => repondre('annule')));
      }
      if (a.statut === 'accepte') {
        if (actif && annuaire.has(recu ? a.expediteur : a.destinataire)) actions.append(ouvrir(a.salle, a.mode === 'audio'));
        actions.append(bouton('Terminer', () => repondre('termine')));
      }
      c.append(actions); root.append(c);
    }
    root.append(n('p', 'meta', 'Les 50 appels les plus récents sont affichés. Le statut ne mesure pas la durée de connexion chez Jitsi.')); return root;
  }
  async function reunions() {
    const root = n('div', 'social-pile'); root.append(n('p', 'msg', NOTE_VIDEO), n('p', 'meta', 'Rejoindre une salle ne valide pas une présence. Les présences continuent à être déclarées puis approuvées dans le portail. Les horaires affichés sont ceux d’Haïti.'));
    if (estBureau(profil())) {
      const c = panneau('Programmer une réunion'); const f = n('form');
      const titre = champ(f, 'Titre'); titre.required = true; titre.maxLength = 160;
      const debut = champ(f, 'Début (heure de cet appareil)', 'datetime-local'); debut.required = true;
      const fin = champ(f, 'Fin (heure de cet appareil, 12 h maximum)', 'datetime-local'); fin.required = true;
      const audience = champ(f, 'Participants invités', 'select', [['tous', 'Membres et parents'], ['membres', 'Membres'], ['parents', 'Parents']]);
      const enregistrer = n('button', 'btn btn-navy', 'Créer la réunion'); enregistrer.type = 'submit'; f.append(enregistrer); c.append(f); root.append(c);
      f.onsubmit = e => { e.preventDefault(); action(enregistrer, async () => {
        if (new Date(fin.value) <= new Date(debut.value)) throw new Error('La fin doit suivre le début.');
        await rpc('creer_reunion', { p_titre: titre.value.trim(), p_debut: new Date(debut.value).toISOString(), p_fin: new Date(fin.value).toISOString(), p_public: audience.value });
        await renouveler(root, reunions); toast('Réunion créée.');
      }); };
    }
    root.append(rafraichir(root, reunions));
    const lignes = await requete(client().from('reunions').select('*').gte('fin', new Date().toISOString()).order('debut').order('id').range(0, 99));
    if (!lignes.length) root.append(n('p', 'meta', 'Aucune réunion à venir.'));
    lignes.forEach(r => {
      const c = panneau(r.titre); c.append(n('p', 'meta', `${date(r.debut)} — ${date(r.fin)} · ${r.annulee ? 'Annulée' : 'Programmée'}`));
      if (!r.annulee) {
        c.append(ouvrir(r.salle, false));
        if (estBureau(profil())) c.append(bouton('Annuler la réunion', async () => {
          if (!window.confirm('Annuler cette réunion ?')) return;
          await rpc('annuler_reunion', { p_id: r.id }); await renouveler(root, reunions);
        }));
      }
      root.append(c);
    }); return root;
  }
  async function famille() {
    const root = n('div', 'social-pile');
    if (estBureau(profil())) {
      root.append(n('p', 'msg', 'Vérifiez l’identité du parent et son autorisation avant de le rattacher à un enfant. Le lien donne uniquement accès à ses déclarations de présence.'));
      const membres = await tous('membres'); const parents = membres.filter(m => m.type_compte === 'parent' && m.statut === 'actif');
      const enfants = membres.filter(m => m.type_compte !== 'parent'); const c = panneau('Rattacher un parent'); const f = n('form');
      const p = champ(f, 'Parent actif', 'select', parents.map(m => [m.id, `${nom(m)} · ${m.numero_membre || ''}`])); p.required = true;
      const e = champ(f, 'Enfant / membre', 'select', enfants.map(m => [m.id, `${nom(m)} · ${m.numero_membre || ''}`])); e.required = true;
      const b = n('button', 'btn btn-navy', 'Valider le lien familial'); b.type = 'submit'; b.disabled = !parents.length || !enfants.length; f.append(b); c.append(f); root.append(c);
      f.onsubmit = ev => { ev.preventDefault(); action(b, async () => {
        await rpc('gerer_lien_familial', { p_parent: p.value, p_enfant: e.value, p_retirer: false }); await renouveler(root, famille); toast('Lien familial validé.');
      }); };
      const liens = await requete(client().from('liens_familiaux').select('*').order('parent_id').order('enfant_id').range(0, 999));
      const noms = new Map(membres.map(m => [m.id, nom(m)]));
      liens.forEach(l => {
        const c = panneau(`${noms.get(l.parent_id)} → ${noms.get(l.enfant_id)}`);
        c.append(bouton('Retirer l’accès du parent', async () => {
          if (!window.confirm('Retirer immédiatement cet accès aux présences ?')) return;
          await rpc('gerer_lien_familial', { p_parent: l.parent_id, p_enfant: l.enfant_id, p_retirer: true }); await renouveler(root, famille);
        })); root.append(c);
      });
      if (liens.length === 1000) root.append(n('p', 'meta', 'Les 1 000 premiers liens sont affichés.'));
    } else {
      const enfants = await rpc('enfants_parent');
      if (!enfants.length) root.append(n('p', 'msg', 'Aucun enfant n’est rattaché à votre compte. Le bureau doit vérifier puis valider ce lien.'));
      const aujourd = jourHaiti();
      for (const enfant of enfants) {
        const c = panneau(nom(enfant)); const f = n('form');
        const debut = champ(f, 'Du', 'date'); debut.value = decalerJour(aujourd, -90); debut.required = true;
        const fin = champ(f, 'Au (366 jours maximum)', 'date'); fin.value = aujourd; fin.required = true;
        const b = n('button', 'btn btn-sm btn-ghost', 'Afficher les présences'); b.type = 'submit'; f.append(b); c.append(f);
        const resultats = n('div', 'social-pile'); resultats.setAttribute('aria-live', 'polite'); c.append(resultats);
        const charger = async () => {
          const lignes = []; for (let i = 0;; i += 500) {
            const lot = await requete(client().rpc('presences_enfant', { p_enfant: enfant.id, p_debut: debut.value, p_fin: fin.value }).range(i, i + 499));
            lignes.push(...lot); if (lot.length < 500) break;
          }
          if (!c.isConnected && root.isConnected) return;
          resultats.replaceChildren();
          resultats.append(n('p', 'meta', `${lignes.filter(l => l.statut === 'approuvee').length} présence(s) approuvée(s) sur ${lignes.length} déclaration(s). Ceci n’est pas un taux de présence.`));
          if (!lignes.length) resultats.append(n('p', '', 'Aucune présence déclarée sur cette période.'));
          lignes.forEach(l => resultats.append(n('p', '', `${l.date_session} · ${l.titre} · ${STATUTS[l.statut] || l.statut}`)));
        };
        f.onsubmit = ev => { ev.preventDefault(); action(b, charger); }; root.append(c); await charger();
      }
      root.append(n('p', 'meta', 'Seules les présences déclarées sont affichées. Une présence en attente n’est pas encore validée par le bureau.'));
    }
    return root;
  }
  async function badgeAppels() {
    const badge = document.getElementById('appels-entrants'); const id = profil()?.id;
    if (!badge || profil()?.statut !== 'actif') return;
    try {
      const { count, error } = await client().from('appels').select('id', { head: true, count: 'exact' }).eq('destinataire', id).eq('statut', 'en_attente').gte('expire_le', new Date().toISOString());
      if (!error && badge.isConnected && profil()?.id === id) { badge.hidden = !count; badge.textContent = String(count || 0); badge.setAttribute('aria-label', `${count || 0} invitation(s) à un appel`); }
    } catch { /* Les anciens écrans restent utilisables avant la migration. */ }
  }
  return { fil: garde(fil), appels: garde(appels), reunions: garde(reunions), famille: garde(famille), badgeAppels };
}
