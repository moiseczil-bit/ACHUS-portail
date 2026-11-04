# Portail ACHUS — à lire avant de mettre en ligne

Association Corps d'Honneur Universel de Santo, Santo 13, Croix-des-Bouquets.
Slogan : « Lajenès se lavni peyi an ».

Ce document est pour la personne qui gère le site, pas pour un développeur.

**Mise en service du 4 novembre 2026** : les migrations `messagerie_presences_registre` et `correction_suppression_dependances` sont appliquées sur ACHUS. Les 6 fiches et les 5 comptes existants sont conservés. La version du commit `f430855d3aa8a31892d01e12bcf442d206432262` est publiée sur le site Netlify existant, déploiement `6aeb3d4191f8a708de90d088`. Les fichiers HTML/JS/CSS servis sur le domaine ont été comparés au dépôt. Le menu **Messagerie** apparaît après connexion pour les comptes au statut **Actif**.

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
- **Messagerie** : réception, messages envoyés, réponse, pagination et badge de non-lus. Seuls les membres au statut **Actif** y accèdent. Même le bureau ne lit que ses propres échanges. Le destinataire peut marquer un message comme lu ; le contenu, l’auteur et la date ne sont pas modifiables. L’annuaire ne donne que le nom et le numéro des membres actifs ayant un compte. Les annonces du bureau sont maintenant lisibles depuis le menu des membres actifs et honoraires.
- **Présences** : les membres actifs ou honoraires déclarent une séance passée de l’agenda ; elle reste **En attente** jusqu’à la décision d’un autre responsable. Le bureau approuve ou refuse avec un motif. Une même séance ne peut pas être déclarée deux fois. Chaque samedi constitue une séance différente, en heure d’Haïti.
- **Suivi du bureau** : tableau par réunion avec « Non déclarée », export CSV, taux par membre sur une période de 366 jours maximum. Le taux compte les présences approuvées sur toutes les séances passées de l’agenda depuis l’adhésion, y compris celles sans déclaration. Les archives anciennes et les périodes de suspension historiques ne sont pas déduites de ce calcul. Un événement avec des déclarations ne peut plus être supprimé.
- **Registre** : filtre **Actif** à l’ouverture, recherche par nom/numéro/grade/fonction, filtres de statut, grade, fonction et validité, tri sur les colonnes demandées, pagination et export de toute la sélection. Les CSV gardent les accents et neutralisent les cellules pouvant être interprétées comme des formules dans Excel.
- **Retrait** : bouton **Gérer** → **Retirer ou suspendre**, avec motif et date obligatoires. Le retrait prend effet immédiatement ; la date saisie documente la décision. L’historique est conservé. Le numéro ACHUS ne change jamais et reste réservé après suppression. Les numéros à quatre chiffres sont pris en charge.
- **Suppression définitive** : uniquement le président, uniquement après retrait ou suspension. Première confirmation par case à cocher ; deuxième confirmation en recopiant le numéro et « SUPPRIMER DÉFINITIVEMENT ». La fiche, ses messages et ses présences sont supprimés. Le compte de connexion Auth reste sans fiche et sans droit aux membres ; le fichier photo éventuel reste dans le stockage privé et demande un nettoyage distinct par le propriétaire. Le numéro réservé et les traces administratives restent conservés. Personne ne peut retirer sa propre fiche ou celle du président.
- **Journal du bureau** : lecture seule, date/heure, numéro du responsable, membre concerné et action. Les changements de fiche, retraits, validations de présence et suppressions y sont tracés. L’attribution des rôles est réservée au président.

## Suivi après publication

1. **Fait** : pull requests #3 et #4 fusionnées, schéma hébergé vérifié, deux migrations appliquées et enregistrées. La refonte initiale n’a pas été rejouée.
2. **Fait** : RLS vérifiée sur les quatre nouvelles tables, lecture anonyme des messages refusée, contenu des messages non modifiable et journal non inscriptible par le client. Les publications liées à une fiche supprimée restent conservées.
3. **Fait** : publication sur **luxury-snickerdoodle-b2bd70**, domaine **portail.achussantohaiti.com**. Le ZIP contient uniquement les fichiers statiques ; `index.html` est une copie de `index-portail.html` pour l’accueil. Aucun secret n’est ajouté.
4. **À valider avec les vrais comptes** : connexion dans le portail et affichage des menus selon les rôles. Les échanges et suppressions ont été testés sur une base jetable ; aucun message n’a été envoyé à un vrai membre et aucune fiche réelle n’a été supprimée pendant la recette.
5. Pour les prochaines évolutions faites avec Cursor, Claude ou Grok, relire `main` et les migrations appliquées avant toute modification. La publication reste manuelle ; une modification GitHub seule ne met pas le site à jour.

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

### Nouvelles fonctions : trois comptes de test

Utilisez un président, un responsable du bureau et deux membres actifs distincts. Ne supprimez pas une vraie fiche pour essayer la fonction.

1. **Messagerie** : A envoie à B. B voit un badge ; A et B voient le texte. Le président et un responsable non destinataires ne le voient pas. B marque le message lu ; le badge disparaît. Vérifiez aussi les messages envoyés et une réponse. Le compteur s’actualise à l’ouverture d’une page, après lecture et toutes les 60 secondes lorsque l’onglet est visible.
2. **Annonce** : le bureau publie une annonce ; A la lit dans **Annonces du bureau**. A n’a pas de bouton Publier ni Supprimer.
3. **Présence** : choisissez une séance réellement passée dans l’agenda, après l’adhésion de A. A déclare sa présence, voit « En attente » et ne peut pas déclarer deux fois la même date. La semaine suivante est une autre séance.
4. **Validation** : le bureau ouvre **Valider les présences**, choisit la séance et approuve A. Pour un autre membre, refusez avec un motif. Chacun ne voit que son propre historique. Un responsable ne valide pas sa propre déclaration.
5. **Taux** : sur une période comportant deux séances et une présence approuvée, le taux est 50 %. Un membre sans séance éligible voit « — ». Comparez les deux exports CSV aux tableaux.
6. **Registre** : recherchez un nom accentué ou un numéro, combinez les filtres et changez le tri. L’export doit contenir tous les résultats filtrés, même au-delà de la page visible. Vérifiez aussi Adhésion et Validité.
7. **Retrait** : le bureau suspend A avec motif et date. A perd immédiatement l’accès aux messages, même avec un ancien jeton de session. Le motif apparaît dans **Gérer**. Réactivez A si nécessaire : son numéro reste le même.
8. **Suppression d’une fiche de test uniquement** : le bureau ne voit pas le bouton. Le président ne le voit qu’après retrait ; les deux étapes sont nécessaires. Une saisie erronée ne supprime rien. Après suppression, le journal et le numéro réservé restent présents. Une nouvelle adhésion ne reprend jamais ce numéro.
9. **Mobile et clavier** : à 390 px et à 1280 px, seuls les tableaux défilent horizontalement dans leur cadre. Les fenêtres se ferment par Fermer ou Échap, et les champs ont une étiquette en français.

## Mettre en ligne

### 1. Appliquer les migrations (après votre accord)

Fichier exact :

Refonte initiale, **si elle n’est pas déjà appliquée** : `supabase/migrations/20261104120000_portail_refonte.sql`.

Ensuite : `supabase/migrations/20261104124515_messagerie_presences_registre.sql`.

Dans Supabase : projet **hyktpddailftuwmbakdm** → **SQL Editor** → New query → collez **tout** le fichier → Run.

Chaque fichier contient déjà `BEGIN` et `COMMIT`. Ne l’entourez pas d’un autre BEGIN. Aucun script de test ne doit être collé dans l’éditeur de production.

La migration initiale conserve les fiches et rattache le président à ACHUS-001. La nouvelle migration ne supprime aucune fiche et conserve les anciens enregistrements de présence. Elle peut être réexécutée sans effacer les messages, décisions ou historiques. Ses nouvelles tables sont protégées par RLS ; les opérations sensibles vérifient le rôle en base.

N'ajoutez jamais la clé `service_role` dans le site. Elle ne doit pas quitter Supabase.

### 2. Netlify

Le portail est publié sur le site Netlify `luxury-snickerdoodle-b2bd70` (domaine portail.achussantohaiti.com) par déploiement manuel. Pour l'auto-déploiement, lier ce site au dépôt dans Netlify.

Le dépôt contient `netlify.toml`. Il n'y a **pas** de commande de build. Le dossier publié est la racine. L'adresse `/` affiche `index-portail.html`.

Si le site est déjà relié à GitHub : fusionnez la demande, Netlify publie tout seul.

Sinon : ouvrez **le site existant** → Project configuration → Build & deploy → Continuous deployment → Link repository → `moiseczil-bit/ACHUS-portail`, branche `main`. Build command : vide. Publish directory : `.`. Ne créez pas un deuxième site : le domaine reste rattaché à `luxury-snickerdoodle-b2bd70`.

Pour un déploiement manuel, publiez les fichiers statiques de cette version sur ce même site. Incluez `js/collaboration.js`, `js/app.js`, `js/documents.js`, `css/portail.css`, `index-portail.html`, `assets/` et `netlify.toml`. N’incluez pas `node_modules/`, les tests ou les fichiers de travail. Le `package.json` ne sert qu’aux tests : aucun build ni serveur Node n’est nécessaire pour le portail.

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

## Vérifications reproductibles pour la personne qui maintient le code

Le script SQL utilise un Postgres local jetable. Sans `psql`, il utilise Postgres embarqué en mémoire (PGlite). Il n’utilise aucune URL de base distante ni aucun secret.

```sh
npm ci
bash scripts/test-migration.sh
# Pour forcer le test embarqué, même si psql est installé :
ACHUS_TEST_EMBARQUE=1 bash scripts/test-migration.sh

# Vérification navigateur locale :
npx playwright install chromium
npm run test:interface
```

Les tests SQL reprennent l’instantané initial, vérifient la refonte, appliquent la nouvelle migration deux fois, exécutent les essais avec `anon` et `authenticated`, puis la réappliquent après utilisation pour vérifier la conservation. Ils couvrent l’usurpation d’expéditeur, la lecture privée, les champs immuables, les doublons de présence, les décisions, les retraits, la double confirmation, le journal et la réservation d’un numéro après suppression et recul de la séquence.

Pour les autres applications de développement : les anciennes tables `presence` et `presences` ne sont pas transformées. Les nouvelles déclarations utilisent `presences_evenements`. Les signatures `approuver_membre(uuid)`, `changer_statut(uuid,text)` et `ping()` restent disponibles. Un retrait Inactif/Suspendu doit désormais appeler `retirer_membre(uuid,text,text,date)` : un ancien appel sans motif est refusé. Pour ne pas contourner l’historique, le statut et les identifiants ne sont plus modifiables par un `UPDATE` client direct. Les signatures et les droits sont définis dans la nouvelle migration ; aucun script ne la déploie automatiquement.

Le test navigateur démarre un serveur sur `127.0.0.1` et une base jetable. Un adaptateur de test remplace le SDK distant et exécute les requêtes sous RLS : réception/lecture/envoi, déclaration/validation, export filtré de plus de 1 000 membres, retrait, refus de suppression au bureau, double confirmation présidentielle, journal, absence d’exécution HTML et absence de débordement horizontal. Il ne se connecte pas à Supabase en service. Les captures de contrôle vont dans `test-results/` (ignoré par Git).

## Correction des dépendances historiques

La vérification du projet hébergé a confirmé huit clés étrangères vers `membres`. Appliquer `20261104135930_correction_suppression_dependances.sql` après la migration de messagerie. Elle conserve les annonces, photos de groupe, votes et anciennes validations en retirant le lien vers une fiche supprimée. Aucune fiche ni publication n’est supprimée lors de l’application de cette correction. Le schéma de test inclut désormais ces huit contraintes.
