# Encodeur WebP de secours

Source : `@jsquash/webp@1.5.0`, paquet officiel npm (`https://registry.npmjs.org/@jsquash/webp/-/webp-1.5.0.tgz`).

Fichiers originaux non modifiés, variante sans SIMD pour les téléphones. Licence Apache-2.0 conservée dans `LICENSE`. Seuls le moteur et ses options sont importés par `js/encoder-photo.js` ; aucun build ni CDN nécessaire. Le WASM est chargé seulement si le navigateur ne produit pas de WebP natif.

SHA-256 :

- `LICENSE` : `8c3690b09c168f196446cf5904332023bbc15eb92b6a7cee470ac829e6a65d20`
- `meta.js` : `3d70163a00e6264fc5a8fa7c8f3b1fa21a50a00d910f4d2de3ef1bbd2fdc98ab`
- `webp_enc.js` : `5fd62301662e37785aec38e38807926f72933d4c8b919018a43faf1b1ca760f6`
- `webp_enc.wasm` : `b6085bb6702f144e9dc6016d58d230b34a84976bf0d080b7390b4b4b137d6ab7`
