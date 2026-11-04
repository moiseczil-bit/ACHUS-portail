-- Preuves après migration. Échoue (exception) si un résultat est faux.

DO $$
DECLARE
  n int;
  v_prenom text;
  v_nom text;
  v_role text;
  v_statut text;
  v_num text;
  v_uid uuid;
  v_grade text;
BEGIN
  SELECT count(*) INTO n FROM auth.users;
  IF n <> 5 THEN
    RAISE EXCEPTION 'FAIL auth users = % (attendu 5)', n;
  END IF;

  SELECT count(*) INTO n FROM public.membres
  WHERE id IN (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
  );
  IF n <> 2 THEN
    RAISE EXCEPTION 'FAIL fiches d’origine perdues (%)', n;
  END IF;

  SELECT prenom, nom, role, statut, numero_membre, user_id, grade
    INTO v_prenom, v_nom, v_role, v_statut, v_num, v_uid, v_grade
  FROM public.membres
  WHERE id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  IF v_prenom <> 'Moïse-Son' OR v_nom <> 'Cezil' OR v_grade <> 'Général' THEN
    RAISE EXCEPTION 'FAIL identité président modifiée';
  END IF;
  IF v_role <> 'president' OR v_statut <> 'actif' OR v_num <> 'ACHUS-001' THEN
    RAISE EXCEPTION 'FAIL président role=% statut=% numero=%', v_role, v_statut, v_num;
  END IF;
  IF v_uid <> '11111111-1111-4111-8111-111111111111' THEN
    RAISE EXCEPTION 'FAIL président non relié par e-mail (%)', v_uid;
  END IF;

  SELECT prenom, nom, statut, role, numero_membre, user_id
    INTO v_prenom, v_nom, v_statut, v_role, v_num, v_uid
  FROM public.membres
  WHERE id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

  IF v_prenom <> 'Jean' OR v_nom <> 'Baptiste' OR v_statut <> 'actif' OR v_role <> 'membre' THEN
    RAISE EXCEPTION 'FAIL seconde fiche altérée';
  END IF;
  IF v_num IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL la 2e fiche ne doit pas prendre ACHUS-002 automatiquement (%)', v_num;
  END IF;
  IF v_uid IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL user_id invalide non effacé';
  END IF;

  SELECT count(*) INTO n FROM public.membres
  WHERE user_id IN (
    '22222222-2222-4222-8222-222222222222',
    '33333333-3333-4333-8333-333333333333',
    '44444444-4444-4444-8444-444444444444',
    '55555555-5555-4555-8555-555555555555'
  ) AND statut = 'en_attente' AND role = 'membre';
  IF n <> 4 THEN
    RAISE EXCEPTION 'FAIL rattrapage des comptes sans fiche (%)', n;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND policyname = 'public_all'
  ) THEN
    RAISE EXCEPTION 'FAIL politique public_all encore présente';
  END IF;

  IF has_table_privilege('anon', 'public.membres', 'SELECT') THEN
    RAISE EXCEPTION 'FAIL anon a encore SELECT sur membres';
  END IF;

  SELECT count(*) INTO n FROM public.evenements
  WHERE titre IN ('Fête du Drapeau', 'Réunion hebdomadaire');
  IF n <> 2 THEN
    RAISE EXCEPTION 'FAIL agenda semé (%)', n;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM storage.buckets WHERE id = 'photos-membres' AND public = false
  ) THEN
    RAISE EXCEPTION 'FAIL bucket photos-membres';
  END IF;

  RAISE NOTICE 'OK conservation des 2 fiches, 5 comptes, ACHUS-001, agenda, bucket';
END $$;

-- Déclencheur d’inscription.
INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES (
  '99999999-9999-4999-8999-999999999999',
  'nouveau@example.ht',
  jsonb_build_object(
    'prenom', 'Paul',
    'nom', 'Joseph',
    'telephone', '+509 3000 0000',
    'quartier', 'Santo 13',
    'programme_interet', 'Leadership',
    'motivation', 'Servir la jeunesse',
    'type_compte', 'moderateur'
  )
);

DO $$
DECLARE
  r public.membres;
BEGIN
  SELECT * INTO r FROM public.membres
  WHERE user_id = '99999999-9999-4999-8999-999999999999';
  IF r.id IS NULL THEN
    RAISE EXCEPTION 'FAIL déclencheur : aucune fiche';
  END IF;
  IF r.statut <> 'en_attente' OR r.role <> 'membre' OR r.type_compte <> 'membre' THEN
    RAISE EXCEPTION 'FAIL déclencheur statut=% role=% type=%', r.statut, r.role, r.type_compte;
  END IF;
  IF r.prenom <> 'Paul' OR r.nom <> 'Joseph' OR r.quartier <> 'Santo 13' THEN
    RAISE EXCEPTION 'FAIL métadonnées non recopiées';
  END IF;
  IF r.grade ~ '^[0-9]+$' THEN
    RAISE EXCEPTION 'FAIL grade numérique';
  END IF;
  RAISE NOTICE 'OK déclencheur en_attente (moderateur ignoré)';
END $$;

-- anon ne lit pas membres
DO $$
BEGIN
  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN
    PERFORM 1 FROM public.membres LIMIT 1;
    RAISE EXCEPTION 'FAIL anon a lu membres';
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'OK anon bloqué sur membres';
  END;
  EXECUTE 'RESET ROLE';
END $$;

-- Le nouveau membre ne voit pas les autres et ne peut pas se promouvoir.
DO $$
DECLARE
  n int;
  v_role text;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '99999999-9999-4999-8999-999999999999', true);
  EXECUTE 'SET LOCAL ROLE authenticated';

  SELECT count(*) INTO n FROM public.membres;
  IF n <> 1 THEN
    RAISE EXCEPTION 'FAIL un membre voit % fiches (attendu 1)', n;
  END IF;

  SELECT count(*) INTO n FROM public.membres WHERE numero_membre = 'ACHUS-001';
  IF n <> 0 THEN
    RAISE EXCEPTION 'FAIL le membre lit la fiche du président';
  END IF;

  BEGIN
    UPDATE public.membres
    SET role = 'president', statut = 'actif', grade = '9'
    WHERE user_id = '99999999-9999-4999-8999-999999999999';
    RAISE EXCEPTION 'FAIL la promotion a été acceptée';
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'OK promotion refusée';
  END;

  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claim.sub', '', true);

  SELECT role INTO v_role FROM public.membres
  WHERE user_id = '99999999-9999-4999-8999-999999999999';
  IF v_role <> 'membre' THEN
    RAISE EXCEPTION 'FAIL rôle devenu %', v_role;
  END IF;
END $$;

-- Le membre ne peut pas appeler l’approbation. Le président le peut.
DO $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '99999999-9999-4999-8999-999999999999', true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.approuver_membre('99999999-9999-4999-8999-999999999999');
    RAISE EXCEPTION 'FAIL membre a approuvé';
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'OK approuver_membre refusé au membre';
  END;
  EXECUTE 'RESET ROLE';
END $$;

INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES (
  '88888888-8888-4888-8888-888888888888',
  'second@example.ht',
  '{"prenom":"Anne","nom":"Louis","telephone":"+509 1","quartier":"Santo"}'::jsonb
);

DO $$
DECLARE
  id_paul uuid;
  id_anne uuid;
  n1 text;
  n2 text;
  n3 text;
  pres text;
BEGIN
  SELECT id INTO id_paul FROM public.membres
  WHERE user_id = '99999999-9999-4999-8999-999999999999';
  SELECT id INTO id_anne FROM public.membres
  WHERE user_id = '88888888-8888-4888-8888-888888888888';

  PERFORM set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
  EXECUTE 'SET LOCAL ROLE authenticated';

  SELECT numero_membre INTO n1 FROM public.approuver_membre(id_paul);
  SELECT numero_membre INTO n2 FROM public.approuver_membre(id_paul);
  SELECT numero_membre INTO n3 FROM public.approuver_membre(id_anne);

  IF n1 <> 'ACHUS-002' OR n2 <> 'ACHUS-002' OR n3 <> 'ACHUS-003' THEN
    RAISE EXCEPTION 'FAIL numéros % / % / %', n1, n2, n3;
  END IF;

  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claim.sub', '', true);

  SELECT numero_membre INTO pres FROM public.membres
  WHERE id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  IF pres <> 'ACHUS-001' THEN
    RAISE EXCEPTION 'FAIL président n’est plus ACHUS-001 (%)', pres;
  END IF;

  IF EXISTS (
    SELECT numero_membre FROM public.membres
    WHERE numero_membre IS NOT NULL
    GROUP BY numero_membre
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'FAIL numéro en double';
  END IF;

  RAISE NOTICE 'OK numérotation ACHUS-002 / ACHUS-003, président ACHUS-001, pas de doublon';
END $$;
