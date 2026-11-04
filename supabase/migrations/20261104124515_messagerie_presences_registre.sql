-- À relire puis appliquer par le propriétaire, APRÈS 20261104120000.
-- Aucun appel à la production n'est nécessaire pour tester ce fichier.
-- Réexécutable : tables/politiques/déclencheurs/fonctions conservant les données.
BEGIN;

-- Réservation durable : aucune FK vers membres, même après suppression de la fiche.
CREATE TABLE IF NOT EXISTS app_private.numeros_reserves (
  numero text PRIMARY KEY,
  membre_id uuid NOT NULL,
  supprime_definitivement boolean NOT NULL DEFAULT false,
  reserve_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE app_private.numeros_reserves ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON app_private.numeros_reserves FROM PUBLIC, anon, authenticated;
INSERT INTO app_private.numeros_reserves (numero, membre_id)
SELECT numero_membre, id FROM public.membres WHERE numero_membre IS NOT NULL
ON CONFLICT (numero) DO NOTHING;

CREATE OR REPLACE FUNCTION app_private.prochain_numero()
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE n bigint; v_numero text;
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(8413001);
  LOOP
    n := pg_catalog.nextval('public.numero_membre_seq');
    -- lpad tronque au-delà de 999 : ne jamais raccourcir un numéro.
    v_numero := 'ACHUS-' || CASE WHEN n < 1000 THEN pg_catalog.lpad(n::text, 3, '0') ELSE n::text END;
    EXIT WHEN NOT EXISTS (SELECT 1 FROM app_private.numeros_reserves r WHERE r.numero = v_numero)
      AND NOT EXISTS (SELECT 1 FROM public.membres m WHERE m.numero_membre = v_numero);
  END LOOP;
  RETURN v_numero;
END $$;

CREATE OR REPLACE FUNCTION app_private.reserver_numero()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE proprietaire uuid; supprime boolean;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.numero_membre IS NOT NULL
     AND NEW.numero_membre IS DISTINCT FROM OLD.numero_membre THEN
    RAISE EXCEPTION 'Le numéro ACHUS attribué est définitif.' USING ERRCODE = '23514';
  END IF;
  IF NEW.numero_membre IS NOT NULL THEN
    INSERT INTO app_private.numeros_reserves (numero, membre_id)
    VALUES (NEW.numero_membre, NEW.id) ON CONFLICT (numero) DO NOTHING;
    SELECT membre_id, supprime_definitivement INTO proprietaire, supprime FROM app_private.numeros_reserves WHERE numero = NEW.numero_membre;
    IF proprietaire IS DISTINCT FROM NEW.id OR supprime THEN
      RAISE EXCEPTION 'Ce numéro ACHUS est déjà réservé, y compris après retrait.' USING ERRCODE = '23505';
    END IF;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS reserver_numero ON public.membres;
CREATE TRIGGER reserver_numero BEFORE INSERT OR UPDATE ON public.membres
FOR EACH ROW EXECUTE FUNCTION app_private.reserver_numero();

CREATE OR REPLACE FUNCTION public.est_president()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.membres WHERE user_id = auth.uid() AND role = 'president' AND statut = 'actif'
  );
$$;

-- Le bureau peut modifier grade/fonction ; les rôles sont réservés au président.
-- Tous les changements de statut passent par les RPC vérifiées.
CREATE OR REPLACE FUNCTION public.encadrer_gestion_membre()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF current_user IN ('postgres', 'supabase_admin', 'service_role', 'supabase_auth_admin') THEN RETURN NEW; END IF;
  IF NEW.id IS DISTINCT FROM OLD.id OR NEW.user_id IS DISTINCT FROM OLD.user_id
     OR NEW.numero_membre IS DISTINCT FROM OLD.numero_membre OR NEW.matricule IS DISTINCT FROM OLD.matricule
     OR NEW.statut IS DISTINCT FROM OLD.statut OR NEW.approuve IS DISTINCT FROM OLD.approuve
     OR NEW.approved_at IS DISTINCT FROM OLD.approved_at OR NEW.date_adhesion IS DISTINCT FROM OLD.date_adhesion
     OR NEW.points IS DISTINCT FROM OLD.points OR NEW.presences_count IS DISTINCT FROM OLD.presences_count
     OR NEW.type_compte IS DISTINCT FROM OLD.type_compte THEN
    RAISE EXCEPTION 'Utilisez les actions du registre pour changer le statut. Les identifiants sont protégés.' USING ERRCODE = '42501';
  END IF;
  IF NEW.role IS DISTINCT FROM OLD.role AND (NOT public.est_president() OR OLD.user_id = auth.uid()) THEN
    RAISE EXCEPTION 'Seul le président peut attribuer un rôle à un autre membre.' USING ERRCODE = '42501';
  END IF;
  IF OLD.role = 'president' AND NOT public.est_president() THEN
    RAISE EXCEPTION 'La fiche du président est protégée.' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS encadrer_gestion_membre ON public.membres;
CREATE TRIGGER encadrer_gestion_membre BEFORE UPDATE ON public.membres
FOR EACH ROW EXECUTE FUNCTION public.encadrer_gestion_membre();

CREATE TABLE IF NOT EXISTS public.historique_statuts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membre_id uuid REFERENCES public.membres(id) ON DELETE SET NULL,
  numero_membre text,
  ancien_statut text NOT NULL,
  nouveau_statut text NOT NULL,
  motif text NOT NULL CHECK (char_length(btrim(motif)) BETWEEN 3 AND 2000),
  date_effet date NOT NULL,
  acteur_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS historique_statuts_membre_idx ON public.historique_statuts(membre_id, created_at DESC);
CREATE TABLE IF NOT EXISTS public.journal_admin (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  acteur_id uuid,
  acteur_numero text,
  cible_id uuid,
  cible_numero text,
  action text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS journal_admin_date_idx ON public.journal_admin(created_at DESC, id);
ALTER TABLE public.historique_statuts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_admin ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS historique_statuts_lecture ON public.historique_statuts;
CREATE POLICY historique_statuts_lecture ON public.historique_statuts FOR SELECT TO authenticated
USING ((SELECT public.is_bureau()) OR membre_id = (SELECT public.current_membre_id()));
DROP POLICY IF EXISTS journal_admin_lecture ON public.journal_admin;
CREATE POLICY journal_admin_lecture ON public.journal_admin FOR SELECT TO authenticated USING ((SELECT public.is_bureau()));
REVOKE ALL ON public.historique_statuts, public.journal_admin FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.historique_statuts, public.journal_admin TO authenticated;

CREATE OR REPLACE FUNCTION app_private.journaliser_membre()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE acteur uuid; numero_acteur text;
BEGIN
  SELECT id, numero_membre INTO acteur, numero_acteur FROM public.membres WHERE user_id = auth.uid();
  IF TG_OP = 'DELETE' THEN
    UPDATE app_private.numeros_reserves SET supprime_definitivement = true WHERE numero = OLD.numero_membre;
    INSERT INTO public.journal_admin(acteur_id, acteur_numero, cible_id, cible_numero, action)
    VALUES (acteur, numero_acteur, OLD.id, OLD.numero_membre, 'suppression_membre');
    RETURN OLD;
  END IF;
  IF ROW(NEW.statut, NEW.role, NEW.grade, NEW.fonction, NEW.date_validite, NEW.numero_membre)
     IS DISTINCT FROM ROW(OLD.statut, OLD.role, OLD.grade, OLD.fonction, OLD.date_validite, OLD.numero_membre) THEN
    INSERT INTO public.journal_admin(acteur_id, acteur_numero, cible_id, cible_numero, action, details)
    VALUES (acteur, numero_acteur, NEW.id, NEW.numero_membre, 'modification_membre',
      jsonb_build_object('ancien_statut', OLD.statut, 'nouveau_statut', NEW.statut,
        'ancien_role', OLD.role, 'nouveau_role', NEW.role, 'grade', NEW.grade,
        'fonction', NEW.fonction, 'date_validite', NEW.date_validite));
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS journaliser_membre ON public.membres;
CREATE TRIGGER journaliser_membre AFTER UPDATE OR DELETE ON public.membres
FOR EACH ROW EXECUTE FUNCTION app_private.journaliser_membre();

CREATE OR REPLACE FUNCTION public.retirer_membre(p_id uuid, p_statut text, p_motif text, p_date date)
RETURNS public.membres LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE fiche public.membres;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_bureau() THEN
    RAISE EXCEPTION 'Seul le bureau peut retirer un membre.' USING ERRCODE = '42501';
  END IF;
  IF p_statut IS NULL OR p_statut NOT IN ('inactif', 'suspendu') OR p_motif IS NULL
     OR char_length(btrim(p_motif)) NOT BETWEEN 3 AND 2000 OR p_date IS NULL
     OR p_date > (now() AT TIME ZONE 'America/Port-au-Prince')::date THEN
    RAISE EXCEPTION 'Choisissez Inactif ou Suspendu, un motif de 3 à 2000 caractères et une date non future.' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO fiche FROM public.membres WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Membre introuvable.' USING ERRCODE = '22023'; END IF;
  IF fiche.role = 'president' OR fiche.user_id = auth.uid() THEN
    RAISE EXCEPTION 'Le président et votre propre fiche sont protégés du retrait.' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.historique_statuts(membre_id, numero_membre, ancien_statut, nouveau_statut, motif, date_effet, acteur_id)
  VALUES (fiche.id, fiche.numero_membre, fiche.statut, p_statut, btrim(p_motif), p_date, public.current_membre_id());
  UPDATE public.membres SET statut = p_statut, approuve = false WHERE id = p_id RETURNING * INTO fiche;
  RETURN fiche;
END $$;

-- Signature historique conservée pour les autres applications : le retrait exige désormais un motif.
CREATE OR REPLACE FUNCTION public.changer_statut(p_id uuid, p_statut text)
RETURNS public.membres LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE fiche public.membres; numero text; adhesion date;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_bureau() THEN
    RAISE EXCEPTION 'Seul le bureau peut changer un statut.' USING ERRCODE = '42501';
  END IF;
  IF p_statut IS NULL OR p_statut NOT IN ('en_attente', 'actif', 'honoraire', 'refuse') THEN
    RAISE EXCEPTION 'Pour un retrait ou une suspension, utilisez retirer_membre avec un motif et une date.' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO fiche FROM public.membres WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Membre introuvable.' USING ERRCODE = '22023'; END IF;
  IF fiche.role = 'president' AND p_statut <> 'actif' THEN
    RAISE EXCEPTION 'Le président doit rester actif.' USING ERRCODE = '42501';
  END IF;
  IF (fiche.numero_membre IS NOT NULL OR fiche.statut NOT IN ('en_attente', 'refuse')) AND p_statut IN ('en_attente', 'refuse') THEN
    RAISE EXCEPTION 'Un membre déjà admis doit être retiré avec un motif et une date.' USING ERRCODE = '22023';
  END IF;
  numero := fiche.numero_membre;
  adhesion := fiche.date_adhesion;
  IF p_statut IN ('actif', 'honoraire') THEN
    IF numero IS NULL THEN numero := app_private.prochain_numero(); END IF;
    adhesion := coalesce(adhesion, CURRENT_DATE);
  END IF;
  UPDATE public.membres SET statut = p_statut, approuve = (p_statut IN ('actif', 'honoraire')),
    numero_membre = numero, matricule = coalesce(numero, matricule), date_adhesion = adhesion,
    approved_at = CASE WHEN p_statut IN ('actif', 'honoraire') THEN coalesce(approved_at, now()) ELSE approved_at END,
    date_validite = CASE WHEN p_statut IN ('actif', 'honoraire') THEN coalesce(date_validite, (adhesion + INTERVAL '1 year')::date) ELSE date_validite END
  WHERE id = p_id RETURNING * INTO fiche;
  RETURN fiche;
END $$;

-- Évite qu'un ancien appel au refus désactive le président en contournant le registre.
CREATE OR REPLACE FUNCTION public.refuser_membre(p_id uuid)
RETURNS public.membres LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN RETURN public.changer_statut(p_id, 'refuse'); END $$;

CREATE TABLE IF NOT EXISTS public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expediteur uuid NOT NULL REFERENCES public.membres(id) ON DELETE CASCADE,
  destinataire uuid NOT NULL REFERENCES public.membres(id) ON DELETE CASCADE,
  contenu text NOT NULL CHECK (char_length(btrim(contenu)) BETWEEN 1 AND 5000),
  lu boolean NOT NULL DEFAULT false,
  date_envoi timestamptz NOT NULL DEFAULT now(),
  CHECK (expediteur <> destinataire)
);
CREATE INDEX IF NOT EXISTS messages_reception_idx ON public.messages(destinataire, date_envoi DESC, id);
CREATE INDEX IF NOT EXISTS messages_envois_idx ON public.messages(expediteur, date_envoi DESC, id);
CREATE INDEX IF NOT EXISTS messages_non_lus_idx ON public.messages(destinataire) WHERE NOT lu;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Annuaire minimal : ni e-mail, ni téléphone, ni profil complet exposé aux membres.
CREATE OR REPLACE FUNCTION public.contact_messagerie_actif(p_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT auth.uid() IS NOT NULL
    AND EXISTS (SELECT 1 FROM public.membres WHERE user_id = auth.uid() AND statut = 'actif')
    AND EXISTS (SELECT 1 FROM public.membres WHERE id = p_id AND statut = 'actif');
$$;
CREATE OR REPLACE FUNCTION public.contacts_messagerie()
RETURNS TABLE(id uuid, prenom text, nom text, numero_membre text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT m.id, m.prenom, m.nom, m.numero_membre FROM public.membres m
  WHERE auth.uid() IS NOT NULL
    AND EXISTS (SELECT 1 FROM public.membres soi WHERE soi.user_id = auth.uid() AND soi.statut = 'actif')
    AND m.statut = 'actif' AND m.user_id IS NOT NULL
  ORDER BY m.nom, m.prenom, m.id;
$$;
DROP POLICY IF EXISTS messages_lecture ON public.messages;
CREATE POLICY messages_lecture ON public.messages FOR SELECT TO authenticated
USING (public.contact_messagerie_actif((SELECT public.current_membre_id()))
  AND (expediteur = (SELECT public.current_membre_id()) OR destinataire = (SELECT public.current_membre_id())));
DROP POLICY IF EXISTS messages_envoi ON public.messages;
CREATE POLICY messages_envoi ON public.messages FOR INSERT TO authenticated
WITH CHECK (expediteur = (SELECT public.current_membre_id()) AND public.contact_messagerie_actif(destinataire));
DROP POLICY IF EXISTS messages_lu ON public.messages;
CREATE POLICY messages_lu ON public.messages FOR UPDATE TO authenticated
USING (destinataire = (SELECT public.current_membre_id()) AND public.contact_messagerie_actif(destinataire))
WITH CHECK (destinataire = (SELECT public.current_membre_id()) AND public.contact_messagerie_actif(destinataire) AND lu);
REVOKE ALL ON public.messages FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.messages TO authenticated;
GRANT INSERT(expediteur, destinataire, contenu) ON public.messages TO authenticated;
GRANT UPDATE(lu) ON public.messages TO authenticated;

-- Table séparée : les anciennes tables presence/presences restent intactes.
CREATE TABLE IF NOT EXISTS public.presences_evenements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membre_id uuid NOT NULL REFERENCES public.membres(id) ON DELETE CASCADE,
  evenement_id uuid NOT NULL REFERENCES public.evenements(id) ON DELETE RESTRICT,
  date_session date NOT NULL,
  statut text NOT NULL DEFAULT 'en_attente' CHECK (statut IN ('en_attente', 'approuvee', 'refusee')),
  motif_decision text,
  valide_par uuid REFERENCES public.membres(id) ON DELETE SET NULL,
  decide_le timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(membre_id, evenement_id, date_session),
  CHECK ((statut = 'en_attente' AND valide_par IS NULL AND decide_le IS NULL)
     OR (statut IN ('approuvee', 'refusee') AND decide_le IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS presences_evenements_reunion_idx ON public.presences_evenements(evenement_id, date_session, statut);
CREATE INDEX IF NOT EXISTS presences_evenements_validation_idx ON public.presences_evenements(valide_par);
ALTER TABLE public.presences_evenements ENABLE ROW LEVEL SECURITY;

-- Séances dans un intervalle de 366 jours maximum, dates civiles d'Haïti.
-- Une récurrence commence à la date_debut de l'événement, jamais avant.
CREATE OR REPLACE FUNCTION public.sessions_presence(p_debut date, p_fin date)
RETURNS TABLE(evenement_id uuid, titre text, date_session date)
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  IF p_debut IS NULL OR p_fin IS NULL OR p_fin < p_debut OR p_fin - p_debut > 365 THEN
    RAISE EXCEPTION 'Choisissez une période de 366 jours maximum.' USING ERRCODE = '22023';
  END IF;
  RETURN QUERY
    SELECT e.id, e.titre, j::date FROM public.evenements e
    CROSS JOIN pg_catalog.generate_series(p_debut::timestamp, p_fin::timestamp, INTERVAL '1 day') j
    WHERE e.date_debut IS NOT NULL AND j::date >= (e.date_debut AT TIME ZONE 'America/Port-au-Prince')::date
      AND (CASE e.recurrence
        WHEN 'hebdomadaire:samedi:09:00' THEN EXTRACT(DOW FROM j) = 6
        WHEN 'annuelle:05-18' THEN to_char(j, 'MM-DD') = '05-18'
        ELSE j::date = (e.date_debut AT TIME ZONE 'America/Port-au-Prince')::date END)
    ORDER BY j, e.titre, e.id;
END $$;

CREATE OR REPLACE FUNCTION public.verifier_declaration_presence()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  IF NEW.membre_id IS DISTINCT FROM public.current_membre_id() THEN
    RAISE EXCEPTION 'Vous ne pouvez déclarer que votre propre présence.' USING ERRCODE = '42501';
  END IF;
  IF NEW.date_session > (now() AT TIME ZONE 'America/Port-au-Prince')::date
    OR NOT EXISTS (SELECT 1 FROM public.sessions_presence(NEW.date_session, NEW.date_session) s WHERE s.evenement_id = NEW.evenement_id)
    OR NOT EXISTS (SELECT 1 FROM public.membres m WHERE m.id = NEW.membre_id
      AND m.statut IN ('actif', 'honoraire') AND m.date_adhesion <= NEW.date_session) THEN
    RAISE EXCEPTION 'Cette séance est future, invalide ou antérieure à votre adhésion.' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS verifier_declaration_presence ON public.presences_evenements;
CREATE TRIGGER verifier_declaration_presence BEFORE INSERT ON public.presences_evenements
FOR EACH ROW EXECUTE FUNCTION public.verifier_declaration_presence();
DROP POLICY IF EXISTS presences_evenements_lecture ON public.presences_evenements;
CREATE POLICY presences_evenements_lecture ON public.presences_evenements FOR SELECT TO authenticated
USING (membre_id = (SELECT public.current_membre_id()) OR (SELECT public.is_bureau()));
DROP POLICY IF EXISTS presences_evenements_declaration ON public.presences_evenements;
CREATE POLICY presences_evenements_declaration ON public.presences_evenements FOR INSERT TO authenticated
WITH CHECK ((SELECT public.is_membre_actif()) AND membre_id = (SELECT public.current_membre_id())
  AND statut = 'en_attente' AND valide_par IS NULL AND decide_le IS NULL AND motif_decision IS NULL);
REVOKE ALL ON public.presences_evenements FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.presences_evenements TO authenticated;
GRANT INSERT(membre_id, evenement_id, date_session) ON public.presences_evenements TO authenticated;

CREATE OR REPLACE FUNCTION public.decider_presence(p_id uuid, p_statut text, p_motif text DEFAULT '')
RETURNS public.presences_evenements LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE presence public.presences_evenements; acteur public.membres;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_bureau() THEN
    RAISE EXCEPTION 'Seul le bureau peut valider une présence.' USING ERRCODE = '42501';
  END IF;
  IF p_statut IS NULL OR p_statut NOT IN ('approuvee', 'refusee') OR p_motif IS NULL
    OR char_length(p_motif) > 2000 OR (p_statut = 'refusee' AND char_length(btrim(p_motif)) < 3) THEN
    RAISE EXCEPTION 'Décision invalide : un refus exige un motif de 3 à 2000 caractères.' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO acteur FROM public.membres WHERE user_id = auth.uid();
  SELECT * INTO presence FROM public.presences_evenements WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Présence introuvable.' USING ERRCODE = '22023'; END IF;
  IF presence.membre_id = acteur.id THEN
    RAISE EXCEPTION 'Un autre responsable doit valider votre présence.' USING ERRCODE = '42501';
  END IF;
  IF presence.statut <> 'en_attente' THEN
    RAISE EXCEPTION 'Cette présence a déjà reçu une décision. Actualisez le tableau.' USING ERRCODE = '22023';
  END IF;
  UPDATE public.presences_evenements SET statut = p_statut, motif_decision = nullif(btrim(p_motif), ''),
    valide_par = acteur.id, decide_le = now() WHERE id = p_id RETURNING * INTO presence;
  INSERT INTO public.journal_admin(acteur_id, acteur_numero, cible_id, cible_numero, action, details)
  SELECT acteur.id, acteur.numero_membre, m.id, m.numero_membre, 'decision_presence',
    jsonb_build_object('presence_id', presence.id, 'evenement_id', presence.evenement_id,
      'date_session', presence.date_session, 'statut', p_statut)
  FROM public.membres m WHERE m.id = presence.membre_id;
  RETURN presence;
END $$;

CREATE OR REPLACE FUNCTION public.statistiques_presences(p_debut date, p_fin date)
RETURNS TABLE(membre_id uuid, numero_membre text, prenom text, nom text, seances bigint, approuvees bigint, en_attente bigint, refusees bigint, taux numeric)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$
  WITH seances AS (SELECT * FROM public.sessions_presence(p_debut, least(p_fin, (now() AT TIME ZONE 'America/Port-au-Prince')::date))),
  compte AS (
    SELECT m.id, m.numero_membre, m.prenom, m.nom, count(s.evenement_id) AS total,
      count(p.id) FILTER (WHERE p.statut = 'approuvee') AS ok,
      count(p.id) FILTER (WHERE p.statut = 'en_attente') AS attente,
      count(p.id) FILTER (WHERE p.statut = 'refusee') AS refus
    FROM public.membres m LEFT JOIN seances s ON s.date_session >= m.date_adhesion
    LEFT JOIN public.presences_evenements p ON p.membre_id = m.id AND p.evenement_id = s.evenement_id AND p.date_session = s.date_session
    WHERE public.is_bureau() AND m.date_adhesion IS NOT NULL
    GROUP BY m.id
  ) SELECT id, numero_membre, prenom, nom, total, ok, attente, refus,
    CASE WHEN total = 0 THEN NULL ELSE round(100.0 * ok / total, 1) END FROM compte ORDER BY nom, prenom;
$$;

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
  -- Les tables historiques n'avaient pas toutes de FK ; nettoyage ciblé.
  DELETE FROM public.presence WHERE membre_id = fiche.id;
  DELETE FROM public.presences WHERE membre_id = fiche.id;
  DELETE FROM public.quiz_resultats WHERE membre_id = fiche.id OR membre_id = fiche.user_id;
  DELETE FROM public.vote_reponses WHERE membre_id = fiche.id OR membre_id = fiche.user_id;
  DELETE FROM public.membres WHERE id = fiche.id;
  -- auth.users est conservé : le compte n'a plus de fiche ni d'accès aux membres.
  -- Les réservations de numéro et les traces administratives restent conservées.
END $$;

-- Aucun nouveau privilège implicite sur les fonctions ou sur le schéma privé.
REVOKE ALL ON FUNCTION app_private.reserver_numero(), app_private.prochain_numero(), app_private.journaliser_membre() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.encadrer_gestion_membre(), public.verifier_declaration_presence() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.est_president(), public.retirer_membre(uuid,text,text,date),
  public.changer_statut(uuid,text), public.refuser_membre(uuid), public.contact_messagerie_actif(uuid),
  public.contacts_messagerie(), public.sessions_presence(date,date), public.decider_presence(uuid,text,text),
  public.statistiques_presences(date,date), public.supprimer_membre(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.est_president(), public.retirer_membre(uuid,text,text,date),
  public.changer_statut(uuid,text), public.refuser_membre(uuid), public.contact_messagerie_actif(uuid),
  public.contacts_messagerie(), public.sessions_presence(date,date), public.decider_presence(uuid,text,text),
  public.statistiques_presences(date,date), public.supprimer_membre(uuid,text,text) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
