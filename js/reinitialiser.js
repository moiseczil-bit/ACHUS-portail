// La session de récupération reste en mémoire sur cette page, sans toucher à
// celle du portail. Aucun mot de passe ou jeton n'est conservé par notre code.
const $ = id => document.getElementById(id);
const retour = new URLSearchParams(location.hash.slice(1));
const recuperation = retour.get('type') === 'recovery';
let client;
let sessionValide = false;
let clientPromesse;
let confirmerRecuperation;
const validationRecuperation = new Promise(ok => { confirmerRecuperation = ok; });
function message(texte, erreur = false) {
  const zone = $('recuperation-msg'); zone.hidden = false;
  zone.textContent = texte; zone.className = 'msg ' + (erreur ? 'err' : 'info');
}
function erreurFR(e) {
  const texte = e?.message || '';
  if (/rate|429|too many/i.test(texte)) return 'Trop de demandes rapprochées. Patientez quelques minutes avant de réessayer.';
  if (/expired|invalid.*token|session.*missing|not authenticated/i.test(texte)) return 'Ce lien est expiré ou déjà utilisé. Demandez un nouveau lien ci-dessous.';
  if (/same.password/i.test(texte)) return 'Choisissez un mot de passe différent du précédent.';
  if (/weak|password/i.test(texte)) return 'Ce mot de passe ne respecte pas les exigences du compte. Choisissez un mot de passe plus long et plus varié.';
  return 'Impossible de joindre le service. Vérifiez votre connexion puis réessayez.';
}
function limiter(promesse) {
  let timer;
  return Promise.race([promesse, new Promise((_, non) => { timer = setTimeout(() => non(new Error('Délai dépassé')), 25000); })]).finally(() => clearTimeout(timer));
}
async function obtenirClient() {
  if (!clientPromesse) clientPromesse = (async () => {
    await import('./vendor/supabase-2.49.4.js');
    client = window.supabase.createClient('https://hyktpddailftuwmbakdm.supabase.co', 'sb_publishable_9B8gTwnHPR5PtJokvusYVQ_3wSw0Mjr', {
      auth: { storageKey: 'achus-recuperation', persistSession: false, autoRefreshToken: false, detectSessionInUrl: true },
      global: { fetch: async (url, options = {}) => {
        const controle = new AbortController(); const timer = setTimeout(() => controle.abort(), 20000);
        try { return await fetch(url, { ...options, signal: controle.signal }); }
        finally { clearTimeout(timer); }
      } }
    });
    client.auth.onAuthStateChange((evenement, session) => {
      if (evenement === 'PASSWORD_RECOVERY' && session) {
        sessionValide = true;
        confirmerRecuperation();
        $('nouveau-mot-de-passe').querySelector('[type="submit"]').disabled = false;
      }
    });
    return client;
  })().catch(e => { clientPromesse = null; throw e; });
  return limiter(clientPromesse);
}
$('demander-lien').onsubmit = async e => {
  e.preventDefault(); const bouton = e.submitter;
  if (bouton.disabled) return;
  bouton.disabled = true;
  message('Envoi de la demande…');
  try {
    const sdk = await obtenirClient();
    const { error } = await limiter(sdk.auth.resetPasswordForEmail($('recuperation-email').value.trim(), {
      // Destination fixe déjà utilisée par le portail, jamais une URL fournie par le visiteur.
      redirectTo: 'https://portail.achussantohaiti.com/'
    }));
    if (error) throw error;
    message('Si un compte correspond à cette adresse, un lien de réinitialisation sera envoyé. Vérifiez aussi les courriers indésirables.');
    // Anti-double-clic local ; les limites réelles sont imposées par Supabase.
    setTimeout(() => { bouton.disabled = false; }, 60000);
  } catch (erreur) { message(erreurFR(erreur), true); bouton.disabled = false; }
};
$('voir-nouveau-password').onclick = () => {
  const visible = $('nouveau-password').type === 'password';
  for (const id of ['nouveau-password', 'confirmer-password']) $(id).type = visible ? 'text' : 'password';
  $('voir-nouveau-password').textContent = visible ? 'Masquer les mots de passe' : 'Afficher les mots de passe';
  $('voir-nouveau-password').setAttribute('aria-pressed', String(visible));
};
$('nouveau-mot-de-passe').onsubmit = async e => {
  e.preventDefault(); const bouton = e.submitter;
  if (bouton.disabled || !sessionValide) return;
  const password = $('nouveau-password').value;
  if (password !== $('confirmer-password').value) { message('Les deux mots de passe ne correspondent pas.', true); return; }
  bouton.disabled = true; message('Enregistrement du nouveau mot de passe…');
  try {
    const { error } = await limiter(client.auth.updateUser({ password }));
    if (error) throw error;
    sessionValide = false;
    $('nouveau-mot-de-passe').reset(); $('nouveau-mot-de-passe').hidden = true;
    message('Votre mot de passe a été modifié. Retournez à la connexion pour entrer avec votre nouveau mot de passe.');
    // Ne pas conserver la session de récupération dans cette page.
    client.auth.signOut({ scope: 'local' }).catch(() => {});
  } catch (erreur) { message(erreurFR(erreur), true); bouton.disabled = false; }
};
async function demarrer() {
  if (retour.has('error')) {
    history.replaceState(null, '', location.pathname);
    message('Ce lien est expiré ou déjà utilisé. Demandez un nouveau lien ci-dessous.', true); return;
  }
  if (!recuperation) return;
  $('demander-lien').hidden = true; $('nouveau-mot-de-passe').hidden = false;
  message('Vérification du lien de réinitialisation…');
  try {
    const sdk = await obtenirClient();
    const { data, error } = await limiter(sdk.auth.getSession());
    if (error || !data.session) throw error || new Error('Session missing');
    await limiter(validationRecuperation);
    message('Lien vérifié. Vous pouvez choisir votre nouveau mot de passe.');
  } catch (erreur) {
    sessionValide = false; $('nouveau-mot-de-passe').hidden = true; $('demander-lien').hidden = false;
    message(erreurFR(erreur), true);
  } finally { history.replaceState(null, '', location.pathname); }
}
demarrer();
