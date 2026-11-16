-- Le grade est attribué par le bureau, jamais par le titulaire membre.
BEGIN;
-- Défense en profondeur pour les anciens clients : aucune écriture par cette RPC.
CREATE OR REPLACE FUNCTION public.modifier_mon_grade(p_grade text)
RETURNS text LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  RAISE EXCEPTION 'Le grade est attribué uniquement par l’administration.' USING ERRCODE = '42501';
END $$;
REVOKE ALL ON FUNCTION public.modifier_mon_grade(text) FROM PUBLIC, anon, authenticated;

-- Realtime respecte les droits SELECT/RLS de membres. Aucune politique n'est élargie.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname='supabase_realtime' AND NOT puballtables)
  AND NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='membres') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.membres;
  END IF;
END $$;
COMMIT;
