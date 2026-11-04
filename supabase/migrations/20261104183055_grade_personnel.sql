-- Grade personnel : seul le grade de sa propre fiche est modifiable par cette action.
-- Aucun changement des politiques RLS ni des protections des autres champs.
BEGIN;
CREATE OR REPLACE FUNCTION public.modifier_mon_grade(p_grade text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE fiche public.membres; valeur text := btrim(p_grade);
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Connexion requise.' USING ERRCODE='42501'; END IF;
 SELECT * INTO fiche FROM public.membres WHERE user_id=auth.uid() FOR UPDATE;
 IF fiche.id IS NULL OR fiche.statut NOT IN ('actif','honoraire') OR fiche.type_compte='parent' THEN
  RAISE EXCEPTION 'Le grade personnel est réservé aux membres actifs ou honoraires.' USING ERRCODE='42501';
 END IF;
 IF valeur IS NULL OR length(valeur) NOT BETWEEN 1 AND 80 OR valeur !~ '[[:alpha:]]' OR valeur ~ '[[:cntrl:]]' THEN
  RAISE EXCEPTION 'Indiquez un grade en toutes lettres, sur une ligne (80 caractères maximum).' USING ERRCODE='22023';
 END IF;
 UPDATE public.membres SET grade=valeur WHERE id=fiche.id;
 -- Le déclencheur journaliser_membre existant conserve la trace de cette modification.
 RETURN valeur;
END $$;
REVOKE ALL ON FUNCTION public.modifier_mon_grade(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.modifier_mon_grade(text) TO authenticated;
COMMIT;
