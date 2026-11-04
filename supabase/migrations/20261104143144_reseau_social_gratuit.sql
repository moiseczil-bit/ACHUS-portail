-- Évolution additive ; ne pas appliquer en production sans accord.
BEGIN;
CREATE TABLE IF NOT EXISTS public.publications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), auteur uuid NOT NULL REFERENCES public.membres(id) ON DELETE CASCADE,
 contenu text NOT NULL CHECK (length(btrim(contenu)) BETWEEN 1 AND 4000),
 masque boolean NOT NULL DEFAULT false, cree_le timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.commentaires (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), publication uuid NOT NULL REFERENCES public.publications(id) ON DELETE CASCADE,
 auteur uuid NOT NULL REFERENCES public.membres(id) ON DELETE CASCADE,
 contenu text NOT NULL CHECK(length(btrim(contenu)) BETWEEN 1 AND 1000),
 masque boolean NOT NULL DEFAULT false, cree_le timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.liens_familiaux (
 parent_id uuid NOT NULL REFERENCES public.membres(id) ON DELETE CASCADE,
 enfant_id uuid NOT NULL REFERENCES public.membres(id) ON DELETE CASCADE,
 cree_par uuid REFERENCES public.membres(id) ON DELETE SET NULL,
 cree_le timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(parent_id,enfant_id), CHECK(parent_id <> enfant_id)
);
CREATE TABLE IF NOT EXISTS public.appels (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), expediteur uuid NOT NULL REFERENCES public.membres(id) ON DELETE CASCADE,
 destinataire uuid NOT NULL REFERENCES public.membres(id) ON DELETE CASCADE,
 mode text NOT NULL CHECK(mode IN ('audio','video')), salle uuid NOT NULL DEFAULT gen_random_uuid(),
 statut text NOT NULL DEFAULT 'en_attente' CHECK(statut IN ('en_attente','accepte','refuse','annule','termine')),
 cree_le timestamptz NOT NULL DEFAULT now(), expire_le timestamptz NOT NULL DEFAULT now() + interval '5 minutes',
 CHECK(expediteur <> destinataire)
);
CREATE TABLE IF NOT EXISTS public.reunions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), titre text NOT NULL CHECK(length(btrim(titre)) BETWEEN 1 AND 160),
 organisateur uuid REFERENCES public.membres(id) ON DELETE SET NULL,
 debut timestamptz NOT NULL, fin timestamptz NOT NULL, salle uuid NOT NULL DEFAULT gen_random_uuid(),
 public_vise text NOT NULL CHECK(public_vise IN ('membres','parents','tous')),
 annulee boolean NOT NULL DEFAULT false, cree_le timestamptz NOT NULL DEFAULT now(),
 CHECK(fin > debut AND fin <= debut + interval '12 hours')
);
CREATE INDEX IF NOT EXISTS publications_date_idx ON public.publications(cree_le DESC,id);
CREATE INDEX IF NOT EXISTS publications_auteur_idx ON public.publications(auteur);
CREATE INDEX IF NOT EXISTS commentaires_auteur_idx ON public.commentaires(auteur);
CREATE INDEX IF NOT EXISTS liens_createur_idx ON public.liens_familiaux(cree_par);
CREATE INDEX IF NOT EXISTS reunions_organisateur_idx ON public.reunions(organisateur);
CREATE INDEX IF NOT EXISTS commentaires_publication_idx ON public.commentaires(publication,cree_le,id);
CREATE INDEX IF NOT EXISTS liens_enfant_idx ON public.liens_familiaux(enfant_id);
CREATE INDEX IF NOT EXISTS appels_destinataire_idx ON public.appels(destinataire,cree_le DESC);
CREATE INDEX IF NOT EXISTS appels_expediteur_idx ON public.appels(expediteur,cree_le DESC);
CREATE INDEX IF NOT EXISTS reunions_debut_idx ON public.reunions(debut);
ALTER TABLE public.publications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commentaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.liens_familiaux ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reunions ENABLE ROW LEVEL SECURITY;

-- Relation de communication : les parents ne contactent que le bureau.
-- Les lectures d'anciens messages conservent la règle existante (participants seuls).
CREATE OR REPLACE FUNCTION public.contact_reseau(p_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT EXISTS(SELECT 1 FROM public.membres s, public.membres d
 WHERE s.user_id = auth.uid() AND s.statut = 'actif' AND d.id = p_id AND d.statut = 'actif'
 AND d.user_id IS NOT NULL AND s.id <> d.id
 AND (coalesce(s.type_compte,'') <> 'parent' OR d.role IN ('bureau','president'))
 AND (coalesce(d.type_compte,'') <> 'parent' OR s.role IN ('bureau','president')));
$$;
CREATE OR REPLACE FUNCTION public.contacts_messagerie()
RETURNS TABLE(id uuid,prenom text,nom text,numero_membre text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT m.id,m.prenom,m.nom,m.numero_membre FROM public.membres m
 WHERE public.contact_reseau(m.id) ORDER BY m.nom,m.prenom,m.id;
$$;
DROP POLICY IF EXISTS messages_envoi ON public.messages;
CREATE POLICY messages_envoi ON public.messages FOR INSERT TO authenticated
 WITH CHECK(expediteur = (SELECT public.current_membre_id()) AND public.contact_reseau(destinataire));

DROP POLICY IF EXISTS publications_lire ON public.publications;
CREATE POLICY publications_lire ON public.publications FOR SELECT TO authenticated
 USING((SELECT public.is_membre_actif()) AND (NOT masque OR (SELECT public.is_bureau())));
DROP POLICY IF EXISTS publications_ecrire ON public.publications;
CREATE POLICY publications_ecrire ON public.publications FOR INSERT TO authenticated
 WITH CHECK((SELECT public.is_membre_actif()) AND auteur = (SELECT public.current_membre_id()));
DROP POLICY IF EXISTS commentaires_lire ON public.commentaires;
CREATE POLICY commentaires_lire ON public.commentaires FOR SELECT TO authenticated
 USING((SELECT public.is_membre_actif()) AND (NOT masque OR (SELECT public.is_bureau()))
 AND EXISTS(SELECT 1 FROM public.publications p WHERE p.id = publication));
DROP POLICY IF EXISTS commentaires_ecrire ON public.commentaires;
CREATE POLICY commentaires_ecrire ON public.commentaires FOR INSERT TO authenticated
 WITH CHECK((SELECT public.is_membre_actif()) AND auteur = (SELECT public.current_membre_id())
 AND EXISTS(SELECT 1 FROM public.publications p WHERE p.id = publication AND NOT p.masque));
DROP POLICY IF EXISTS liens_lire ON public.liens_familiaux;
CREATE POLICY liens_lire ON public.liens_familiaux FOR SELECT TO authenticated
 USING((SELECT public.is_bureau()) OR ((SELECT public.is_membre_actif()) AND parent_id = (SELECT public.current_membre_id())));
DROP POLICY IF EXISTS appels_lire ON public.appels;
CREATE POLICY appels_lire ON public.appels FOR SELECT TO authenticated
 USING(public.contact_messagerie_actif((SELECT public.current_membre_id()))
 AND (expediteur = (SELECT public.current_membre_id()) OR destinataire = (SELECT public.current_membre_id())));
DROP POLICY IF EXISTS reunions_lire ON public.reunions;
CREATE POLICY reunions_lire ON public.reunions FOR SELECT TO authenticated
 USING((SELECT public.is_membre_actif()) AND ((SELECT public.is_bureau()) OR public_vise = 'tous'
 OR EXISTS(SELECT 1 FROM public.membres m WHERE m.user_id = (SELECT auth.uid())
 AND ((m.type_compte = 'parent' AND public_vise = 'parents') OR (coalesce(m.type_compte,'') <> 'parent' AND public_vise = 'membres')))));
REVOKE ALL ON public.publications,public.commentaires,public.liens_familiaux,public.appels,public.reunions FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.publications,public.commentaires,public.liens_familiaux,public.appels,public.reunions TO authenticated;
GRANT INSERT(auteur,contenu) ON public.publications TO authenticated;
GRANT INSERT(publication,auteur,contenu) ON public.commentaires TO authenticated;

-- Noms des auteurs uniquement lorsqu'une contribution est visible ; pas d'annuaire familial.
CREATE OR REPLACE FUNCTION public.noms_contributions(p_ids uuid[])
RETURNS TABLE(id uuid,prenom text,nom text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT m.id,m.prenom,m.nom FROM public.membres m
 WHERE public.is_membre_actif() AND m.id = ANY(p_ids) AND cardinality(p_ids) <= 100
 AND (EXISTS(SELECT 1 FROM public.publications p WHERE p.auteur=m.id AND (NOT p.masque OR public.is_bureau()))
 OR EXISTS(SELECT 1 FROM public.commentaires c JOIN public.publications p ON p.id=c.publication
 WHERE c.auteur=m.id AND ((NOT c.masque AND NOT p.masque) OR public.is_bureau())));
$$;
-- Retrait définitif de l'affichage : aucun bouton ne permet de rétablir une modération.
CREATE OR REPLACE FUNCTION public.masquer_contribution(p_id uuid,p_commentaire boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE a uuid;
BEGIN
 IF NOT public.is_membre_actif() THEN RAISE EXCEPTION 'Accès refusé' USING ERRCODE='42501'; END IF;
 IF p_commentaire THEN SELECT auteur INTO a FROM public.commentaires WHERE id=p_id;
 ELSE SELECT auteur INTO a FROM public.publications WHERE id=p_id; END IF;
 IF a IS NULL OR (a <> public.current_membre_id() AND NOT public.is_bureau()) THEN RAISE EXCEPTION 'Accès refusé' USING ERRCODE='42501'; END IF;
 IF p_commentaire THEN UPDATE public.commentaires SET masque=true WHERE id=p_id;
 ELSE UPDATE public.publications SET masque=true WHERE id=p_id; END IF;
 INSERT INTO public.journal_admin(acteur_id,cible_id,action,details)
 VALUES(public.current_membre_id(),a,'masquer_contribution',jsonb_build_object('id',p_id,'commentaire',p_commentaire));
END $$;
CREATE OR REPLACE FUNCTION public.gerer_lien_familial(p_parent uuid,p_enfant uuid,p_retirer boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
 IF NOT public.is_bureau() THEN RAISE EXCEPTION 'Réservé au bureau' USING ERRCODE='42501'; END IF;
 IF p_retirer THEN DELETE FROM public.liens_familiaux WHERE parent_id=p_parent AND enfant_id=p_enfant;
 ELSE
  IF p_parent=p_enfant OR NOT EXISTS(SELECT 1 FROM public.membres WHERE id=p_parent AND type_compte='parent' AND statut='actif')
   OR NOT EXISTS(SELECT 1 FROM public.membres WHERE id=p_enfant AND coalesce(type_compte,'') <> 'parent') THEN
   RAISE EXCEPTION 'Choisissez un parent actif et un autre membre' USING ERRCODE='22023'; END IF;
  INSERT INTO public.liens_familiaux(parent_id,enfant_id,cree_par) VALUES(p_parent,p_enfant,public.current_membre_id()) ON CONFLICT DO NOTHING;
 END IF;
 INSERT INTO public.journal_admin(acteur_id,cible_id,action,details) VALUES(public.current_membre_id(),p_enfant,
 CASE WHEN p_retirer THEN 'retirer_lien_familial' ELSE 'ajouter_lien_familial' END,jsonb_build_object('parent_id',p_parent));
END $$;
CREATE OR REPLACE FUNCTION public.enfants_parent()
RETURNS TABLE(id uuid,prenom text,nom text,numero_membre text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT e.id,e.prenom,e.nom,e.numero_membre FROM public.liens_familiaux l
 JOIN public.membres p ON p.id=l.parent_id JOIN public.membres e ON e.id=l.enfant_id
 WHERE p.user_id=auth.uid() AND p.statut='actif' AND p.type_compte='parent' ORDER BY e.nom,e.prenom;
$$;
-- Aucun accès parent à membres, aux messages ou aux motifs de refus/retrait.
CREATE OR REPLACE FUNCTION public.presences_enfant(p_enfant uuid,p_debut date,p_fin date)
RETURNS TABLE(id uuid,titre text,date_session date,statut text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.enfants_parent() e WHERE e.id=p_enfant) THEN RAISE EXCEPTION 'Lien familial non autorisé' USING ERRCODE='42501'; END IF;
 IF p_debut IS NULL OR p_fin IS NULL OR p_fin < p_debut OR p_fin-p_debut > 365 THEN RAISE EXCEPTION 'Période invalide (366 jours maximum)' USING ERRCODE='22023'; END IF;
 RETURN QUERY SELECT pe.id,e.titre,pe.date_session,pe.statut FROM public.presences_evenements pe
 JOIN public.evenements e ON e.id=pe.evenement_id WHERE pe.membre_id=p_enfant AND pe.date_session BETWEEN p_debut AND p_fin
 ORDER BY pe.date_session DESC,pe.id;
END $$;
CREATE OR REPLACE FUNCTION public.inviter_appel(p_destinataire uuid,p_mode text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE resultat uuid; soi uuid := public.current_membre_id();
BEGIN
 IF NOT public.contact_reseau(p_destinataire) THEN RAISE EXCEPTION 'Contact non autorisé' USING ERRCODE='42501'; END IF;
 IF p_mode NOT IN ('audio','video') OR p_mode IS NULL THEN RAISE EXCEPTION 'Mode invalide' USING ERRCODE='22023'; END IF;
 -- Ordre stable des verrous pour empêcher deux invitations simultanées entre les mêmes comptes.
 PERFORM id FROM public.membres WHERE id IN (soi,p_destinataire) ORDER BY id FOR UPDATE;
 IF EXISTS(SELECT 1 FROM public.appels WHERE (expediteur IN (soi,p_destinataire) OR destinataire IN (soi,p_destinataire))
 AND ((statut='en_attente' AND expire_le > now()) OR (statut='accepte' AND cree_le > now()-interval '12 hours'))) THEN
 RAISE EXCEPTION 'Un appel est déjà en cours ou en attente' USING ERRCODE='22023'; END IF;
 INSERT INTO public.appels(expediteur,destinataire,mode) VALUES(soi,p_destinataire,p_mode) RETURNING id INTO resultat;
 RETURN resultat;
END $$;
CREATE OR REPLACE FUNCTION public.repondre_appel(p_id uuid,p_action text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE a public.appels; soi uuid := public.current_membre_id();
BEGIN
 SELECT * INTO a FROM public.appels WHERE id=p_id FOR UPDATE;
 IF soi IS NULL OR NOT public.contact_messagerie_actif(soi) OR a.id IS NULL OR soi NOT IN(a.expediteur,a.destinataire) THEN
 RAISE EXCEPTION 'Accès refusé' USING ERRCODE='42501'; END IF;
 IF p_action IN ('accepte','refuse') THEN
  IF soi<>a.destinataire OR a.statut<>'en_attente' OR a.expire_le<=now() OR NOT public.contact_reseau(a.expediteur) THEN
   RAISE EXCEPTION 'Invitation expirée ou non autorisée' USING ERRCODE='22023'; END IF;
 ELSIF p_action='annule' THEN
  IF soi<>a.expediteur OR a.statut<>'en_attente' THEN RAISE EXCEPTION 'Transition interdite' USING ERRCODE='22023'; END IF;
 ELSIF p_action='termine' THEN
  IF a.statut<>'accepte' THEN RAISE EXCEPTION 'Transition interdite' USING ERRCODE='22023'; END IF;
 ELSE RAISE EXCEPTION 'Action invalide' USING ERRCODE='22023'; END IF;
 UPDATE public.appels SET statut=p_action WHERE id=p_id;
END $$;
CREATE OR REPLACE FUNCTION public.creer_reunion(p_titre text,p_debut timestamptz,p_fin timestamptz,p_public text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE resultat uuid;
BEGIN
 IF NOT public.is_bureau() THEN RAISE EXCEPTION 'Réservé au bureau' USING ERRCODE='42501'; END IF;
 INSERT INTO public.reunions(titre,organisateur,debut,fin,public_vise) VALUES(btrim(p_titre),public.current_membre_id(),p_debut,p_fin,p_public) RETURNING id INTO resultat;
 INSERT INTO public.journal_admin(acteur_id,action,details) VALUES(public.current_membre_id(),'creer_reunion',jsonb_build_object('id',resultat));
 RETURN resultat;
END $$;
CREATE OR REPLACE FUNCTION public.annuler_reunion(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
 IF NOT public.is_bureau() THEN RAISE EXCEPTION 'Réservé au bureau' USING ERRCODE='42501'; END IF;
 UPDATE public.reunions SET annulee=true WHERE id=p_id;
 INSERT INTO public.journal_admin(acteur_id,action,details) VALUES(public.current_membre_id(),'annuler_reunion',jsonb_build_object('id',p_id));
END $$;
REVOKE ALL ON FUNCTION public.contact_reseau(uuid),public.noms_contributions(uuid[]),public.masquer_contribution(uuid,boolean),
 public.gerer_lien_familial(uuid,uuid,boolean),public.enfants_parent(),public.presences_enfant(uuid,date,date),
 public.inviter_appel(uuid,text),public.repondre_appel(uuid,text),public.creer_reunion(text,timestamptz,timestamptz,text),public.annuler_reunion(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.contact_reseau(uuid),public.noms_contributions(uuid[]),public.masquer_contribution(uuid,boolean),
 public.gerer_lien_familial(uuid,uuid,boolean),public.enfants_parent(),public.presences_enfant(uuid,date,date),
 public.inviter_appel(uuid,text),public.repondre_appel(uuid,text),public.creer_reunion(text,timestamptz,timestamptz,text),public.annuler_reunion(uuid) TO authenticated;
COMMIT;
