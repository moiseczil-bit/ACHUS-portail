# Portail ACHUS — à lire avant de mettre en ligne

Association Corps d'Honneur Universel de Santo, Santo 13, Croix-des-Bouquets.
Slogan : « Lajenès se lavni peyi an ».

Ce document est pour la personne qui gère le site, pas pour un développeur.

## Ce qui a été fait

- Les demandes d'adhésion sont vraiment enregistrées. Avant, le site disait « candidature envoyée » même quand la base refusait la fiche (il manquait le numéro automatique, le prénom, et l'erreur était cachée).
- Le formulaire demande : nom, prénom, téléphone, e-mail, mot de passe, quartier, programme, motivation. Personne ne peut plus se choisir « modérateur ».
- Dès qu'un compte est créé, une fiche « en attente » est créée toute seule, même si la personne doit encore confirmer son e-mail.
- Les comptes déjà créés qui n'avaient pas de fiche en reçoivent une « en attente » (le nom peut être « — » s'il n'avait pas été enregistré). Les 2 fiches déjà présentes et les 5 comptes de connexion sont conservés.
- Le président actuel reçoit le numéro **ACHUS-001**. Les suivants seront ACHUS-002, ACHUS-003, sans doublon, au moment où le bureau clique sur Approuver. L'autre fiche déjà active ne reçoit pas de numéro toute seule : dans le registre, enregistrez-la avec le statut Actif pour lui en donner un.
- Le bureau (président ou membre du bureau) voit les demandes, approuve ou refuse, change le statut (Actif, Inactif, Suspendu, Honoraire, En attente, Refusé), corrige le grade et la fonction en toutes lettres, exporte un fichier CSV pour Excel, publie des annonces et gère l'agenda.
- Chaque membre voit son profil, peut ajouter sa photo, et télécharge sa carte (PNG et PDF, format carte bancaire 85,6 × 54 mm). Le certificat (page A4 paysage) est réservé aux membres actifs ou honoraires qui ont un numéro.
- L'agenda rappelle la réunion du samedi à 9 h et la Fête du Drapeau le 18 mai.
- Les contacts sont affichés : WhatsApp +509 39 18 0332, achushaiti@gmail.com.
- Les données des membres ne sont plus lisibles par n'importe qui sur Internet. Chacun ne voit que sa fiche. Le bureau voit l'ensemble. La clé visible dans le site ne permet plus de se nommer admin.
- Un petit appel automatique, deux fois par semaine, évite que Supabase mette le projet en pause.

## Ce qui reste à faire (par vous)

1. Appliquer le fichier SQL (voir plus bas). Tant que ce n'est pas fait, le nouveau site ne peut pas enregistrer les demandes.
2. Ajouter deux secrets sur GitHub (voir plus bas), sinon le réveil automatique échoue.
3. Déployer ce code sur Netlify (ou fusionner la demande, si Netlify est déjà relié au dépôt).
4. Vérifier l'adresse du site dans Supabase Auth.
5. Donner le rôle « bureau » aux autres responsables, depuis le registre (une fois connecté comme président).

Le live, les votes et la galerie de groupe ne sont pas refaits dans cet écran. Les tables existent et sont protégées. On pourra les rebrancher plus tard.

## Checklist de test sur iPhone

Ouvrez Safari. Allez sur le site. Largeur d'un iPhone : tout doit tenir sans défilement horizontal gênant.

1. Sur l'écran d'accueil, ouvrez **Adhésion**. Vérifiez les champs : prénom, nom, téléphone, e-mail, mot de passe, quartier, programme, motivation. Il n'y a pas de choix « modérateur ».
2. Envoyez une demande avec un nouvel e-mail. Vous devez voir un message clair : succès, ou l'erreur exacte. Vous ne devez plus voir « envoyée » si ça a échoué.
3. Si un e-mail de confirmation arrive, ouvrez-le (regardez aussi les indésirables), puis connectez-vous. La fiche existe déjà avant cette confirmation.
4. Le membre en attente voit un bandeau « en attente », ses contacts, et l'agenda (samedi 9 h, 18 mai). Il ne voit pas le menu Bureau.
5. Rechargez la page : vous devez rester connecté.
6. Déconnectez-vous, puis connectez-vous avec le compte du président.
7. Ouvrez **Demandes**. La nouvelle personne apparaît, avec quartier et motivation. **Approuver**. Son numéro doit être ACHUS-002 (le président reste ACHUS-001). Approuver une deuxième fois ne doit pas changer le numéro.
8. Ouvrez **Registre**. Filtrez « Actif ». Changez un grade en écrivant un texte (par exemple « Caporal »), pas un chiffre. Changez un statut. **Exporter CSV** : le fichier s'ouvre dans Excel avec les accents corrects.
9. Publiez une annonce, ajoutez un rendez-vous, supprimez-les pour vérifier.
10. Sur le profil d'un membre actif : envoyez une photo, puis **Télécharger PNG** et **Télécharger PDF**. La carte a deux faces. Le PDF fait la taille d'une carte bancaire.
11. **Télécharger le certificat** : le nom, le grade, la fonction, le numéro, « Membre depuis le … », « Fait à Santo, le … », la référence CERT-ACHUS-00X, la signature du président Moïse-Son Sorel Cezil, et la ligne du secrétaire laissée vide.
12. Depuis le registre, le président peut ouvrir la carte et le certificat d'un autre membre, et imprimer (réglage d'impression : A4 paysage, marges aucune, arrière-plan graphique activé).
13. Touchez le lien WhatsApp : il ouvre une discussion vers +509 39 18 0332.

## Mettre en ligne

### 1. Appliquer la migration (c'est vous qui le faites)

Fichier exact :

`supabase/migrations/20261104120000_portail_refonte.sql`

Dans Supabase : projet **hyktpddailftuwmbakdm** → **SQL Editor** → New query → collez **tout** le fichier → Run.

Le fichier contient déjà `BEGIN` et `COMMIT`. Ne l'entourez pas d'un autre BEGIN.

Il ne supprime aucune fiche et aucun compte. Il peut être relancé s'il s'arrête au milieu (il reprend proprement). À la fin, le président existant est ACHUS-001 et les demandes en attente des anciens comptes apparaissent.

N'ajoutez jamais la clé `service_role` dans le site. Elle ne doit pas quitter Supabase.

### 2. Netlify

Le portail est publié sur le site Netlify `luxury-snickerdoodle-b2bd70` (domaine portail.achussantohaiti.com) par déploiement manuel. Pour l'auto-déploiement, lier ce site au dépôt dans Netlify.

Le dépôt contient `netlify.toml`. Il n'y a **pas** de commande de build. Le dossier publié est la racine. L'adresse `/` affiche `index-portail.html`.

Si le site est déjà relié à GitHub : fusionnez la demande, Netlify publie tout seul.

Sinon : Netlify → Add new site → Import from Git → ce dépôt. Build command : laissez vide. Publish directory : `.`

### 3. Les deux secrets GitHub (clics)

1. Ouvrez [https://github.com/moiseczil-bit/ACHUS-portail/settings/secrets/actions](https://github.com/moiseczil-bit/ACHUS-portail/settings/secrets/actions).
2. Cliquez **New repository secret**.
3. Name : `SUPABASE_URL`  
   Secret : `https://hyktpddailftuwmbakdm.supabase.co`  
   **Add secret**.
4. Encore **New repository secret**.
5. Name : `SUPABASE_ANON_KEY`  
   Secret : la clé « anon » ou « publishable » (Supabase → Project Settings → API). C'est la même clé déjà utilisée par le site.  
   **Add secret**.
6. Onglet **Actions** du dépôt → à gauche **Supabase keep-alive** → **Run workflow** → **Run workflow**.
7. Le rond doit devenir vert. S'il est rouge : la migration n'est pas encore appliquée, ou un secret est mal collé (espace en trop, mauvaise adresse).

### 4. Réglages Supabase Auth à vérifier

Authentication → URL configuration :

- **Site URL** = `https://portail.achussantohaiti.com`
- **Redirect URLs** : ajoutez `https://portail.achussantohaiti.com`

Authentication → Providers → Email :

- La confirmation d'e-mail peut rester activée. Le portail l'explique. La fiche « en attente » est créée quand même.
- Regardez qu'un e-mail de test arrive bien (les envois gratuits de Supabase sont limités).

## Le keep-alive (anti-pause)

Sur l'offre gratuite, Supabase endort un projet qui ne reçoit aucune visite pendant environ une semaine. Le fichier `.github/workflows/supabase-keepalive.yml` appelle l'adresse du projet **le lundi et le jeudi à 12 h UTC** (et quand vous cliquez sur Run workflow). Il appelle la fonction `ping`, qui répond l'heure, sans lire la liste des membres. Si la réponse n'est pas un succès, le contrôle devient rouge : vous le voyez dans l'onglet Actions.

## Dépôt public ou privé

Le rendre privé est **facultatif**. La clé anon est faite pour être dans le navigateur : tout visiteur du site peut la voir. Elle ne devient dangereuse que si la base laisse tout modifier. Après cette migration, un visiteur ne peut plus lire les membres ni se donner un rôle. La clé secrète `service_role`, elle, ne doit jamais être publiée — elle n'est pas dans ce dépôt.
