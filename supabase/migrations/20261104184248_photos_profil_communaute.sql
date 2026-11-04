-- Photos de profil explicitement partagées avec la communauté, distinctes des cartes.
BEGIN;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES('photos-profils','photos-profils',false,524288,ARRAY['image/webp'])
ON CONFLICT(id) DO UPDATE SET public=false,file_size_limit=524288,allowed_mime_types=ARRAY['image/webp'];
-- Ne pas désactiver ni remplacer les politiques existantes du bucket des cartes.
CREATE OR REPLACE FUNCTION public.photo_profil_visible(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.is_membre_actif() AND EXISTS(SELECT 1 FROM public.membres m
 WHERE m.statut IN ('actif','honoraire') AND p_nom=m.id::text||'/avatar.webp');
$$;
REVOKE ALL ON FUNCTION public.photo_profil_visible(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.photo_profil_visible(text) TO authenticated;
DO $$ BEGIN
 IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='storage.objects'::regclass) THEN
  RAISE EXCEPTION 'La RLS du stockage doit être activée avant cette migration.';
 END IF;
END $$;
DROP POLICY IF EXISTS photos_profils_lecture ON storage.objects;
CREATE POLICY photos_profils_lecture ON storage.objects FOR SELECT TO authenticated
 USING(bucket_id='photos-profils' AND public.photo_profil_visible(name));
DROP POLICY IF EXISTS photos_profils_ajout ON storage.objects;
CREATE POLICY photos_profils_ajout ON storage.objects FOR INSERT TO authenticated
 WITH CHECK(bucket_id='photos-profils' AND (SELECT public.is_membre_actif()) AND name=(SELECT public.current_membre_id())::text||'/avatar.webp');
DROP POLICY IF EXISTS photos_profils_modification ON storage.objects;
CREATE POLICY photos_profils_modification ON storage.objects FOR UPDATE TO authenticated
 USING(bucket_id='photos-profils' AND (SELECT public.is_membre_actif()) AND name=(SELECT public.current_membre_id())::text||'/avatar.webp')
 WITH CHECK(bucket_id='photos-profils' AND (SELECT public.is_membre_actif()) AND name=(SELECT public.current_membre_id())::text||'/avatar.webp');
DROP POLICY IF EXISTS photos_profils_retrait ON storage.objects;
CREATE POLICY photos_profils_retrait ON storage.objects FOR DELETE TO authenticated
 USING(bucket_id='photos-profils' AND (SELECT public.is_membre_actif()) AND name=(SELECT public.current_membre_id())::text||'/avatar.webp');
-- Une politique permissive ancienne créée par une autre application ne doit pas
-- ouvrir ce nouveau bucket : ces restrictions ne concernent que photos-profils.
DROP POLICY IF EXISTS photos_profils_visiteur_refus ON storage.objects;
CREATE POLICY photos_profils_visiteur_refus ON storage.objects AS RESTRICTIVE FOR ALL TO anon
 USING(bucket_id IS DISTINCT FROM 'photos-profils') WITH CHECK(bucket_id IS DISTINCT FROM 'photos-profils');
DROP POLICY IF EXISTS photos_profils_lecture_limitee ON storage.objects;
CREATE POLICY photos_profils_lecture_limitee ON storage.objects AS RESTRICTIVE FOR SELECT TO authenticated
 USING(bucket_id IS DISTINCT FROM 'photos-profils' OR public.photo_profil_visible(name));
DROP POLICY IF EXISTS photos_profils_ajout_limite ON storage.objects;
CREATE POLICY photos_profils_ajout_limite ON storage.objects AS RESTRICTIVE FOR INSERT TO authenticated
 WITH CHECK(bucket_id IS DISTINCT FROM 'photos-profils' OR ((SELECT public.is_membre_actif()) AND name=(SELECT public.current_membre_id())::text||'/avatar.webp'));
DROP POLICY IF EXISTS photos_profils_modification_limitee ON storage.objects;
CREATE POLICY photos_profils_modification_limitee ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated
 USING(bucket_id IS DISTINCT FROM 'photos-profils' OR ((SELECT public.is_membre_actif()) AND name=(SELECT public.current_membre_id())::text||'/avatar.webp'))
 WITH CHECK(bucket_id IS DISTINCT FROM 'photos-profils' OR ((SELECT public.is_membre_actif()) AND name=(SELECT public.current_membre_id())::text||'/avatar.webp'));
DROP POLICY IF EXISTS photos_profils_retrait_limite ON storage.objects;
CREATE POLICY photos_profils_retrait_limite ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated
 USING(bucket_id IS DISTINCT FROM 'photos-profils' OR ((SELECT public.is_membre_actif()) AND name=(SELECT public.current_membre_id())::text||'/avatar.webp'));
CREATE OR REPLACE FUNCTION public.profils_contributions(p_ids uuid[])
RETURNS TABLE(id uuid,prenom text,nom text,photo_profil boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT m.id,m.prenom,m.nom,
  EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id='photos-profils' AND o.name=m.id::text||'/avatar.webp')
 FROM public.membres m WHERE public.is_membre_actif() AND m.id=ANY(p_ids) AND cardinality(p_ids)<=100
 AND (EXISTS(SELECT 1 FROM public.publications p WHERE p.auteur=m.id AND (NOT p.masque OR public.is_bureau()))
 OR EXISTS(SELECT 1 FROM public.commentaires c JOIN public.publications p ON p.id=c.publication
 WHERE c.auteur=m.id AND ((NOT c.masque AND NOT p.masque) OR public.is_bureau())));
$$;
REVOKE ALL ON FUNCTION public.profils_contributions(uuid[]) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.profils_contributions(uuid[]) TO authenticated;
COMMIT;
