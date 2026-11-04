// Secours pour les navigateurs qui lisent WebP sans savoir l'encoder (Safari).
import creerEncodeur from './vendor/webp-1.5.0/webp_enc.js';
import { defaultOptions } from './vendor/webp-1.5.0/meta.js';

let chargement;
export async function encoderPhoto(pixels) {
  if (!chargement) {
    chargement = (async () => {
      const controle = new AbortController();
      const timer = setTimeout(() => controle.abort(), 20000);
      try {
        const reponse = await fetch(new URL('./vendor/webp-1.5.0/webp_enc.wasm', import.meta.url), { signal: controle.signal });
        if (!reponse.ok) throw new Error('Encodeur indisponible.');
        return await creerEncodeur({ wasmBinary: await reponse.arrayBuffer(), noInitialRun: true });
      } finally { clearTimeout(timer); }
    })().catch(e => { chargement = null; throw e; });
  }
  const encodeur = await chargement;
  const resultat = encodeur.encode(pixels.data, pixels.width, pixels.height, { ...defaultOptions, quality: 82 });
  if (!resultat) throw new Error('Conversion impossible.');
  return new Blob([resultat], { type: 'image/webp' });
}
