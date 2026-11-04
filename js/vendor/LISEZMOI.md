# Client Supabase local

Version conservée : `@supabase/supabase-js@2.49.4` (identique à la version précédemment importée depuis le CDN).

Source officielle distribuée sur npm :
`https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.49.4/dist/umd/supabase.js`

SHA-256 du fichier original :
`fda9d67f80cce4074f78d6373bb136e84c34cb235b8a91c5e4284068da6ddc42`

Licence MIT conservée dans `SUPABASE-LICENSE.txt`. Le fichier n’est pas modifié ni reconstruit. La version UMD expose `window.supabase` ; le portail l’importe une seule fois depuis son propre domaine avant de créer le client. Aucun build Netlify n’est nécessaire.

Ce fichier doit être inclus dans chaque déploiement statique, avec son dossier `js/vendor/`. Il ne contient aucune configuration ACHUS ni aucun secret.
