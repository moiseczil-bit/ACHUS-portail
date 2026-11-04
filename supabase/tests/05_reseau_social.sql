-- Fixtures isolées : deux parents, deux enfants ; aucune donnée réelle.
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('60000000-0000-4000-8000-000000000001','parent1@example.ht','{"prenom":"Parent","nom":"Un","type_compte":"parent"}'),
 ('60000000-0000-4000-8000-000000000002','parent2@example.ht','{"prenom":"Parent","nom":"Deux","type_compte":"parent"}'),
 ('60000000-0000-4000-8000-000000000003','enfant1@example.ht','{"prenom":"Enfant","nom":"Un"}'),
 ('60000000-0000-4000-8000-000000000004','enfant2@example.ht','{"prenom":"Enfant","nom":"Deux"}');
SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
SELECT public.approuver_membre(id) FROM public.membres WHERE user_id::text LIKE '60000000%';
UPDATE public.membres SET date_adhesion=CURRENT_DATE-90 WHERE user_id::text LIKE '60000000%';
SELECT set_config('test.parent1',(SELECT id::text FROM public.membres WHERE user_id='60000000-0000-4000-8000-000000000001'),false);
SELECT set_config('test.parent2',(SELECT id::text FROM public.membres WHERE user_id='60000000-0000-4000-8000-000000000002'),false);
SELECT set_config('test.enfant1',(SELECT id::text FROM public.membres WHERE user_id='60000000-0000-4000-8000-000000000003'),false);
SELECT set_config('test.enfant2',(SELECT id::text FROM public.membres WHERE user_id='60000000-0000-4000-8000-000000000004'),false);
SET ROLE anon;
SELECT pg_temp.refuse('SELECT * FROM public.publications');
SELECT pg_temp.refuse('SELECT * FROM public.commentaires');
SELECT pg_temp.refuse('SELECT * FROM public.liens_familiaux');
SELECT pg_temp.refuse('SELECT * FROM public.appels');
SELECT pg_temp.refuse('SELECT * FROM public.reunions');
SELECT pg_temp.refuse('SELECT public.enfants_parent()');
SELECT pg_temp.refuse('SELECT public.creer_reunion(''Interdit'',now(),now()+interval ''1 hour'',''tous'')');
RESET ROLE;
-- Bureau : liens vérifiés et réunion privée aux parents.
SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
SET ROLE authenticated;
SELECT public.gerer_lien_familial(current_setting('test.parent1')::uuid,current_setting('test.enfant1')::uuid);
SELECT public.gerer_lien_familial(current_setting('test.parent2')::uuid,current_setting('test.enfant2')::uuid);
SELECT public.gerer_lien_familial(current_setting('test.parent1')::uuid,current_setting('test.enfant1')::uuid);
SELECT set_config('test.reunion',public.creer_reunion('Parents uniquement',now(),now()+interval '1 hour','parents')::text,false);
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000003',false);
INSERT INTO public.presences_evenements(membre_id,evenement_id,date_session) VALUES(current_setting('test.enfant1')::uuid,'10000000-0000-4000-8000-000000000001',CURRENT_DATE-1);
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000004',false);
INSERT INTO public.presences_evenements(membre_id,evenement_id,date_session) VALUES(current_setting('test.enfant2')::uuid,'10000000-0000-4000-8000-000000000001',CURRENT_DATE-1);
-- Parent : propre enfant, pas l'autre, pas les données privées.
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000001',false);
SET ROLE authenticated;
DO $$ BEGIN
 ASSERT (SELECT count(*)=1 FROM public.enfants_parent());
 ASSERT (SELECT count(*)=1 FROM public.presences_enfant(current_setting('test.enfant1')::uuid,CURRENT_DATE-10,CURRENT_DATE));
 ASSERT (SELECT count(*)=1 FROM public.membres), 'Parent lit une fiche étrangère';
 ASSERT (SELECT count(*)=1 FROM public.liens_familiaux), 'Parent voit les autres familles';
 ASSERT (SELECT count(*)=1 FROM public.reunions WHERE id=current_setting('test.reunion')::uuid);
 ASSERT NOT public.contact_reseau(current_setting('test.enfant2')::uuid), 'Parent contacte un enfant arbitraire';
 ASSERT public.contact_reseau(current_setting('test.bureau')::uuid), 'Parent ne peut joindre le bureau';
END $$;
SELECT pg_temp.refuse(format('SELECT * FROM public.presences_enfant(%L,CURRENT_DATE-10,CURRENT_DATE)',current_setting('test.enfant2')));
SELECT pg_temp.refuse(format('SELECT public.gerer_lien_familial(%L,%L)',current_setting('test.parent1'),current_setting('test.enfant2')));
SELECT pg_temp.refuse(format('INSERT INTO public.liens_familiaux(parent_id,enfant_id) VALUES (%L,%L)',current_setting('test.parent1'),current_setting('test.enfant2')));
SELECT pg_temp.refuse(format('SELECT public.inviter_appel(%L,''audio'')',current_setting('test.enfant2')));
SELECT pg_temp.refuse('SELECT public.creer_reunion(''Interdit'',now(),now()+interval ''1 hour'',''tous'')');
SELECT pg_temp.refuse(format('SELECT * FROM public.presences_enfant(%L,CURRENT_DATE-400,CURRENT_DATE)',current_setting('test.enfant1')),'22023');
-- Une ancienne colonne enfant_id auto-modifiable ne donne aucun droit supplémentaire.
UPDATE public.membres SET enfant_id=current_setting('test.enfant2')::uuid WHERE id=public.current_membre_id();
DO $$ BEGIN ASSERT (SELECT count(*)=1 FROM public.enfants_parent()); END $$;
SELECT set_config('test.post',(SELECT id::text FROM public.publications LIMIT 1),false);
INSERT INTO public.publications(auteur,contenu) VALUES(public.current_membre_id(),'Bonjour <script>aucune exécution</script>');
SELECT set_config('test.post',(SELECT id::text FROM public.publications ORDER BY cree_le DESC LIMIT 1),false);
SELECT pg_temp.refuse(format('INSERT INTO public.publications(auteur,contenu) VALUES (%L,''Usurpation'')',current_setting('test.enfant2')));
SELECT pg_temp.refuse('UPDATE public.publications SET masque=true');
SELECT pg_temp.refuse('INSERT INTO public.publications(auteur,contenu,cree_le) VALUES (public.current_membre_id(),''Antidaté'',now())');
RESET ROLE;
-- Enfant : fil visible, commentaires, aucune réunion parents ni accès familial.
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000003',false);
SET ROLE authenticated;
DO $$ BEGIN
 ASSERT (SELECT count(*)=0 FROM public.enfants_parent());
 ASSERT (SELECT count(*)=0 FROM public.reunions WHERE id=current_setting('test.reunion')::uuid);
 ASSERT (SELECT count(*)=1 FROM public.publications WHERE id=current_setting('test.post')::uuid);
 ASSERT (SELECT count(*)=1 FROM public.noms_contributions(ARRAY[current_setting('test.parent1')::uuid]));
END $$;
INSERT INTO public.commentaires(publication,auteur,contenu) VALUES(current_setting('test.post')::uuid,public.current_membre_id(),'Réponse');
SELECT pg_temp.refuse(format('SELECT public.masquer_contribution(%L)',current_setting('test.post')));
-- Appels privés : seul le destinataire peut accepter, un tiers ne voit pas la salle.
SELECT set_config('test.appel',public.inviter_appel(current_setting('test.enfant2')::uuid,'audio')::text,false);
SELECT pg_temp.refuse(format('SELECT public.repondre_appel(%L,''accepte'')',current_setting('test.appel')),'22023');
SELECT pg_temp.refuse(format('SELECT public.inviter_appel(%L,''video'')',current_setting('test.enfant2')),'22023');
SELECT pg_temp.refuse('UPDATE public.appels SET statut=''accepte''');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000001',false);
SET ROLE authenticated;
DO $$ BEGIN ASSERT (SELECT count(*)=0 FROM public.appels); END $$;
SELECT pg_temp.refuse(format('SELECT public.repondre_appel(%L,''termine'')',current_setting('test.appel')));
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000004',false);
SET ROLE authenticated;
SELECT public.repondre_appel(current_setting('test.appel')::uuid,'accepte');
SELECT pg_temp.refuse(format('SELECT public.repondre_appel(%L,''refuse'')',current_setting('test.appel')),'22023');
SELECT public.repondre_appel(current_setting('test.appel')::uuid,'termine');
RESET ROLE;
-- Vidéo, refus, annulation et expiration : pas de retour vers un état actif.
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000003',false);
SET ROLE authenticated;
SELECT set_config('test.appel_video',public.inviter_appel(current_setting('test.enfant2')::uuid,'video')::text,false);
SELECT public.repondre_appel(current_setting('test.appel_video')::uuid,'annule');
SELECT pg_temp.refuse(format('SELECT public.repondre_appel(%L,''accepte'')',current_setting('test.appel_video')),'22023');
SELECT set_config('test.appel_refus',public.inviter_appel(current_setting('test.enfant2')::uuid,'video')::text,false);
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000004',false);
SET ROLE authenticated;
SELECT public.repondre_appel(current_setting('test.appel_refus')::uuid,'refuse');
SELECT set_config('test.appel_expire',public.inviter_appel(current_setting('test.enfant1')::uuid,'audio')::text,false);
RESET ROLE;
UPDATE public.appels SET expire_le=now()-interval '1 second' WHERE id=current_setting('test.appel_expire')::uuid;
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000003',false);
SET ROLE authenticated;
SELECT pg_temp.refuse(format('SELECT public.repondre_appel(%L,''accepte'')',current_setting('test.appel_expire')),'22023');
RESET ROLE;
-- Modération et révocation immédiate du lien.
SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
SET ROLE authenticated;
SELECT public.masquer_contribution(current_setting('test.post')::uuid);
SELECT public.gerer_lien_familial(current_setting('test.parent1')::uuid,current_setting('test.enfant1')::uuid,true);
SELECT public.annuler_reunion(current_setting('test.reunion')::uuid);
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000001',false);
SET ROLE authenticated;
DO $$ BEGIN
 ASSERT (SELECT count(*)=0 FROM public.enfants_parent());
 ASSERT (SELECT count(*)=0 FROM public.publications WHERE id=current_setting('test.post')::uuid);
 ASSERT (SELECT count(*)=0 FROM public.commentaires WHERE publication=current_setting('test.post')::uuid);
END $$;
SELECT pg_temp.refuse(format('SELECT * FROM public.presences_enfant(%L,CURRENT_DATE-10,CURRENT_DATE)',current_setting('test.enfant1')));
RESET ROLE;
-- Suspension : le JWT reste identique mais l'accès communautaire cesse.
UPDATE public.membres SET statut='suspendu' WHERE id=current_setting('test.parent1')::uuid;
SET ROLE authenticated;
DO $$ BEGIN ASSERT (SELECT count(*)=0 FROM public.publications); ASSERT (SELECT count(*)=0 FROM public.reunions); END $$;
SELECT pg_temp.refuse('INSERT INTO public.publications(auteur,contenu) VALUES(public.current_membre_id(),''Interdit'')');
RESET ROLE;
DO $$ BEGIN
 ASSERT (SELECT count(*)=5 FROM pg_class WHERE relname IN ('publications','commentaires','liens_familiaux','appels','reunions') AND relrowsecurity);
 ASSERT EXISTS(SELECT 1 FROM public.journal_admin WHERE action='retirer_lien_familial');
END $$;

-- Les nouvelles clés étrangères n'empêchent pas une suppression présidentielle autorisée.
SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
SET ROLE authenticated;
SELECT public.retirer_membre(current_setting('test.enfant2')::uuid,'inactif','Fin de la fiche de test',CURRENT_DATE);
SELECT public.supprimer_membre(current_setting('test.enfant2')::uuid,(SELECT numero_membre FROM public.membres WHERE id=current_setting('test.enfant2')::uuid),'SUPPRIMER DÉFINITIVEMENT');
RESET ROLE;
DO $$ BEGIN
 ASSERT NOT EXISTS(SELECT 1 FROM public.membres WHERE id=current_setting('test.enfant2')::uuid);
 ASSERT NOT EXISTS(SELECT 1 FROM public.liens_familiaux WHERE enfant_id=current_setting('test.enfant2')::uuid);
 ASSERT NOT EXISTS(SELECT 1 FROM public.appels WHERE destinataire=current_setting('test.enfant2')::uuid OR expediteur=current_setting('test.enfant2')::uuid);
END $$;
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000003',false);
SET ROLE authenticated;
SELECT public.inviter_appel(current_setting('test.bureau')::uuid,'audio');
RESET ROLE;
