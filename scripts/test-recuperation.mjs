// Véritable SDK Supabase, API Auth fictive : aucun courriel ni mot de passe réel.
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile,mkdir} from 'node:fs/promises';
import {resolve,extname} from 'node:path';
import {chromium} from 'playwright';
const root=resolve(new URL('..',import.meta.url).pathname);
const server=createServer(async(req,res)=>{try{
 const p=resolve(root,'.'+(req.url.split('?')[0]==='/'?'/index-portail.html':req.url.split('?')[0]));
 if(!p.startsWith(root+'/')){res.writeHead(403).end();return;}
 res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.woff2':'font/woff2'})[extname(p)]||'application/octet-stream');res.end(await readFile(p));
}catch{res.writeHead(404).end();}});
await new Promise(ok=>server.listen(0,'127.0.0.1',ok));
const url='http://127.0.0.1:'+server.address().port;
const browser=await chromium.launch({headless:true,args:['--no-sandbox'],...(process.env.ACHUS_CHROMIUM_PATH?{executablePath:process.env.ACHUS_CHROMIUM_PATH}:{})});
let demandes=0,changements=0,mode='succes';
const user={id:'99999999-9999-4999-8999-999999999999',email:'fictif@example.ht',aud:'authenticated',role:'authenticated',app_metadata:{provider:'email'},user_metadata:{}};
const b64=x=>Buffer.from(JSON.stringify(x)).toString('base64url');
const token=b64({alg:'HS256',typ:'JWT'})+'.'+b64({sub:user.id,exp:Math.floor(Date.now()/1000)+3600,aud:'authenticated'})+'.signature-test';
async function page(){const c=await browser.newContext({viewport:{width:390,height:844}});const p=await c.newPage();
 await p.route('https://**/*',async route=>{const req=route.request(),u=new URL(req.url());if(u.hostname!=='hyktpddailftuwmbakdm.supabase.co')return route.abort();
 const headers={'access-control-allow-origin':'*','access-control-allow-headers':'*','access-control-allow-methods':'GET,POST,PUT,OPTIONS'};
 if(req.method()==='OPTIONS')return route.fulfill({status:204,headers});
 let data={},status=200;
 if(u.pathname==='/auth/v1/recover'){
  demandes++;assert.equal(req.postDataJSON().email,'fictif@example.ht');assert.equal(u.searchParams.get('redirect_to'),'https://portail.achussantohaiti.com/');
  if(mode==='limite'){status=429;data={msg:'Email rate limit exceeded'};}
 }else if(u.pathname==='/auth/v1/user'){
  if(req.method()==='PUT'){changements++;assert.equal(req.postDataJSON().password,'Nouveau-test-fictif-123');}
  data=user;
 }else if(u.pathname==='/auth/v1/logout')data={};else return route.abort();
 return route.fulfill({status,headers,contentType:'application/json',body:JSON.stringify(data)});
 });return {p,c};}
try{
 let {p,c}=await page();await p.goto(url);await p.getByRole('link',{name:'Mot de passe oublié ?'}).click();
 await p.getByLabel('Adresse e-mail',{exact:true}).fill('fictif@example.ht');mode='limite';await p.getByRole('button',{name:'Envoyer le lien de réinitialisation'}).click();
 await p.getByText('Trop de demandes rapprochées.',{exact:false}).waitFor();assert.equal(await p.getByRole('button',{name:'Envoyer le lien de réinitialisation'}).isEnabled(),true);
 mode='succes';await p.getByRole('button',{name:'Envoyer le lien de réinitialisation'}).click();await p.getByText('Si un compte correspond à cette adresse,',{exact:false}).waitFor();assert.equal(demandes,2);await c.close();
 ({p,c}=await page());await p.goto(url+'/#error=access_denied&error_code=otp_expired');await p.getByText('Ce lien est expiré ou déjà utilisé.',{exact:false}).waitFor();assert.equal(await p.locator('#nouveau-mot-de-passe').isVisible(),false);assert.equal(changements,0);await c.close();
 ({p,c}=await page());await p.goto(url+'/#access_token='+token+'&refresh_token=jeton-fictif&expires_in=3600&token_type=bearer&type=recovery');
 await p.getByText('Lien vérifié. Vous pouvez choisir votre nouveau mot de passe.').waitFor();
 assert.equal(await p.locator('#nouveau-mot-de-passe').isVisible(),true);assert.equal(await p.locator('#ecran-app').count(),0);
 assert.equal(new URL(p.url()).hash,'');
 await p.getByLabel('Nouveau mot de passe',{exact:true}).fill('Nouveau-test-fictif-123');await p.getByLabel('Confirmer le nouveau mot de passe',{exact:true}).fill('Different-fictif-123');
 await p.getByRole('button',{name:'Enregistrer mon nouveau mot de passe'}).click();await p.getByText('Les deux mots de passe ne correspondent pas.').waitFor();assert.equal(changements,0);
 await p.getByLabel('Confirmer le nouveau mot de passe',{exact:true}).fill('Nouveau-test-fictif-123');await p.getByRole('button',{name:'Afficher les mots de passe'}).click();assert.equal(await p.locator('#nouveau-password').getAttribute('type'),'text');
 await p.getByRole('button',{name:'Masquer les mots de passe'}).click();await p.getByRole('button',{name:'Enregistrer mon nouveau mot de passe'}).click();
 await p.getByText('Votre mot de passe a été modifié.',{exact:false}).waitFor();assert.equal(changements,1);
 assert.equal(await p.locator('#nouveau-password').inputValue(),'');assert.equal(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
 await mkdir(resolve(root,'test-results'),{recursive:true});await p.screenshot({path:resolve(root,'test-results/recuperation-mobile.png')});await c.close();
 console.log('RECUPERATION_OK : demande, limite, lien expiré, retour accueil, véritable SDK, confirmation et mise à jour fictive.');
}finally{await browser.close();await new Promise(ok=>server.close(ok));}
