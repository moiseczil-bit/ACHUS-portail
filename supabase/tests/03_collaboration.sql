-- Tests fonctionnels et tentatives d'accès direct avec les vrais rôles Postgres.
-- Aucune donnée de production ; les UUID/e-mails sont ceux des fixtures.
CREATE OR REPLACE FUNCTION pg_temp.refuse(requete text, code text DEFAULT '42501')
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE requete;
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = code OR (code = '23503' AND SQLSTATE = '23001') THEN RETURN; END IF;
    RAISE EXCEPTION 'Mauvaise erreur : % / % pour %', SQLSTATE, SQLERRM, requete;
  END;
  RAISE EXCEPTION 'FAIL : opération acceptée : %', requete;
END $$;

SELECT set_config('test.paul', (SELECT id::text FROM public.membres WHERE user_id = '99999999-9999-4999-8999-999999999999'), false);
SELECT set_config('test.anne', (SELECT id::text FROM public.membres WHERE user_id = '88888888-8888-4888-8888-888888888888'), false);
SELECT set_config('test.bureau', (SELECT id::text FROM public.membres WHERE user_id = '22222222-2222-4222-8222-222222222222'), false);
SELECT set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', false);
SELECT public.approuver_membre(current_setting('test.bureau')::uuid);
UPDATE public.membres SET role = 'bureau' WHERE id = current_setting('test.bureau')::uuid;
UPDATE public.membres SET date_adhesion = CURRENT_DATE - 60 WHERE numero_membre IS NOT NULL;
INSERT INTO public.evenements(id,titre,date_debut,recurrence) VALUES
('10000000-0000-4000-8000-000000000001','Réunion de test', ((now() AT TIME ZONE 'America/Port-au-Prince')::date - 1 + TIME '09:00') AT TIME ZONE 'America/Port-au-Prince', NULL),
('10000000-0000-4000-8000-000000000002','Samedis de test', ((now() AT TIME ZONE 'America/Port-au-Prince')::date - 28 + TIME '09:00') AT TIME ZONE 'America/Port-au-Prince','hebdomadaire:samedi:09:00');

-- Visiteur : tables, annuaire et fonctions privilégiées inaccessibles.
SET ROLE anon;
SELECT pg_temp.refuse('SELECT * FROM public.messages');
SELECT pg_temp.refuse('SELECT * FROM public.presences_evenements');
SELECT pg_temp.refuse('SELECT * FROM public.historique_statuts');
SELECT pg_temp.refuse('SELECT * FROM public.journal_admin');
SELECT pg_temp.refuse('SELECT * FROM public.contacts_messagerie()');
SELECT pg_temp.refuse('SELECT * FROM app_private.numeros_reserves');
RESET ROLE;

-- En attente : aucune messagerie, aucune déclaration.
SELECT set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',false);
SET ROLE authenticated;
DO $$ BEGIN
  ASSERT (SELECT count(*) = 0 FROM public.contacts_messagerie()), 'Annuaire visible avant activation';
  ASSERT (SELECT count(*) = 0 FROM public.messages), 'Messages visibles avant activation';
  ASSERT (SELECT count(*) = 0 FROM public.journal_admin), 'Journal visible au membre';
END $$;
SELECT pg_temp.refuse(format('INSERT INTO public.messages(expediteur,destinataire,contenu) VALUES (%L,%L,%L)',
  public.current_membre_id(),current_setting('test.paul'),'Interdit'));
SELECT pg_temp.refuse(format('SELECT public.retirer_membre(%L,%L,%L,CURRENT_DATE)',current_setting('test.paul'),'inactif','Interdit'));
RESET ROLE;

-- Paul envoie deux messages. L'horodatage et le lu sont imposés par la base.
SELECT set_config('request.jwt.claim.sub','99999999-9999-4999-8999-999999999999',false);
SET ROLE authenticated;
INSERT INTO public.messages(expediteur,destinataire,contenu) VALUES
(public.current_membre_id(),current_setting('test.anne')::uuid,'Bonjour Anne'),
(public.current_membre_id(),'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Bonjour Président');
SELECT pg_temp.refuse(format('INSERT INTO public.messages(expediteur,destinataire,contenu) VALUES (%L,%L,%L)',
  current_setting('test.anne'),'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Usurpation'));
SELECT pg_temp.refuse(format('INSERT INTO public.messages(expediteur,destinataire,contenu,lu) VALUES (%L,%L,%L,true)',
  public.current_membre_id(),current_setting('test.anne'),'Déjà lu'));
SELECT pg_temp.refuse(format('INSERT INTO public.messages(expediteur,destinataire,contenu,date_envoi) VALUES (%L,%L,%L,now())',
  public.current_membre_id(),current_setting('test.anne'),'Fausse date'));
SELECT pg_temp.refuse('UPDATE public.messages SET contenu = ''Altéré''');
SELECT pg_temp.refuse('UPDATE public.messages SET destinataire = ''aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa''');
SELECT pg_temp.refuse('DELETE FROM public.messages');
DO $$ DECLARE n int; BEGIN
  UPDATE public.messages SET lu = true;
  GET DIAGNOSTICS n = ROW_COUNT;
  ASSERT n = 0, 'Expéditeur peut marquer lu';
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',false);
SET ROLE authenticated;
DO $$ BEGIN
  ASSERT (SELECT count(*) = 1 FROM public.messages), 'Anne lit un message privé d’autrui';
  ASSERT (SELECT count(*) = 1 FROM public.messages WHERE NOT lu), 'Non-lus incohérents';
END $$;
UPDATE public.messages SET lu = true;
SELECT pg_temp.refuse('UPDATE public.messages SET lu = false');
INSERT INTO public.messages(expediteur,destinataire,contenu)
VALUES (public.current_membre_id(),'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Message privé Anne');
RESET ROLE;

-- Même le bureau n'a aucun accès transversal à la messagerie.
SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
SET ROLE authenticated;
DO $$ BEGIN ASSERT (SELECT count(*) = 0 FROM public.messages), 'Bureau lit les messages d’autrui'; END $$;
SELECT pg_temp.refuse(format('UPDATE public.membres SET role = %L WHERE id = %L','president',current_setting('test.bureau')));
SELECT pg_temp.refuse(format('UPDATE public.membres SET statut = %L WHERE id = %L','suspendu',current_setting('test.paul')));
SELECT pg_temp.refuse(format('SELECT public.changer_statut(%L,%L)',current_setting('test.paul'),'inactif'),'22023');
SELECT pg_temp.refuse('SELECT public.refuser_membre(''aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'')');
SELECT pg_temp.refuse(format('SELECT public.supprimer_membre(%L,%L,%L)',current_setting('test.paul'),'ACHUS-002','SUPPRIMER DÉFINITIVEMENT'));
RESET ROLE;

-- Déclaration liée à l'événement. Ni doublon, ni validation, ni date arbitraire.
SELECT set_config('request.jwt.claim.sub','99999999-9999-4999-8999-999999999999',false);
SET ROLE authenticated;
INSERT INTO public.presences_evenements(membre_id,evenement_id,date_session)
VALUES (public.current_membre_id(),'10000000-0000-4000-8000-000000000001',(now() AT TIME ZONE 'America/Port-au-Prince')::date - 1);
SELECT pg_temp.refuse(format('INSERT INTO public.presences_evenements(membre_id,evenement_id,date_session) VALUES (%L,%L,%L)',
  public.current_membre_id(),'10000000-0000-4000-8000-000000000001',(now() AT TIME ZONE 'America/Port-au-Prince')::date - 1),'23505');
SELECT pg_temp.refuse('UPDATE public.presences_evenements SET statut = ''approuvee''');
SELECT pg_temp.refuse('DELETE FROM public.presences_evenements');
SELECT pg_temp.refuse(format('INSERT INTO public.presences_evenements(membre_id,evenement_id,date_session,statut) VALUES (%L,%L,%L,%L)',
  public.current_membre_id(),'10000000-0000-4000-8000-000000000001',CURRENT_DATE,'approuvee'));
SELECT pg_temp.refuse(format('INSERT INTO public.presences_evenements(membre_id,evenement_id,date_session) VALUES (%L,%L,%L)',
  public.current_membre_id(),'10000000-0000-4000-8000-000000000001',CURRENT_DATE + 1),'22023');
SELECT pg_temp.refuse(format('INSERT INTO public.presences_evenements(membre_id,evenement_id,date_session) VALUES (%L,%L,%L)',
  current_setting('test.anne'),'10000000-0000-4000-8000-000000000001',(now() AT TIME ZONE 'America/Port-au-Prince')::date - 1));
DO $$ DECLARE p uuid; BEGIN
  SELECT id INTO p FROM public.presences_evenements LIMIT 1;
  PERFORM pg_temp.refuse(format('SELECT public.decider_presence(%L,%L,%L)',p,'approuvee',''));
  ASSERT (SELECT count(*) = 0 FROM public.statistiques_presences(CURRENT_DATE - 30, CURRENT_DATE)), 'Stats accessibles au membre';
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',false);
SET ROLE authenticated;
DO $$ BEGIN ASSERT (SELECT count(*) = 0 FROM public.presences_evenements), 'Anne lit les présences de Paul'; END $$;
INSERT INTO public.presences_evenements(membre_id,evenement_id,date_session)
VALUES (public.current_membre_id(),'10000000-0000-4000-8000-000000000001',(now() AT TIME ZONE 'America/Port-au-Prince')::date - 1);
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
SET ROLE authenticated;
DO $$ DECLARE p uuid; a uuid; stats record; BEGIN
  SELECT id INTO p FROM public.presences_evenements WHERE membre_id = current_setting('test.paul')::uuid;
  SELECT id INTO a FROM public.presences_evenements WHERE membre_id = current_setting('test.anne')::uuid;
  PERFORM public.decider_presence(p,'approuvee','');
  PERFORM pg_temp.refuse(format('SELECT public.decider_presence(%L,%L,%L)',p,'refusee','Après coup'),'22023');
  PERFORM pg_temp.refuse(format('SELECT public.decider_presence(%L,%L,%L)',a,'refusee',''),'22023');
  PERFORM public.decider_presence(a,'refusee','Non constatée');
  SELECT * INTO stats FROM public.statistiques_presences((now() AT TIME ZONE 'America/Port-au-Prince')::date - 1,(now() AT TIME ZONE 'America/Port-au-Prince')::date - 1)
    WHERE membre_id = current_setting('test.paul')::uuid;
  ASSERT stats.approuvees = 1 AND stats.seances >= 1 AND stats.taux = round(100.0 / stats.seances,1), 'Taux incorrect';
END $$;
-- FK restrictive : l'agenda ne peut pas effacer l'historique.
SELECT pg_temp.refuse('DELETE FROM public.evenements WHERE id = ''10000000-0000-4000-8000-000000000001''','23503');
-- Propre présence : un autre responsable doit valider.
INSERT INTO public.presences_evenements(membre_id,evenement_id,date_session)
VALUES (public.current_membre_id(),'10000000-0000-4000-8000-000000000001',(now() AT TIME ZONE 'America/Port-au-Prince')::date - 1);
DO $$ DECLARE p uuid; BEGIN
  SELECT id INTO p FROM public.presences_evenements WHERE membre_id = public.current_membre_id();
  PERFORM pg_temp.refuse(format('SELECT public.decider_presence(%L,%L,%L)',p,'approuvee',''));
END $$;
RESET ROLE;

-- Retrait motivé, suppression présidentielle et numéro durable.
SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
SET ROLE authenticated;
SELECT pg_temp.refuse(format('SELECT public.retirer_membre(%L,%L,%L,CURRENT_DATE)',current_setting('test.paul'),'inactif',''),'22023');
SELECT public.retirer_membre(current_setting('test.paul')::uuid,'suspendu','Absences répétées',CURRENT_DATE);
SELECT pg_temp.refuse('INSERT INTO public.journal_admin(action) VALUES (''faux'')');
SELECT pg_temp.refuse('DELETE FROM public.historique_statuts');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','99999999-9999-4999-8999-999999999999',false);
SET ROLE authenticated;
DO $$ BEGIN
  ASSERT (SELECT count(*) = 0 FROM public.messages), 'Suspendu lit les messages';
  ASSERT (SELECT count(*) = 0 FROM public.contacts_messagerie()), 'Suspendu lit l’annuaire';
  ASSERT (SELECT count(*) = 1 FROM public.historique_statuts), 'Le membre ne retrouve pas son retrait';
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
SET ROLE authenticated;
SELECT pg_temp.refuse(format('SELECT public.supprimer_membre(%L,%L,%L)',current_setting('test.paul'),'ACHUS-002','oui'),'22023');
SELECT pg_temp.refuse(format('SELECT public.supprimer_membre(%L,%L,%L)',current_setting('test.paul'),'ACHUS-999','SUPPRIMER DÉFINITIVEMENT'),'22023');
SELECT public.supprimer_membre(current_setting('test.paul')::uuid,'ACHUS-002','SUPPRIMER DÉFINITIVEMENT');
DO $$ BEGIN
  ASSERT (SELECT count(*) = 0 FROM public.membres WHERE id = current_setting('test.paul')::uuid), 'Fiche non supprimée';
  ASSERT (SELECT count(*) = 0 FROM public.messages WHERE expediteur = current_setting('test.paul')::uuid OR destinataire = current_setting('test.paul')::uuid), 'Messages orphelins';
  ASSERT (SELECT count(*) = 1 FROM public.historique_statuts WHERE numero_membre = 'ACHUS-002' AND membre_id IS NULL), 'Historique perdu';
  ASSERT (SELECT count(*) = 1 FROM public.journal_admin WHERE cible_numero = 'ACHUS-002' AND action = 'suppression_membre'), 'Suppression non journalisée';
END $$;
RESET ROLE;

-- Même après un recul artificiel de la séquence, 002 reste réservé.
SELECT setval('public.numero_membre_seq',1,true);
SELECT set_config('test.nouveau_numero',(SELECT numero_membre FROM public.approuver_membre((SELECT id FROM public.membres WHERE user_id = '33333333-3333-4333-8333-333333333333'))),false);
DO $$ BEGIN
  ASSERT current_setting('test.nouveau_numero') <> 'ACHUS-002', 'Numéro réattribué';
  PERFORM pg_temp.refuse('INSERT INTO public.membres(prenom,nom,numero_membre) VALUES (''Faux'',''Numéro'',''ACHUS-002'')','23505');
  PERFORM pg_temp.refuse(format('INSERT INTO public.membres(id,prenom,nom,numero_membre) VALUES (%L,%L,%L,%L)', current_setting('test.paul'),'Même UUID','Autre personne','ACHUS-002'),'23505');
END $$;
-- Plus de troncature à 4 chiffres.
SELECT setval('public.numero_membre_seq',999,true);
SELECT set_config('test.numero_1000',(SELECT numero_membre FROM public.approuver_membre((SELECT id FROM public.membres WHERE user_id = '44444444-4444-4444-8444-444444444444'))),false);
DO $$ BEGIN ASSERT current_setting('test.numero_1000') = 'ACHUS-1000', 'Numéro tronqué au-delà de 999'; END $$;

-- Un compte supprimé reste sans fiche, sans annuaire, sans accès à autrui.
SELECT set_config('request.jwt.claim.sub','99999999-9999-4999-8999-999999999999',false);
SET ROLE authenticated;
DO $$ BEGIN
  ASSERT public.current_membre_id() IS NULL, 'Compte encore rattaché';
  ASSERT (SELECT count(*) = 0 FROM public.contacts_messagerie()), 'Compte supprimé lit l’annuaire';
  ASSERT (SELECT count(*) = 0 FROM public.membres), 'Compte supprimé lit les fiches';
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','',false);
