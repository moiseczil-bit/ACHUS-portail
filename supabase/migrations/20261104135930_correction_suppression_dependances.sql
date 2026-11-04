-- Liens historiques observés en production : conserver les publications sans leur auteur.
BEGIN;
CREATE OR REPLACE FUNCTION public.supprimer_membre(p_id uuid, p_numero text, p_confirmation text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE fiche public.membres;
BEGIN
  IF auth.uid() IS NULL OR NOT public.est_president() THEN
    RAISE EXCEPTION 'Seul le président peut supprimer définitivement une fiche.' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO fiche FROM public.membres WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Membre introuvable.' USING ERRCODE = '22023'; END IF;
  IF fiche.role = 'president' OR fiche.user_id = auth.uid() OR fiche.statut NOT IN ('inactif', 'suspendu') THEN
    RAISE EXCEPTION 'Retirez d’abord le membre. La fiche du président est protégée.' USING ERRCODE = '42501';
  END IF;
  IF p_numero IS DISTINCT FROM coalesce(fiche.numero_membre, fiche.id::text)
    OR p_confirmation IS DISTINCT FROM 'SUPPRIMER DÉFINITIVEMENT' THEN
    RAISE EXCEPTION 'Les deux confirmations ne correspondent pas.' USING ERRCODE = '22023';
  END IF;
  UPDATE public.presence SET valide_par = NULL WHERE valide_par = fiche.id;
  UPDATE public.annonces SET auteur_id = NULL WHERE auteur_id = fiche.id;
  UPDATE public.photos SET uploade_par = NULL WHERE uploade_par = fiche.id;
  UPDATE public.votes SET cree_par = NULL WHERE cree_par = fiche.id;
  -- Les tables historiques n'avaient pas toutes de FK ; nettoyage ciblé.
  DELETE FROM public.presence WHERE membre_id = fiche.id;
  DELETE FROM public.presences WHERE membre_id = fiche.id;
  DELETE FROM public.quiz_resultats WHERE membre_id = fiche.id OR membre_id = fiche.user_id;
  DELETE FROM public.vote_reponses WHERE membre_id = fiche.id OR membre_id = fiche.user_id;
  DELETE FROM public.membres WHERE id = fiche.id;
  -- auth.users est conservé : le compte n'a plus de fiche ni d'accès aux membres.
  -- Les réservations de numéro et les traces administratives restent conservées.
END $$;

REVOKE ALL ON FUNCTION public.supprimer_membre(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.supprimer_membre(uuid,text,text) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
