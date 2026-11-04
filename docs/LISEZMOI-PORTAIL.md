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

## Évolution gratuite : communauté, appels, réunions et parents

**Mise en service du 4 novembre 2026 à 13 h 21 (Toronto)** : PR nº 6 fusionnée, migration `20261104143144_reseau_social_gratuit.sql` appliquée et enregistrée sur ACHUS. Les **10 fiches et 9 comptes** présents avant cette évolution sont conservés. Les cinq nouvelles tables ont RLS activée ; les appels ne sont pas lisibles anonymement, les liens familiaux ne sont pas inscriptibles directement et les états d’appel ne sont pas modifiables directement par le client. Version publiée : `9add8a6b5b1b89ef0448a949406aab075bddcf23`, déploiement Netlify `6aeb77ab5efb4ed2b39751e5`. Le HTML et les fichiers JS/CSS servis sur le domaine ont été comparés au dépôt. La recette avec de vrais participants audio/vidéo reste à faire.

**Publiée sur le site existant après accord du propriétaire.** Ne rejouez pas les anciennes migrations. La nouvelle est `supabase/migrations/20261104143144_reseau_social_gratuit.sql`, à appliquer uniquement après accord du propriétaire, après les trois migrations existantes. Publier ensuite les fichiers statiques, avec le nouveau fichier **`js/communaute.js`**, sur le même site Netlify. Avant la migration, les nouveaux écrans indiquent qu’une mise à jour est nécessaire ; les écrans existants restent disponibles.

### Fait dans cette évolution

- **Communauté** : publications textuelles de 4 000 caractères maximum, commentaires de 1 000 caractères, pagination. Membres actifs et honoraires, parents actifs inclus. Chaque auteur peut retirer sa contribution ; le bureau peut modérer toutes les contributions. Une publication retirée et ses commentaires ne sont plus visibles aux membres. Le bureau conserve la visibilité pour modération ; aucune restauration n’est proposée. Les noms d’auteurs sont fournis sans ouvrir les fiches personnelles. Les textes sont affichés comme du texte, jamais comme du HTML.
- **Appels audio et vidéo** : invitation privée, acceptation/refus par le destinataire, annulation par l’expéditeur et fin manuelle par un participant. Le bouton Jitsi apparaît après acceptation ; le mode audio propose de démarrer caméra coupée. Une invitation expire après 5 minutes. Un appel accepté bloque les nouvelles invitations pendant 12 heures maximum s’il n’a pas été terminé. Le badge des appels entrants s’actualise à la navigation et toutes les 60 secondes quand l’onglet est visible. Actualiser l’écran affiche la réponse. Les 50 appels les plus récents sont affichés.
- **Réunions en ligne** : le bureau programme titre, début, fin et public (membres, parents ou tous). Les dates saisies utilisent l’heure de l’appareil ; l’affichage utilise l’heure d’Haïti. Le bureau peut annuler une réunion. Les 100 prochaines réunions sont affichées ; ce chiffre ne représente pas une capacité vidéo garantie. Les réunions vidéo sont indépendantes des événements de l’agenda : pour suivre les présences, créer aussi l’événement correspondant dans l’agenda.
- **Espace parents** : le bureau vérifie l’identité et l’autorisation du parent, puis rattache un compte de type Parent et au statut Actif à un ou plusieurs enfants. Le parent ne choisit pas lui-même ses enfants. Il consulte uniquement les noms/numéros de ses enfants liés et leurs déclarations de présence sur une période de 366 jours maximum. Aucun accès aux messages, aux motifs de refus ou de retrait, ni aux profils complets. Le retrait du lien ou la désactivation du parent coupe immédiatement cet accès en base. L’ancienne colonne `membres.enfant_id` ne donne aucun droit.
- **Contacter les responsables** : les parents actifs peuvent écrire et inviter à un appel les responsables actifs ; les membres ordinaires ne peuvent pas contacter un parent arbitraire. Les conversations déjà existantes restent lisibles par leurs seuls participants actifs.
- **Sécurité** : cinq nouvelles tables protégées par RLS et droits de colonnes ; aucune écriture client directe des liens familiaux, états d’appel, salles, réunions ou décisions de modération. Les actions sensibles vérifient le rôle courant en base et utilisent les fonctions prévues. Les ajouts/retraits de liens, modérations et réunions sont tracés dans le journal du bureau. Aucune clé secrète ni nouveau service payant.

### Gratuit : limites à comprendre

La vidéo s’ouvre sur **https://meet.jit.si/** dans un nouvel onglet, sans intégration iframe. C’est le service public gratuit de Jitsi, distinct de Supabase et Netlify. Le premier participant doit s’authentifier chez Jitsi (Google, Facebook ou GitHub), ou attendre un modérateur. Le portail n’ouvre aucun compte payant et n’enregistre pas de carte bancaire.

**100 personnes est un objectif d’usage, pas une capacité garantie.** La disponibilité, la capacité, la qualité et les conditions du service externe peuvent évoluer. Tester avec le groupe avant une réunion importante ; privilégier l’audio et limiter les caméras si les connexions sont faibles. Aucun essai de charge de 100 participants ni de conversation audio/vidéo réelle n’est simulé par nos tests automatisés.

Les salles ont un identifiant aléatoire sans nom ni e-mail dans l’URL. Toutefois, une personne peut transférer le lien Jitsi. L’organisateur doit y activer une salle d’attente ou un mot de passe et contrôler les participants. Retirer un membre du portail, annuler la réunion ou terminer l’appel dans le portail **ne ferme pas une salle déjà ouverte chez Jitsi et ne révoque pas un lien déjà copié** ; le modérateur gère la salle externe. Ne pas qualifier ces salles de réservées techniquement aux seuls comptes ACHUS.

Les invitations ne sont reçues que lorsque le portail est ouvert : pas de notification push, de sonnerie quand le téléphone est verrouillé ni d’appel téléphonique vers un numéro. Le statut d’appel ne prouve pas une connexion audio réelle et ne mesure pas sa durée. Aucune présence n’est approuvée automatiquement quand quelqu’un clique sur Rejoindre. Aucun enregistrement audio/vidéo n’est ajouté. Les offres gratuites Supabase/Netlify gardent leurs limites habituelles de stockage et de trafic.

### Reste à faire et recette avant publication

1. **Fait** : accord obtenu, PR nº 6 fusionnée et nouvelle migration appliquée manuellement. Les anciennes migrations n’ont pas été rejouées.
2. Avec un parent A, un parent B, deux enfants et un responsable : lier chaque parent à son enfant. Vérifier qu’A ne voit jamais les présences de l’enfant de B. Retirer le lien puis actualiser : l’accès doit disparaître. Un compte simplement déclaré Parent à l’inscription reste sans enfant tant que le bureau n’a pas vérifié le lien.
3. Publier un texte, commenter, retirer sa contribution ; modérer une autre contribution avec le bureau. Vérifier au clavier et à 390 px, puis à 1280 px. Vérifier qu’un texte contenant `<script>` reste visible sans exécution.
4. A invite B en audio, B accepte ; chacun ouvre la même salle Jitsi. Autoriser le microphone puis essayer la vidéo. Tester refus, annulation, expiration et fin manuelle. Un troisième membre, même du bureau, ne voit pas leur invitation. Essayer aussi un appel parent → bureau et vérifier qu’un parent ne peut pas inviter un enfant arbitraire.
5. Programmer une réunion pour les parents seulement : un membre ordinaire ne doit pas la voir. Tester une réunion pour tous, puis son annulation. Tester le démarrage Jitsi, la salle d’attente/le mot de passe et un petit groupe sur téléphones avant un essai de 100 participants.
6. **Publication faite** : nouvelle migration et fichiers statiques publiés sur le site existant. **À valider** : les menus et les échanges avec de vrais comptes ; aucune fiche réelle ne doit être supprimée pour la recette.

Les commandes `bash scripts/test-migration.sh` et `npm run test:interface` couvrent les anciennes fonctions et les nouvelles. Les essais SQL appliquent trois fois la migration sociale (deux fois avant utilisation, une fois après), contrôlent RLS, usurpation, droits parents, messages, appels, modération et conservation. Le navigateur utilise un adaptateur local exécutant les requêtes sous RLS ; il ne contacte ni Supabase en service ni Jitsi. Les captures vont dans `test-results/`, ignoré par Git.

Sources techniques à revérifier avant une grande réunion : [FAQ Jitsi](https://jitsi.org/user-faq/) et [Démarrer une réunion](https://jitsi.github.io/handbook/docs/user-guide/user-guide-start-a-jitsi-meeting/).

## Correction publiée : mot de passe visible et grade personnel

**Mise en service du 4 novembre 2026 à 14 h 02 (Toronto)** : PR nº 8 fusionnée, migrations `grade_personnel` et `photos_profil_communaute` appliquées et enregistrées. Les **10 fiches et 9 comptes** sont conservés. Le stockage des photos est privé, cinq politiques restrictives sont présentes, et les fonctions ne sont pas exécutables anonymement. Version publiée : `3ef5781556553a668f77dbfe68594ee90c2d92bf`, déploiement Netlify `6aeb812c514951fb17fa0005`. Le HTML, le CSS et les modules JS servis sur le domaine ont été comparés au dépôt. L’écran public affiche maintenant la commande de visibilité du mot de passe. Les essais de photos et de grade ont été effectués sur une base jetable ; la recette avec les vrais comptes reste à faire.

- **Connexion et adhésion** : bouton « Afficher le mot de passe » / « Masquer le mot de passe », utilisable au clavier. Le mot de passe reste masqué à l’ouverture ; le bouton ne change pas sa valeur et ne l’enregistre pas ailleurs.
- **Mon profil → Mon grade** : un membre actif ou honoraire peut saisir son grade ACHUS en toutes lettres (80 caractères maximum) puis cliquer sur **Enregistrer mon grade**. La carte affichée et ses téléchargements, ainsi que le certificat, utilisent immédiatement le grade enregistré. Un rechargement garde le choix. Le bureau peut toujours corriger un grade depuis le registre.
- Les comptes parents ne disposent pas de ce champ. Le grade est distinct du rôle : saisir un grade ne donne aucun droit de président ou de bureau. Les rôles, statuts, numéros et autres champs protégés gardent leurs protections. L’action ne peut cibler que la propre fiche de la personne connectée et reste tracée par le journal existant.
- Le grade initial déjà présent n’est pas effacé : le membre peut le remplacer. Aucun grade existant n’est remplacé automatiquement pendant cette migration.

**Fait après accord du propriétaire** : migration `supabase/migrations/20261104183055_grade_personnel.sql` appliquée puis HTML, JS et CSS publiés sur le même site Netlify. Les anciennes migrations n’ont pas été rejouées.

**Recette** : essayer Afficher puis Masquer à la connexion et à l’adhésion ; vérifier la conservation des caractères saisis. Avec un membre actif, remplacer le grade initial par « Sergent-chef », enregistrer, contrôler le recto de la carte, le certificat et les téléchargements, puis recharger. Vérifier qu’un parent ou un compte suspendu ne peut pas utiliser l’action et que le rôle/numéro/statut ne changent pas. Les tests SQL vérifient aussi les saisies vides, trop longues, numériques seules ou contenant un retour à la ligne, et la conservation après réapplication de la migration. Le test navigateur local vérifie le grade sur la carte et après rechargement.

## Mur et photo de profil — mise en service

**Publié le 4 novembre 2026 sur le site existant.** La PR nº 8 comprend un accueil avec fil central et rappels à côté, une bannière ACHUS, une identité avec photo ronde, un espace pour publier, les photos et noms des auteurs, les commentaires et les onglets **Toute la communauté** / **Mon mur**. Sur téléphone, le fil et les rappels se placent les uns sous les autres. Le mur reste réservé à la communauté active ou honoraire ; aucun profil complet, téléphone ou courriel d’un auteur n’est ajouté au fil.

Dans **Mon profil → Ma photo de profil**, choisir un JPG, PNG ou WebP (5 Mo maximum), puis **Enregistrer ma photo de profil**. L’image est recadrée au centre en carré, redimensionnée à 512 × 512 et réencodée en WebP dans le navigateur, sans les métadonnées de l’original. Sans photo, les initiales sont affichées. **Retirer ma photo de profil** permet de revenir aux initiales. La photo est celle de la communauté, distincte de la photo de carte : les photos privées déjà envoyées pour les documents ne deviennent pas visibles sur le mur.

Nouvelle migration associée : `supabase/migrations/20261104184248_photos_profil_communaute.sql`, appliquée **après** `20261104183055_grade_personnel.sql`, avec l’accord du propriétaire. Elle crée le bucket privé `photos-profils`, limité à une photo `identifiant-membre/avatar.webp`, 512 Ko et au type WebP. Aucun bucket existant n’est rendu public. Les comptes actifs/honoraires peuvent lire les photos de profil des comptes actifs/honoraires ; seul le titulaire peut ajouter, remplacer ou retirer sa photo. La RLS empêche de déplacer la photo vers un autre chemin. Le bucket des cartes et ses politiques restent inchangés.

Les URL des images sont signées pour 15 minutes, avec cache applicatif de 2 minutes. Une URL déjà obtenue peut rester utilisable jusqu’à expiration après retrait ou suspension ; un rafraîchissement ou l’expiration renouvelle la vérification d’accès. Après suppression définitive d’une fiche, son éventuel fichier de profil demande un nettoyage distinct dans Storage par le propriétaire, comme les photos de carte ; la règle de lecture refuse les nouveaux accès à une photo sans fiche active. Il n’y a pas de publication de photos/vidéos dans les messages du mur dans cette version : seule la photo de profil est ajoutée.

**Recette complémentaire** : ajouter puis remplacer une photo dans Mon profil, revenir à Accueil et Communauté, publier et commenter, vérifier la photo sur un second compte actif. Vérifier Mon mur et Toute la communauté, l’absence de photo après retrait, les initiales, le mobile à 390 px et le bureau à 1280 px. Un visiteur ou un compte suspendu ne doit pas lire les photos ; un autre membre ne doit pas modifier ou supprimer la photo du titulaire. Vérifier que les photos de carte ne sont pas lisibles par les autres membres. Les tests automatisés utilisent un stockage local avec RLS et une image factice, sans envoyer de photo réelle ni modifier la production.

Pour publier l’ensemble de cette correction, inclure aussi **`js/photos-profil.js`** et la version mise à jour de **`js/communaute.js`**, en plus du HTML, de `js/app.js`, de `js/documents.js`, de `js/collaboration.js`, du CSS et des assets. Les deux migrations sont déjà appliquées en production ; elles ne sont pas exécutées automatiquement par un déploiement Netlify.
