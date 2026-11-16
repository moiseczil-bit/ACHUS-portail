// Publication statique uniquement : aucun SQL, test ou fichier de configuration privé.
import { readdir, readFile, mkdir, writeFile, rm } from 'node:fs/promises';
import { resolve, relative, extname, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const racine = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sortie = resolve(racine, 'dist');
const extensions = new Set(['.js', '.css', '.wasm', '.png', '.jpg', '.jpeg', '.webp', '.svg', '.woff', '.woff2', '.ttf', '.txt', '.md']);
async function fichiers(dossier) {
  const liste = [];
  for (const entree of await readdir(resolve(racine, dossier), { withFileTypes: true })) {
    const chemin = `${dossier}/${entree.name}`;
    if (entree.isDirectory()) liste.push(...await fichiers(chemin));
    else if (entree.isFile() && !entree.name.startsWith('.') && (extensions.has(extname(entree.name)) || entree.name === 'LICENSE')) liste.push(chemin);
    else throw new Error(`Fichier non prévu pour publication : ${chemin}`);
  }
  return liste;
}
const liste = ['index-portail.html', 'reinitialiser.html'];
for (const dossier of ['js', 'css', 'assets']) liste.push(...await fichiers(dossier));
await rm(sortie, { recursive: true, force: true });
for (const chemin of liste) {
  const cible = resolve(sortie, chemin);
  if (relative(sortie, cible).startsWith('..')) throw new Error('Chemin invalide.');
  await mkdir(dirname(cible), { recursive: true });
  await writeFile(cible, await readFile(resolve(racine, chemin)));
}
console.log(`${liste.length} fichiers statiques préparés dans dist/.`);
