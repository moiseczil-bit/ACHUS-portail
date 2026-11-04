-- Le stockage de profil est séparé des photos des documents.
INSERT INTO storage.objects(bucket_id,name,owner) VALUES
 ('photos-profils',current_setting('test.enfant1')||'/avatar.webp','60000000-0000-4000-8000-000000000003'),
 ('photos-membres','60000000-0000-4000-8000-000000000003/carte.jpg','60000000-0000-4000-8000-000000000003');
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000002',false);
SET ROLE anon;
DO $$ BEGIN ASSERT (SELECT count(*)=0 FROM storage.objects WHERE bucket_id='photos-profils'); END $$;
SELECT pg_temp.refuse('SELECT public.profils_contributions(ARRAY[]::uuid[])');
RESET ROLE;
SET ROLE authenticated;
-- Un parent actif, dans la communauté, voit la photo de profil mais pas celle de carte.
DO $$ BEGIN
 ASSERT (SELECT count(*)=1 FROM storage.objects WHERE bucket_id='photos-profils');
 ASSERT (SELECT count(*)=0 FROM storage.objects WHERE bucket_id='photos-membres');
END $$;
SELECT pg_temp.refuse(format('INSERT INTO storage.objects(bucket_id,name) VALUES (''photos-profils'',%L)',current_setting('test.enfant1')||'/autre.webp'));
SELECT pg_temp.refuse(format('INSERT INTO storage.objects(bucket_id,name) VALUES (''photos-profils'',%L)',current_setting('test.enfant1')||'/avatar.webp'));
DO $$ DECLARE compte int; BEGIN
 UPDATE storage.objects SET name=public.current_membre_id()::text||'/avatar.webp' WHERE bucket_id='photos-profils';
 GET DIAGNOSTICS compte=ROW_COUNT; ASSERT compte=0,'Photo étrangère modifiable';
 DELETE FROM storage.objects WHERE bucket_id='photos-profils'; GET DIAGNOSTICS compte=ROW_COUNT; ASSERT compte=0,'Photo étrangère supprimable';
END $$;
INSERT INTO storage.objects(bucket_id,name) VALUES('photos-profils',public.current_membre_id()::text||'/avatar.webp');
SELECT pg_temp.refuse('UPDATE storage.objects SET name=''autre/avatar.webp'' WHERE name=public.current_membre_id()::text||''/avatar.webp''');
DELETE FROM storage.objects WHERE bucket_id='photos-profils' AND name=public.current_membre_id()::text||'/avatar.webp';
RESET ROLE;
-- Un auteur visible fournit nom et indicateur de photo, sans autre champ de profil.
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000003',false);
SET ROLE authenticated;
INSERT INTO public.publications(auteur,contenu) VALUES(public.current_membre_id(),'Publication avec photo de profil');
DO $$ BEGIN
 ASSERT (SELECT photo_profil FROM public.profils_contributions(ARRAY[public.current_membre_id()]));
 ASSERT (SELECT count(*)=1 FROM public.membres),'Fiche étrangère exposée';
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000001',false);
SET ROLE authenticated;
DO $$ BEGIN ASSERT (SELECT count(*)=0 FROM storage.objects WHERE bucket_id='photos-profils'); END $$;
SELECT pg_temp.refuse('INSERT INTO storage.objects(bucket_id,name) VALUES(''photos-profils'',public.current_membre_id()::text||''/avatar.webp'')');
DO $$ BEGIN ASSERT (SELECT count(*)=0 FROM public.profils_contributions(ARRAY[current_setting('test.enfant1')::uuid])); END $$;
RESET ROLE;
DO $$ BEGIN
 ASSERT (SELECT NOT public AND file_size_limit=524288 AND allowed_mime_types=ARRAY['image/webp'] FROM storage.buckets WHERE id='photos-profils');
 ASSERT (SELECT count(*)=1 FROM storage.objects WHERE bucket_id='photos-profils');
END $$;

-- Même une politique ancienne trop large ne donne pas accès à ce nouveau bucket.
CREATE POLICY test_stockage_trop_large ON storage.objects FOR ALL TO authenticated USING(true) WITH CHECK(true);
CREATE POLICY test_stockage_public ON storage.objects FOR SELECT TO anon USING(true);
SET ROLE anon;
DO $$ BEGIN ASSERT (SELECT count(*)=0 FROM storage.objects WHERE bucket_id='photos-profils'); END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000002',false);
SET ROLE authenticated;
DO $$ DECLARE compte int; BEGIN
 UPDATE storage.objects SET name='pirate/avatar.webp' WHERE bucket_id='photos-profils'; GET DIAGNOSTICS compte=ROW_COUNT; ASSERT compte=0;
 DELETE FROM storage.objects WHERE bucket_id='photos-profils'; GET DIAGNOSTICS compte=ROW_COUNT; ASSERT compte=0;
END $$;
RESET ROLE;
DROP POLICY test_stockage_trop_large ON storage.objects;
DROP POLICY test_stockage_public ON storage.objects;
