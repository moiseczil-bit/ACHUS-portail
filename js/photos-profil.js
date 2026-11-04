// Une photo communautaire par membre ; les photos de carte restent privées.
const nom = m => [m?.prenom,m?.nom].filter(Boolean).join(' ') || 'Membre ACHUS';
const n = (tag, classe, texte) => { const e=document.createElement(tag); e.className=classe||''; if(texte!=null)e.textContent=texte; return e; };
export function creerPhotosProfil({client,profil,toast,actualiser}) {
  const cache = new Map();
  const eligible = () => ['actif','honoraire'].includes(profil()?.statut);
  async function url(m) {
    if(!eligible() || !m?.id || m.photo_profil===false) return '';
    const cle=profil().id+'/'+m.id; const ancien=cache.get(cle);
    if(ancien && ancien.expire>Date.now()) return ancien.promesse;
    if(cache.size>200) cache.clear();
    const promesse=(async()=> {
      try {
        const {data,error}=await client().storage.from('photos-profils').createSignedUrl(m.id+'/avatar.webp',900);
        if(error || !data?.signedUrl) return '';
        const u=new URL(data.signedUrl,location.origin);
        if(u.origin!==location.origin && (u.protocol!=='https:' || u.hostname!=='hyktpddailftuwmbakdm.supabase.co')) return '';
        u.searchParams.set('v',String(Date.now())); return u.href;
      } catch { return ''; }
    })();
    cache.set(cle,{promesse,expire:Date.now()+120000}); return promesse;
  }
  function avatar(m,grand=false) {
    const cercle=n('span','avatar-profil'+(grand?' avatar-grand':''));
    const lettres=n('span','avatar-initiales',nom(m).split(/\s+/u).filter(Boolean).slice(0,2).map(x=>x[0]).join('').toUpperCase());
    lettres.setAttribute('aria-hidden','true'); cercle.setAttribute('role','img'); cercle.setAttribute('aria-label','Photo de profil de '+nom(m)); cercle.append(lettres);
    const lecteur=profil()?.id;
    url(m).then(src=> {
      if(!src || profil()?.id!==lecteur || !eligible()) return;
      const image=n('img'); image.alt=''; image.width=grand?96:44; image.height=grand?96:44; image.loading='eager'; image.referrerPolicy='no-referrer';
      image.onload=()=>{if(profil()?.id===lecteur){cercle.replaceChildren(image);} }; image.src=src;
    }); return cercle;
  }
  async function reduire(file) {
    if(!file || !['image/jpeg','image/png','image/webp'].includes(file.type)) throw new Error('Choisissez une photo JPG, PNG ou WebP.');
    if(file.size>5*1024*1024) throw new Error('La photo doit peser moins de 5 Mo.');
    let bitmap;
    try {
      try { bitmap=await createImageBitmap(file); }
      catch {
        const src=URL.createObjectURL(file);
        try {
          bitmap=await new Promise((ok,refuser)=>{
            const image=new Image(); image.onload=()=>ok(image);
            image.onerror=()=>refuser(new Error('Cette image ne peut pas être lue. Choisissez une photo JPG, PNG ou WebP.'));
            image.src=src;
          });
        } finally { URL.revokeObjectURL(src); }
      }
      if(!bitmap.width || !bitmap.height || bitmap.width*bitmap.height>40000000) throw new Error('Dimensions de photo trop grandes.');
      const canvas=document.createElement('canvas'); canvas.width=512; canvas.height=512;
      const ctx=canvas.getContext('2d'); const cote=Math.min(bitmap.width,bitmap.height);
      ctx.drawImage(bitmap,(bitmap.width-cote)/2,(bitmap.height-cote)/2,cote,cote,0,0,512,512);
      let blob=await new Promise(ok=>canvas.toBlob(ok,'image/webp',0.82));
      if(!blob || blob.type!=='image/webp') {
        try {
          const {encoderPhoto}=await import('./encoder-photo.js');
          blob=await encoderPhoto(ctx.getImageData(0,0,512,512));
        } catch { throw new Error('La conversion de la photo a échoué. Vérifiez votre connexion puis réessayez.'); }
      }
      if(!blob || blob.type!=='image/webp' || blob.size>524288) throw new Error('Impossible de préparer cette photo. Essayez une autre image.');
      return blob;
    } finally {bitmap?.close?.();}
  }
  function formulaire() {
    const root=n('section','panneau photo-profil-form'); root.append(n('h3','','Ma photo de profil'));
    root.append(n('p','meta','Visible par les comptes actifs de la communauté. La photo sera recadrée au centre en carré. Votre photo de carte reste distincte.'));
    root.append(avatar(profil(),true));
    const form=n('form'); const label=n('label','champ'); label.append(n('span','','Choisir ma photo de profil'));
    const fichier=n('input'); fichier.type='file'; fichier.accept='image/jpeg,image/png,image/webp'; fichier.required=true; label.append(fichier); form.append(label);
    const enregistrer=n('button','btn btn-navy','Enregistrer ma photo de profil'); enregistrer.type='submit';
    const retirer=n('button','btn btn-ghost','Retirer ma photo de profil'); retirer.type='button'; form.append(enregistrer,retirer); root.append(form);
    const agir=async fn=>{
      enregistrer.disabled=true;retirer.disabled=true;
      try {await fn();cache.clear(); await actualiser();}
      catch(e){toast(e.message||'Impossible de mettre à jour la photo.','error');}
      finally {enregistrer.disabled=false;retirer.disabled=false;}
    };
    form.onsubmit=e=>{e.preventDefault();const membre=profil()?.id;agir(async()=>{
      const blob=await reduire(fichier.files[0]);
      if(profil()?.id!==membre)throw new Error('Votre session a changé.');
      const {error}=await client().storage.from('photos-profils').upload(membre+'/avatar.webp',blob,{upsert:true,contentType:'image/webp',cacheControl:'0'});
      if(error)throw error; toast('Photo de profil enregistrée.');
    });};
    retirer.onclick=()=>{if(window.confirm('Retirer votre photo de profil de la communauté ?'))agir(async()=>{
      const {error}=await client().storage.from('photos-profils').remove([profil().id+'/avatar.webp']);
      if(error)throw error;toast('Photo de profil retirée.');
    });}; return root;
  }
  return {avatar,formulaire};
}
