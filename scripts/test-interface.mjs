// Navigateur → adaptateur de test → Postgres local avec RLS.
// Le SDK et les appels distants sont remplacés UNIQUEMENT dans ce serveur de test.
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, mkdir } from 'node:fs/promises';
import { resolve, extname } from 'node:path';
import { chromium } from 'playwright';
import { PGlite } from '@electric-sql/pglite';
import { lienSalle } from '../js/communaute.js';
import { csvTexte, filtrerMembres, jourHaiti, decalerJour } from '../js/collaboration.js';

assert.match(csvTexte(['Nom'], [['=2+2'], ['  @somme'], ['Émilie;"test"']]), /"'=2\+2"/);
assert.match(csvTexte(['Nom'], [['  @somme']]), /"'  @somme"/);
assert.equal(jourHaiti(new Date('2026-11-04T02:00:00Z')), '2026-11-03');
assert.equal(decalerJour('2026-03-08', 1), '2026-03-09');
const testMembres = [
  { nom: 'Émilie', prenom: 'A', numero_membre: 'ACHUS-010', statut: 'actif' },
  { nom: 'Paul', prenom: 'B', numero_membre: 'ACHUS-002', statut: 'inactif' }
];
assert.equal(filtrerMembres(testMembres, { recherche: 'emilie', statut: 'actif' }).length, 1);
assert.equal(filtrerMembres(testMembres, { tri: 'numero_membre' })[0].numero_membre, 'ACHUS-002');

assert.throws(() => lienSalle('javascript:alert(1)'));
assert.match(lienSalle('10000000-0000-4000-8000-000000000001', true), /^https:\/\/meet\.jit\.si\/ACHUS-/);
const root = resolve(new URL('..', import.meta.url).pathname);
const db = new PGlite({ parsers: { 1082: value => value } });
const PRESIDENT = '11111111-1111-4111-8111-111111111111';
const BUREAU = '22222222-2222-4222-8222-222222222222';
const PAUL = '99999999-9999-4999-8999-999999999999';
const ANNE = '88888888-8888-4888-8888-888888888888';
const PARENT = '60000000-0000-4000-8000-000000000001';
const EVENEMENT = '10000000-0000-4000-8000-000000000001';
const aujourd = jourHaiti();
const hier = decalerJour(aujourd, -1);
for (const file of ['supabase/tests/00_schema_snapshot.sql', 'supabase/tests/01_seed.sql',
  'supabase/migrations/20261104120000_portail_refonte.sql',
  'supabase/migrations/20261104124515_messagerie_presences_registre.sql',
  'supabase/migrations/20261104135930_correction_suppression_dependances.sql',
  'supabase/migrations/20261104143144_reseau_social_gratuit.sql',
  'supabase/migrations/20261104183055_grade_personnel.sql',
  'supabase/migrations/20261104184248_photos_profil_communaute.sql']) await db.exec(await readFile(resolve(root, file), 'utf8'));
await db.query('INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES ($1,$2,$3),($4,$5,$6)',
  [PAUL, 'paul@example.ht', { prenom: 'Paul', nom: 'Joseph' }, ANNE, 'anne@example.ht', { prenom: 'Anne', nom: 'Louis' }]);
await db.query("SELECT set_config('request.jwt.claim.sub',$1,false)", [PRESIDENT]);
await db.query('INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES ($1,$2,$3)', [PARENT, 'parent@example.ht', { prenom: 'Marie', nom: 'Parent', type_compte: 'parent' }]);
for (const uid of [PAUL, ANNE, BUREAU, PARENT]) await db.query('SELECT public.approuver_membre((SELECT id FROM public.membres WHERE user_id = $1))', [uid]);
await db.query("UPDATE public.membres SET role = 'bureau' WHERE user_id = $1", [BUREAU]);
await db.query('UPDATE public.membres SET date_adhesion = $1 WHERE numero_membre IS NOT NULL', [decalerJour(aujourd, -100)]);
await db.query('INSERT INTO public.evenements(id,titre,date_debut) VALUES ($1,$2,($3::date + TIME \'09:00\') AT TIME ZONE \'America/Port-au-Prince\')', [EVENEMENT, 'Réunion de contrôle', hier]);
await db.query("INSERT INTO public.evenements(titre,date_debut,recurrence) VALUES ('Réunion du samedi',($1::date + TIME '09:00') AT TIME ZONE 'America/Port-au-Prince','hebdomadaire:samedi:09:00')", [decalerJour(aujourd, -28)]);
const membreId = async uid => (await db.query('SELECT id FROM public.membres WHERE user_id = $1', [uid])).rows[0].id;
const paulId = await membreId(PAUL); const anneId = await membreId(ANNE); const presidentId = await membreId(PRESIDENT);
const parentId = await membreId(PARENT);
const paulNumero = (await db.query('SELECT numero_membre FROM public.membres WHERE id = $1', [paulId])).rows[0].numero_membre;
await db.query('INSERT INTO public.messages(expediteur,destinataire,contenu) VALUES ($1,$2,$3),($1,$4,$5)',
  [anneId, paulId, 'Bonjour Paul <script>window.injection = true</script>', presidentId, 'Bonjour Président']);
await db.query("SELECT set_config('request.jwt.claim.sub',$1,false)", [PAUL]);
await db.query('INSERT INTO public.presences_evenements(membre_id,evenement_id,date_session) VALUES ($1,$2,$3)', [paulId, EVENEMENT, hier]);
// Plus que la limite REST habituelle : vérifier qu'un export n'est pas tronqué.
await db.exec("INSERT INTO public.membres(prenom,nom,statut,grade) SELECT 'Test','Pagination ' || g,'actif','Garde de test' FROM generate_series(1,1005) g");

const sdk = `
class Requete {
  constructor(table, rpc, params) { this.val = { table, rpc, params, filters: [], orders: [], action: 'select' }; }
  select(columns = '*', options = {}) { this.val.columns = columns; this.val.options = options; return this; }
  insert(payload) { this.val.action = 'insert'; this.val.payload = payload; return this; }
  update(payload) { this.val.action = 'update'; this.val.payload = payload; return this; }
  delete() { this.val.action = 'delete'; return this; }
  eq(key,value) { this.val.filters.push([key,'=',value]); return this; }
  in(key,value) { this.val.filters.push([key,'in',value]); return this; }
  gte(key,value) { this.val.filters.push([key,'>=',value]); return this; }
  lte(key,value) { this.val.filters.push([key,'<=',value]); return this; }
  order(key,options = {}) { this.val.orders.push([key, options.ascending !== false]); return this; }
  range(start,end) { this.val.range = [start,end]; return this; }
  maybeSingle() { this.val.single = true; return this; }
  then(ok,no) { return fetch('/__test__/query', { method: 'POST', headers: {'Content-Type':'application/json','x-test-user':localStorage.getItem('achus-test-user')}, body: JSON.stringify(this.val) }).then(r=>r.json()).then(ok,no); }
}
async function storageRequest(operation,bucket,path,body) {
  return fetch('/__test__/storage?operation='+operation+'&bucket='+encodeURIComponent(bucket)+'&path='+encodeURIComponent(path),
    {method:'POST',headers:{'x-test-user':localStorage.getItem('achus-test-user'),'Content-Type':operation==='upload'?'image/webp':'application/json'},body:body||''}).then(r=>r.json());
}
export function createClient() {
  const user = {id:localStorage.getItem('achus-test-user'),email:'test@example.ht'};
  return { from: table=>new Requete(table), rpc:(name,params={})=>new Requete(null,name,params),
    storage:{from:bucket=>({createSignedUrl:path=>storageRequest('sign',bucket,path),upload:(path,file)=>storageRequest('upload',bucket,path,file),remove:paths=>storageRequest('remove',bucket,paths[0])})},
    auth:{getSession:async()=>({data:{session:{user}}}),signOut:async()=>({error:null})} };
}
window.supabase={createClient};`;
const tables = new Set(['membres', 'messages', 'presences_evenements', 'presences', 'evenements', 'annonces', 'historique_statuts', 'journal_admin', 'publications', 'commentaires', 'liens_familiaux', 'appels', 'reunions']);
const fonctions = new Set(['contacts_messagerie', 'sessions_presence', 'statistiques_presences', 'decider_presence', 'retirer_membre', 'supprimer_membre', 'changer_statut', 'noms_contributions', 'masquer_contribution', 'gerer_lien_familial', 'enfants_parent', 'presences_enfant', 'inviter_appel', 'repondre_appel', 'creer_reunion', 'annuler_reunion', 'modifier_mon_grade', 'profils_contributions']);
const ident = value => { if (!/^[a-z_]+$/.test(value)) throw new Error('Identifiant invalide'); return '"' + value + '"'; };
async function requeteLocale(q, uid) {
  return db.transaction(async tx => {
    await tx.query("SELECT set_config('request.jwt.claim.sub',$1,true)", [uid]);
    await tx.exec('SET LOCAL ROLE authenticated');
    const args = [];
    const arg = value => { args.push(value); return '$' + args.length; };
    let source;
    if (q.rpc) {
      assert.ok(fonctions.has(q.rpc));
      source = 'public.' + ident(q.rpc) + '(' + Object.entries(q.params).map(([key, value]) => ident(key) + ' => ' + arg(value)).join(',') + ')';
    } else { assert.ok(tables.has(q.table)); source = 'public.' + ident(q.table); }
    const where = q.filters.length ? ' WHERE ' + q.filters.map(([key, oper, value]) => {
      assert.ok(['=', '>=', '<=', 'in'].includes(oper));
      return ident(key) + (oper === 'in' ? ' = ANY(' + arg(value) + ')' : ' ' + oper + ' ' + arg(value));
    }).join(' AND ') : '';
    let sql;
    if (q.action === 'insert') {
      const cols = Object.keys(q.payload);
      sql = 'INSERT INTO ' + source + '(' + cols.map(ident).join(',') + ') VALUES (' + cols.map(k => arg(q.payload[k])).join(',') + ')';
    } else if (q.action === 'update') {
      sql = 'UPDATE ' + source + ' SET ' + Object.keys(q.payload).map(k => ident(k) + '=' + arg(q.payload[k])).join(',') + where + (q.columns ? ' RETURNING ' + q.columns.split(',').map(ident).join(',') : '');
    } else if (q.action === 'delete') sql = 'DELETE FROM ' + source + where;
    else {
      let colonnes = q.columns || '*';
      if (colonnes.includes('evenements(titre)')) colonnes = '*, (SELECT json_build_object(\'titre\', e.titre) FROM public.evenements e WHERE e.id = evenement_id) AS evenements';
      else if (colonnes !== '*') colonnes = colonnes.split(',').map(ident).join(',');
      sql = 'SELECT ' + (q.options?.head ? 'count(*)::int AS count' : colonnes) + ' FROM ' + source + where;
      if (!q.options?.head && q.orders.length) sql += ' ORDER BY ' + q.orders.map(([key, asc]) => ident(key) + (asc ? ' ASC' : ' DESC')).join(',');
      if (!q.options?.head && q.range) sql += ' LIMIT ' + arg(q.range[1] - q.range[0] + 1) + ' OFFSET ' + arg(q.range[0]);
    }
    const result = await tx.query(sql, args);
    return { data: q.options?.head ? null : q.single ? result.rows[0] || null : result.rows, count: q.options?.head ? result.rows[0].count : null, error: null };
  });
}
const photosLocales = new Map(); const photosSignees = new Map();
const server = createServer(async (req, res) => {
  try {
    if (req.url.startsWith('/__test__/avatar?')) {
      const token = new URL(req.url,'http://local').searchParams.get('token'); const photo=photosSignees.get(token);
      if(!photo){res.writeHead(403).end();return;}
      res.setHeader('Content-Type','image/webp');res.end(photo);return;
    }
    if(req.url.startsWith('/__test__/storage?') && req.method==='POST') {
      const uid=req.headers['x-test-user'];assert.ok([PAUL,ANNE,PRESIDENT,BUREAU,PARENT].includes(uid));
      const u=new URL(req.url,'http://local');const bucket=u.searchParams.get('bucket');const path=u.searchParams.get('path');const operation=u.searchParams.get('operation');
      assert.equal(bucket,'photos-profils');const morceaux=[];for await(const c of req)morceaux.push(c);const photo=Buffer.concat(morceaux);
      let resultat;
      try {
        if(operation==='upload') {assert.ok(photo.length<=524288);assert.equal(req.headers['content-type'],'image/webp');}
        const donnees=await db.transaction(async tx=>{
          await tx.query("SELECT set_config('request.jwt.claim.sub',$1,true)",[uid]);await tx.exec('SET LOCAL ROLE authenticated');
          if(operation==='sign') {
            const lignes=await tx.query('SELECT id FROM storage.objects WHERE bucket_id=$1 AND name=$2',[bucket,path]);
            if(!lignes.rows.length || !photosLocales.has(path))throw new Error('Photo absente ou accès refusé.');
          } else if(operation==='upload') {
            const existe=await tx.query('SELECT id FROM storage.objects WHERE bucket_id=$1 AND name=$2',[bucket,path]);
            if(existe.rows.length) await tx.query('UPDATE storage.objects SET name=$2 WHERE bucket_id=$1 AND name=$2',[bucket,path]);
            else await tx.query('INSERT INTO storage.objects(bucket_id,name) VALUES($1,$2)',[bucket,path]);
          } else if(operation==='remove') await tx.query('DELETE FROM storage.objects WHERE bucket_id=$1 AND name=$2',[bucket,path]);
          else throw new Error('Action stockage inconnue');
          return true;
        });
        if(donnees && operation==='upload')photosLocales.set(path,photo);
        if(donnees && operation==='remove')photosLocales.delete(path);
        let data={};if(operation==='sign') {const token=crypto.randomUUID();photosSignees.set(token,photosLocales.get(path));data={signedUrl:url+'/__test__/avatar?token='+token};}
        resultat={data,error:null};
      } catch(e){resultat={data:null,error:{message:e.message,code:e.code}};}
      res.setHeader('Content-Type','application/json');res.end(JSON.stringify(resultat));return;
    }
    if (req.url === '/__test__/sdk.js' || req.url === '/__test__/sdk-vendor.js') { res.setHeader('Content-Type', 'text/javascript'); res.end(sdk); return; }
    if (req.url === '/__test__/query' && req.method === 'POST') {
      let body = ''; for await (const chunk of req) body += chunk;
      const uid = req.headers['x-test-user'];
      assert.ok([PAUL, ANNE, PRESIDENT, BUREAU, PARENT].includes(uid));
      let data;
      try { data = await requeteLocale(JSON.parse(body), uid); }
      catch (e) { data = { data: null, error: { code: e.code, message: e.message } }; }
      res.setHeader('Content-Type', 'application/json'); res.end(JSON.stringify(data)); return;
    }
    const path = resolve(root, '.' + (req.url === '/' ? '/index-portail.html' : req.url.split('?')[0]));
    if (!path.startsWith(root + '/')) { res.writeHead(403).end(); return; }
    res.setHeader('Content-Type', { '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.png': 'image/png', '.woff2': 'font/woff2' }[extname(path)] || 'text/plain');
    res.end(req.url.split('?')[0] === '/js/vendor/supabase-2.49.4.js' ? sdk : await readFile(path));
  } catch { res.writeHead(404).end(); }
});
await new Promise(ok => server.listen(0, '127.0.0.1', ok));
const url = 'http://127.0.0.1:' + server.address().port;
let browser;
try {
  browser = await chromium.launch({ headless: true, args: ['--no-sandbox'],
    ...(process.env.ACHUS_CHROMIUM_PATH ? { executablePath: process.env.ACHUS_CHROMIUM_PATH } : {}) });
  const erreurs = [];
  async function pagePour(uid, largeur = 390) {
    const context = await browser.newContext({ viewport: { width: largeur, height: 844 }, locale: 'fr-HT', acceptDownloads: true });
    const page = await context.newPage();
    page.on('pageerror', error => erreurs.push(error.message));
    await page.addInitScript(uid => localStorage.setItem('achus-test-user', uid), uid);
    await page.route('https://cdn.jsdelivr.net/**', route => route.fulfill({ contentType: 'text/javascript', body: sdk }));
    // Aucun appel externe, y compris accidentel, pendant les tests.
    await page.route('https://**/*', route => {
      if (route.request().url().startsWith('https://cdn.jsdelivr.net/')) return route.fulfill({ contentType: 'text/javascript', body: sdk });
      return route.abort();
    });
    await page.goto(url);
    await page.locator('#ecran-app:not([hidden])').waitFor();
    return page;
  }
  async function nav(page, id) { await page.locator(`[data-page="${id}"]`).click(); await page.locator('#contenu[aria-busy="false"]').waitFor({ state: 'attached' }); }
  async function sansDebordement(page) { assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), true, 'Débordement horizontal de la page'); }

  console.log('→ connexion avec le véritable SDK local, démarrage lent, erreur, succès et session restaurée');
  const reel=await browser.newContext({viewport:{width:390,height:844},locale:'fr-HT'});
  const connexion=await reel.newPage();
  connexion.on('pageerror',e=>erreurs.push(e.message));
  let debloquerSdk;const sdkAttente=new Promise(ok=>debloquerSdk=ok);
  const vendorReel=await readFile(resolve(root,'js/vendor/supabase-2.49.4.js'),'utf8');
  await connexion.route('**/js/vendor/supabase-2.49.4.js',async route=>{await sdkAttente;await route.fulfill({contentType:'text/javascript',body:vendorReel});});
  let modeConnexion='erreur';
  const membreReel=(await requeteLocale({table:'membres',action:'select',columns:'*',filters:[['user_id','=',PAUL]],orders:[],options:{}},PAUL)).data;
  const encoder=v=>Buffer.from(JSON.stringify(v)).toString('base64url');
  const tokenFictif=encoder({alg:'HS256',typ:'JWT'})+'.'+encoder({sub:PAUL,exp:Math.floor(Date.now()/1000)+3600,iat:Math.floor(Date.now()/1000),aud:'authenticated',role:'authenticated'})+'.signature-locale-de-test';
  const utilisateurFictif={id:PAUL,email:'paul@example.ht',aud:'authenticated',role:'authenticated',app_metadata:{provider:'email',providers:['email']},user_metadata:{},created_at:new Date().toISOString()};
  await connexion.route('https://**/*',async route=>{
    const u=new URL(route.request().url());
    if(u.hostname!=='hyktpddailftuwmbakdm.supabase.co')return route.abort();
    const headers={'access-control-allow-origin':'*','access-control-allow-headers':'*','access-control-allow-methods':'GET,POST,HEAD,OPTIONS'};
    if(route.request().method()==='OPTIONS')return route.fulfill({status:204,headers});
    let status=200;let data=[];
    if(u.pathname==='/auth/v1/token') {
      if(modeConnexion==='erreur'){status=400;data={code:'invalid_credentials',msg:'Invalid login credentials'};}
      else data={access_token:tokenFictif,refresh_token:'jeton-fictif-local',token_type:'bearer',expires_in:3600,user:utilisateurFictif};
    } else if(u.pathname==='/auth/v1/user')data=utilisateurFictif;
    else if(u.pathname==='/rest/v1/membres')data=membreReel;
    else if(u.pathname.startsWith('/storage/')){status=404;data={message:'Photo absente'};}
    if(route.request().method()==='HEAD')headers['content-range']='*/0';
    return route.fulfill({status,headers,contentType:'application/json',body:route.request().method()==='HEAD'?'':JSON.stringify(data)});
  });
  await connexion.goto(url, { waitUntil: 'domcontentloaded' });
  await connexion.locator('#login-email').fill('paul@example.ht');
  await connexion.locator('#login-password').fill('mot-de-passe-fictif-local');
  await connexion.getByRole('button',{name:'Se connecter',exact:true}).click();
  await connexion.getByText('Connexion…',{exact:true}).waitFor();
  assert.equal(await connexion.getByRole('button',{name:'Connexion en cours…',exact:true}).isDisabled(),true);
  debloquerSdk();
  await connexion.getByText('E-mail ou mot de passe incorrect.',{exact:true}).waitFor();
  assert.equal(await connexion.getByRole('button',{name:'Se connecter',exact:true}).isEnabled(),true);
  modeConnexion='succes';
  await connexion.getByRole('button',{name:'Se connecter',exact:true}).click();
  await connexion.locator('#ecran-app:not([hidden])').waitFor();
  await connexion.getByRole('heading',{name:'Paul Joseph',exact:true}).waitFor();
  await connexion.reload();
  await connexion.locator('#ecran-app:not([hidden])').waitFor();
  await connexion.getByRole('heading',{name:'Paul Joseph',exact:true}).waitFor();
  await reel.close();
  // Test de visibilité des mots de passe sur la vraie page publique, avant toute connexion.
  const authContext = await browser.newContext({ viewport:{width:390,height:844} });
  const authPage = await authContext.newPage();
  await authPage.route('https://**/*', route=>route.abort());
  await authPage.goto(url);
  const motPasse = authPage.locator('#login-password');
  await motPasse.fill('Exemple-local-123');
  assert.equal(await motPasse.getAttribute('type'), 'password');
  await authPage.getByRole('button',{name:'Afficher le mot de passe',exact:true}).click();
  assert.equal(await motPasse.getAttribute('type'), 'text');
  assert.equal(await motPasse.inputValue(), 'Exemple-local-123');
  await authPage.getByRole('button',{name:'Masquer le mot de passe',exact:true}).click();
  assert.equal(await motPasse.getAttribute('type'), 'password');
  await authPage.getByRole('button',{name:'Adhésion',exact:true}).click();
  await authPage.locator('#reg-password').fill('Autre-exemple-123');
  await authPage.getByRole('button',{name:'Afficher le mot de passe',exact:true}).click();
  assert.equal(await authPage.locator('#reg-password').getAttribute('type'), 'text');
  await authContext.close();
  const membre = await pagePour(PAUL);
  console.log('→ membre : messagerie et présences');
  assert.equal(await membre.locator('[data-page="registre"]').count(), 0);
  await nav(membre, 'profil');
  const imageTest = await membre.evaluate(() => { const c=document.createElement('canvas');c.width=80;c.height=100;const ctx=c.getContext('2d');ctx.fillStyle='#B01C2A';ctx.fillRect(0,0,80,100);return c.toDataURL('image/png').split(',')[1]; });
  await membre.getByLabel('Choisir ma photo de profil',{exact:true}).setInputFiles({name:'profil.png',mimeType:'image/png',buffer:Buffer.from(imageTest,'base64')});
  await membre.getByRole('button',{name:'Enregistrer ma photo de profil',exact:true}).click();
  await membre.getByText('Photo de profil enregistrée.',{exact:true}).waitFor();
  await membre.locator('.photo-profil-form .avatar-profil img').waitFor();
  assert.equal((await db.query('SELECT count(*)::int AS n FROM storage.objects WHERE bucket_id=$1 AND name=$2',['photos-profils',paulId+'/avatar.webp'])).rows[0].n,1);
  // Remplacer et retirer sa photo avant de la remettre pour le mur.
  let ancienFormPhoto=await membre.locator('.photo-profil-form').elementHandle();
  await membre.getByLabel('Choisir ma photo de profil',{exact:true}).setInputFiles({name:'autre.png',mimeType:'image/png',buffer:Buffer.from(imageTest,'base64')});
  await membre.getByRole('button',{name:'Enregistrer ma photo de profil',exact:true}).click();
  await membre.waitForFunction(e=>!e.isConnected,ancienFormPhoto);
  await membre.locator('.photo-profil-form .avatar-profil img').waitFor();
  assert.equal((await db.query('SELECT count(*)::int AS n FROM storage.objects WHERE bucket_id=$1 AND name=$2',['photos-profils',paulId+'/avatar.webp'])).rows[0].n,1);
  ancienFormPhoto=await membre.locator('.photo-profil-form').elementHandle();
  membre.once('dialog',d=>d.accept());
  await membre.getByRole('button',{name:'Retirer ma photo de profil',exact:true}).click();
  await membre.waitForFunction(e=>!e.isConnected,ancienFormPhoto);
  assert.equal(await membre.locator('.photo-profil-form .avatar-profil img').count(),0);
  assert.equal((await db.query('SELECT count(*)::int AS n FROM storage.objects WHERE bucket_id=$1 AND name=$2',['photos-profils',paulId+'/avatar.webp'])).rows[0].n,0);
  ancienFormPhoto=await membre.locator('.photo-profil-form').elementHandle();
  await membre.getByLabel('Choisir ma photo de profil',{exact:true}).setInputFiles({name:'profil.png',mimeType:'image/png',buffer:Buffer.from(imageTest,'base64')});
  await membre.getByRole('button',{name:'Enregistrer ma photo de profil',exact:true}).click();
  await membre.waitForFunction(e=>!e.isConnected,ancienFormPhoto);
  await membre.locator('.photo-profil-form .avatar-profil img').waitFor();

  await membre.getByLabel('Grade à afficher sur ma carte', { exact: true }).fill('Sergent-chef');
  await membre.getByRole('button', { name: 'Enregistrer mon grade', exact: true }).click();
  await membre.getByText('Grade enregistré. Votre carte est actualisée.', { exact: true }).waitFor();
  assert.equal(await membre.locator('.doc-carte').getByText('SERGENT-CHEF', { exact: true }).count(), 1);
  assert.equal((await db.query('SELECT grade FROM public.membres WHERE id=$1', [paulId])).rows[0].grade, 'Sergent-chef');
  await membre.reload();
  await membre.locator('#ecran-app:not([hidden])').waitFor();
  await nav(membre, 'profil');
  assert.equal(await membre.getByLabel('Grade à afficher sur ma carte', {exact:true}).inputValue(), 'Sergent-chef');
  await mkdir(resolve(root, 'test-results'), { recursive: true });
  await membre.locator('.doc-carte').first().screenshot({path:resolve(root,'test-results/grade-personnel-carte.png')});
  await nav(membre, 'messages');
  assert.equal(await membre.locator('.message').count(), 1);
  assert.equal(await membre.evaluate(() => window.injection), undefined);
  await membre.getByRole('button', { name: 'Marquer comme lu', exact: true }).click();
  await membre.locator('#non-lus[hidden]').waitFor({ state: 'attached' });
  await membre.getByRole('button', { name: 'Nouveau message', exact: true }).click();
  await membre.getByLabel('Destinataire', { exact: true }).selectOption(anneId);
  await membre.getByLabel('Message (5 000 caractères maximum)', { exact: true }).fill('Bonjour Anne, message de contrôle.');
  await membre.getByRole('button', { name: 'Envoyer', exact: true }).click();
  await membre.locator('dialog').waitFor({ state: 'detached' });
  await membre.getByText('Bonjour Anne, message de contrôle.', { exact: true }).waitFor();
  assert.equal((await db.query('SELECT count(*)::int AS n FROM public.messages WHERE expediteur=$1 AND contenu=$2', [paulId, 'Bonjour Anne, message de contrôle.'])).rows[0].n, 1);
  await sansDebordement(membre);
  await nav(membre, 'presences');
  const selectSeance = membre.getByLabel('Réunion ou événement', { exact: true });
  const option = await selectSeance.locator('option').nth(1).getAttribute('value');
  assert.ok(option); await selectSeance.selectOption(option);
  await membre.getByRole('button', { name: 'Déclarer ma présence', exact: true }).click();
  await membre.getByText('Présence déclarée. Elle attend la validation du bureau.', { exact: true }).waitFor();
  assert.ok((await db.query('SELECT count(*)::int AS n FROM public.presences_evenements WHERE membre_id=$1 AND statut=$2', [paulId, 'en_attente'])).rows[0].n >= 2);
  await nav(membre, 'annonces');
  assert.equal(await membre.getByRole('button', { name: 'Publier', exact: true }).count(), 0);

  const admin = await pagePour(PRESIDENT);
  console.log('→ président : validation, registre et export complet');
  console.log('→ communauté, appels, réunions et accès parent');
  await nav(membre, 'accueil');
  await membre.locator('.mur-profil .avatar-profil img').waitFor();
  await sansDebordement(membre);
  await membre.evaluate(()=>window.scrollTo(0,0));
  await membre.screenshot({path:resolve(root,'test-results/accueil-mur-mobile.png'),fullPage:true});
  await nav(membre, 'fil');
  await membre.getByLabel('Votre publication', { exact: true }).fill('Bonjour ACHUS <img src=x onerror="window.injection=true">');
  await membre.getByRole('button', { name: 'Publier', exact: true }).click();
  await membre.getByText('Bonjour ACHUS <img src=x onerror="window.injection=true">', { exact: true }).waitFor();
  assert.equal(await membre.evaluate(() => window.injection), undefined);
  await membre.locator('.mur-publication .avatar-profil img').waitFor();
  await membre.getByRole('button',{name:'Mon mur',exact:true}).click();
  await membre.getByRole('button',{name:'Mon mur',exact:true,pressed:true}).waitFor();
  await membre.getByLabel('Votre commentaire', { exact: true }).fill('Prêt pour notre réunion.');
  const ancienCommenter = await membre.getByRole('button', { name: 'Commenter', exact: true }).elementHandle();
  await membre.getByRole('button', { name: 'Commenter', exact: true }).click();
  await membre.waitForFunction(e => !e.isConnected, ancienCommenter);
  await membre.getByRole('button', { name: 'Voir les commentaires', exact: true }).click();
  await membre.getByText('Prêt pour notre réunion.', { exact: true }).waitFor();
  await sansDebordement(membre);
  await mkdir(resolve(root, 'test-results'), { recursive: true });
  await membre.evaluate(() => window.scrollTo(0,0));
  await membre.screenshot({ path: resolve(root, 'test-results/communaute-mobile.png'), fullPage: true });
  await nav(membre, 'appels');
  await membre.getByLabel('Destinataire', { exact: true }).selectOption(anneId);
  await membre.getByLabel('Type d’appel', { exact: true }).selectOption('audio');
  await membre.getByRole('button', { name: 'Envoyer l’invitation', exact: true }).click();
  await membre.getByRole('button', { name: 'Annuler l’invitation', exact: true }).waitFor();
  const anne = await pagePour(ANNE, 1280);
  await nav(anne, 'appels');
  await anne.getByRole('button', { name: 'Accepter', exact: true }).click();
  const salle = anne.getByRole('link', { name: 'Rejoindre sur Jitsi', exact: true });
  await salle.waitFor(); assert.match(await salle.getAttribute('href'), /startWithVideoMuted=true/);
  assert.equal(await salle.getAttribute('rel'), 'noopener noreferrer');
  await anne.getByRole('button', { name: 'Terminer', exact: true }).click();
  await anne.getByText(/Audio.*Terminé/).waitFor();
  await sansDebordement(anne);
  await nav(anne,'fil');
  await anne.locator('.mur-publication .avatar-profil img').waitFor();
  await sansDebordement(anne);
  await anne.evaluate(()=>window.scrollTo(0,0));
  await anne.screenshot({path:resolve(root,'test-results/communaute-bureau.png'),fullPage:true});
  await nav(admin, 'reunions');
  await admin.getByLabel('Titre', { exact: true }).fill('Grande réunion ACHUS');
  const local = d => new Date(d).toISOString().slice(0,16);
  await admin.getByLabel('Début (heure de cet appareil)', { exact: true }).fill(local(Date.now()+3600000));
  await admin.getByLabel('Fin (heure de cet appareil, 12 h maximum)', { exact: true }).fill(local(Date.now()+7200000));
  await admin.getByRole('button', { name: 'Créer la réunion', exact: true }).click();
  await admin.getByRole('heading', { name: 'Grande réunion ACHUS', exact: true }).waitFor();
  await sansDebordement(admin);
  await admin.evaluate(() => window.scrollTo(0,0));
  await admin.screenshot({ path: resolve(root, 'test-results/reunions-mobile.png'), fullPage: true });
  await nav(admin, 'famille');
  await admin.getByLabel('Parent actif', { exact: true }).selectOption(parentId);
  await admin.getByLabel('Enfant / membre', { exact: true }).selectOption(paulId);
  await admin.getByRole('button', { name: 'Valider le lien familial', exact: true }).click();
  await admin.getByRole('button', { name: 'Retirer l’accès du parent', exact: true }).waitFor();
  const parent = await pagePour(PARENT);
  await nav(parent, 'famille');
  await parent.getByRole('heading', { name: 'Paul Joseph', exact: true }).waitFor();
  await parent.getByText(/Réunion de contrôle.*En attente/).waitFor();
  await sansDebordement(parent);
  await parent.evaluate(() => window.scrollTo(0,0));
  await parent.screenshot({ path: resolve(root, 'test-results/parents-mobile.png'), fullPage: true });
  await nav(parent, 'messages');
  await parent.getByRole('button', { name: 'Nouveau message', exact: true }).click();
  assert.equal(await parent.getByLabel('Destinataire', { exact: true }).locator(`option[value="${anneId}"]`).count(), 0);
  await parent.keyboard.press('Escape');
  admin.once('dialog', d => d.accept());
  await admin.getByRole('button', { name: 'Retirer l’accès du parent', exact: true }).click();
  await admin.getByRole('button', { name: 'Retirer l’accès du parent', exact: true }).waitFor({state:'detached'});
  await nav(parent, 'famille');
  await parent.getByText(/Aucun enfant n’est rattaché/).waitFor();
  await nav(admin, 'presences-admin');
  await admin.getByLabel('Séance', { exact: true }).selectOption(EVENEMENT + '/' + hier);
  await admin.getByRole('button', { name: 'Approuver la présence de Paul Joseph', exact: true }).click();
  await admin.getByRole('button', { name: 'Confirmer la décision', exact: true }).click();
  await admin.locator('dialog').waitFor({ state: 'detached' });
  assert.equal((await db.query('SELECT statut FROM public.presences_evenements WHERE membre_id=$1 AND evenement_id=$2', [paulId, EVENEMENT])).rows[0].statut, 'approuvee');
  await sansDebordement(admin);
  await nav(admin, 'registre');
  await admin.getByLabel('Rechercher', { exact: true }).fill('Pagination');
  assert.equal(await admin.locator('tbody tr').count(), 25);
  const exportComplet = admin.waitForEvent('download');
  await admin.getByRole('button', { name: 'Exporter la sélection en CSV', exact: true }).click();
  const complet = await readFile(await (await exportComplet).path(), 'utf8');
  assert.equal(complet.split('\r\n').length, 1006, 'Export de plus de 1000 membres tronqué');
  await admin.getByLabel('Rechercher', { exact: true }).fill('Paul');
  assert.equal(await admin.locator('tbody tr').count(), 1);
  const telechargement = admin.waitForEvent('download');
  await admin.getByRole('button', { name: 'Exporter la sélection en CSV', exact: true }).click();
  const csv = await readFile(await (await telechargement).path(), 'utf8');
  assert.ok(csv.startsWith('\uFEFF')); assert.ok(csv.includes('Joseph')); assert.ok(!csv.includes('Louis'));
  await sansDebordement(admin);
  await admin.getByRole('button', { name: 'Gérer', exact: true }).click();
  await admin.getByRole('button', { name: 'Retirer ou suspendre', exact: true }).click();
  await admin.getByLabel('Nouveau statut', { exact: true }).selectOption('suspendu');
  await admin.getByLabel('Motif obligatoire', { exact: true }).fill('Absences répétées constatées par le bureau.');
  await admin.getByRole('button', { name: 'Confirmer le retrait', exact: true }).click();
  await admin.locator('dialog').waitFor({ state: 'detached' });
  assert.equal((await db.query('SELECT statut FROM public.membres WHERE id=$1', [paulId])).rows[0].statut, 'suspendu');
  await nav(membre, 'messages');
  await membre.getByText('Cette fonction attend la mise à jour de la base. Contactez le président.', { exact: true }).waitFor({ state: 'hidden' });
  assert.equal(await membre.locator('.message').count(), 0, 'RLS doit bloquer le membre retiré immédiatement');

  const bureau = await pagePour(BUREAU, 1280);
  console.log('→ bureau : droits limités ; président : double confirmation');
  await nav(bureau, 'registre');
  await bureau.getByLabel('Statut', { exact: true }).selectOption('suspendu');
  await bureau.getByRole('button', { name: 'Gérer', exact: true }).click();
  assert.equal(await bureau.getByRole('button', { name: 'Supprimer définitivement', exact: true }).count(), 0);
  assert.equal(await bureau.getByLabel('Rôle', { exact: true }).isDisabled(), true);
  await bureau.keyboard.press('Escape');

  await nav(admin, 'registre');
  await admin.getByLabel('Statut', { exact: true }).selectOption('suspendu');
  await admin.getByRole('button', { name: 'Gérer', exact: true }).click();
  await admin.getByRole('button', { name: 'Supprimer définitivement', exact: true }).click();
  assert.equal(await admin.getByRole('button', { name: 'Continuer vers la deuxième confirmation', exact: true }).isDisabled(), true);
  await admin.locator('dialog input[type="checkbox"]').check();
  await admin.getByRole('button', { name: 'Continuer vers la deuxième confirmation', exact: true }).click();
  await admin.getByLabel('Recopiez : ' + paulNumero, { exact: true }).fill('MAUVAIS');
  await admin.getByLabel('Recopiez : SUPPRIMER DÉFINITIVEMENT', { exact: true }).fill('SUPPRIMER DÉFINITIVEMENT');
  await admin.getByRole('button', { name: 'Confirmer la suppression définitive', exact: true }).click();
  assert.equal((await db.query('SELECT count(*)::int AS n FROM public.membres WHERE id=$1', [paulId])).rows[0].n, 1);
  await admin.getByLabel('Recopiez : ' + paulNumero, { exact: true }).fill(paulNumero);
  await admin.getByRole('button', { name: 'Confirmer la suppression définitive', exact: true }).click();
  await admin.locator('dialog').waitFor({ state: 'detached' });
  assert.equal((await db.query('SELECT count(*)::int AS n FROM public.membres WHERE id=$1', [paulId])).rows[0].n, 0);
  assert.equal((await db.query('SELECT count(*)::int AS n FROM app_private.numeros_reserves WHERE numero=$1', [paulNumero])).rows[0].n, 1);
  await nav(admin, 'journal');
  await admin.getByText('Fiche supprimée', { exact: true }).waitFor();
  await sansDebordement(admin);
  await mkdir(resolve(root, 'test-results'), { recursive: true });
  await admin.screenshot({ path: resolve(root, 'test-results/journal-mobile.png'), fullPage: true });
  await nav(admin, 'registre');
  await admin.screenshot({ path: resolve(root, 'test-results/registre-mobile.png'), fullPage: true });
  assert.deepEqual(erreurs, []);
  console.log('INTERFACE_OK : mots de passe, grade/carte, photo de profil, accueil/mur, messages, présences, CSV, appels, réunions, parents et droits.');
} catch (error) {
  await mkdir(resolve(root, 'test-results'), { recursive: true });
  if (browser) {
    for (const [index, context] of browser.contexts().entries()) {
      const page = context.pages()[0];
      if (page) {
        console.error('Écran de test', index, (await page.locator('body').innerText()).slice(-3500));
        await page.screenshot({ path: resolve(root, 'test-results/echec-' + index + '.png'), fullPage: true });
      }
    }
  }
  throw error;
} finally {
  if (browser) await browser.close();
  await new Promise(ok => server.close(ok));
  await db.close();
}
