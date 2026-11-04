SET ROLE anon;
SELECT pg_temp.refuse('SELECT public.modifier_mon_grade(''Sergent'')');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000003',false);
SELECT set_config('test.grade_role',(SELECT role FROM public.membres WHERE id=current_setting('test.enfant1')::uuid),false);
SELECT set_config('test.grade_numero',(SELECT numero_membre FROM public.membres WHERE id=current_setting('test.enfant1')::uuid),false);
SET ROLE authenticated;
SELECT public.modifier_mon_grade('  Sergent-chef  ');
DO $$ BEGIN
 ASSERT (SELECT grade='Sergent-chef' AND role=current_setting('test.grade_role') AND numero_membre=current_setting('test.grade_numero') FROM public.membres WHERE id=public.current_membre_id());
END $$;
SELECT pg_temp.refuse('SELECT public.modifier_mon_grade('''')','22023');
SELECT pg_temp.refuse('SELECT public.modifier_mon_grade(NULL)','22023');
SELECT pg_temp.refuse('SELECT public.modifier_mon_grade(repeat(''A'',81))','22023');
SELECT pg_temp.refuse('SELECT public.modifier_mon_grade(''9'')','22023');
SELECT pg_temp.refuse('SELECT public.modifier_mon_grade(E''Sergent\nPrésident'')','22023');
-- L'action ne permet pas de modifier d'autres champs ni d'ouvrir l'UPDATE direct du grade.
SELECT pg_temp.refuse('UPDATE public.membres SET role=''president'' WHERE id=public.current_membre_id()');
SELECT pg_temp.refuse('UPDATE public.membres SET grade=''Général'' WHERE id=public.current_membre_id()');
DO $$ BEGIN ASSERT (SELECT count(*)=1 FROM public.membres), 'Accès à une autre fiche'; END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000002',false);
SET ROLE authenticated;
SELECT pg_temp.refuse('SELECT public.modifier_mon_grade(''Sergent'')');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000001',false);
SET ROLE authenticated;
SELECT pg_temp.refuse('SELECT public.modifier_mon_grade(''Sergent'')');
RESET ROLE;
DO $$ BEGIN
 ASSERT EXISTS(SELECT 1 FROM public.journal_admin WHERE cible_id=current_setting('test.enfant1')::uuid AND details->>'grade'='Sergent-chef');
 ASSERT (SELECT grade='Sergent-chef' FROM public.membres WHERE id=current_setting('test.enfant1')::uuid);
END $$;
