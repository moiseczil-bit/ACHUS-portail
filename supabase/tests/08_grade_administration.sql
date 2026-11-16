-- La migration conserve les grades existants mais retire l'ancien libre-service.
DO $$ BEGIN
 ASSERT NOT has_function_privilege('anon','public.modifier_mon_grade(text)','EXECUTE');
 ASSERT NOT has_function_privilege('authenticated','public.modifier_mon_grade(text)','EXECUTE');
 ASSERT NOT (SELECT prosecdef FROM pg_proc WHERE oid='public.modifier_mon_grade(text)'::regprocedure);
END $$;
SELECT set_config('test.grade_autre',(SELECT grade FROM public.membres WHERE id=current_setting('test.parent2')::uuid),false);
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000003',false);
SET ROLE authenticated;
SELECT pg_temp.refuse('SELECT public.modifier_mon_grade(''Général'')');
SELECT pg_temp.refuse('UPDATE public.membres SET grade=''Général'' WHERE id=public.current_membre_id()');
UPDATE public.membres SET grade='Général' WHERE id=current_setting('test.parent2')::uuid;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
SET ROLE authenticated;
UPDATE public.membres SET grade='Caporal attribué' WHERE id=current_setting('test.enfant1')::uuid;
RESET ROLE;
DO $$ BEGIN
 ASSERT (SELECT grade=current_setting('test.grade_autre') FROM public.membres WHERE id=current_setting('test.parent2')::uuid);
 ASSERT (SELECT grade='Caporal attribué' AND role=current_setting('test.grade_role') AND numero_membre=current_setting('test.grade_numero') FROM public.membres WHERE id=current_setting('test.enfant1')::uuid);
 ASSERT EXISTS(SELECT 1 FROM public.journal_admin WHERE cible_id=current_setting('test.enfant1')::uuid AND details->>'grade'='Caporal attribué');
END $$;
SELECT set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000003',false);
SET ROLE authenticated;
DO $$ BEGIN
 ASSERT (SELECT count(*)=1 FROM public.membres);
 ASSERT (SELECT grade='Caporal attribué' FROM public.membres WHERE id=public.current_membre_id());
END $$;
RESET ROLE;
