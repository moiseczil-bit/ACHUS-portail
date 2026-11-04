-- ACHUS — refonte du portail (adhésion, rôles, RLS, numéros, agenda, photos)
-- À appliquer UNE FOIS par le propriétaire, dans l’éditeur SQL Supabase (rôle postgres).
-- Le fichier est déjà dans une transaction. Ne pas l’envelopper une seconde fois.
--
-- SÛRETÉ (base déjà en service : 2 fiches membres, 5 comptes auth) :
--   * aucune ligne de public.membres n’est supprimée ;
--   * aucune ligne de auth.users n’est supprimée ni modifiée
--     (le déclencheur ne concerne que les futurs INSERT) ;
--   * pas de TRUNCATE, pas de DROP TABLE sur les tables existantes ;
--   * le président existant (type_compte = admin, ou e-mail correspondant) reçoit ACHUS-001.

BEGIN;

ALTER TABLE public.membres DROP CONSTRAINT IF EXISTS membres_id_fkey;

-- ---------------------------------------------------------------------------
-- Schéma privé : numérotation (non exposée à l’API REST)
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS app_private;
REVOKE ALL ON SCHEMA app_private FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- Colonnes membres
-- ---------------------------------------------------------------------------
ALTER TABLE public.membres ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.membres ALTER COLUMN prenom SET DEFAULT '';
ALTER TABLE public.membres ALTER COLUMN nom SET DEFAULT '';
ALTER TABLE public.membres ALTER COLUMN statut SET DEFAULT 'en_attente';
ALTER TABLE public.membres ALTER COLUMN grade SET DEFAULT 'Soldat de l''Honneur';

ALTER TABLE public.membres ADD COLUMN IF NOT EXISTS quartier text;
ALTER TABLE public.membres ADD COLUMN IF NOT EXISTS programme_interet text;
ALTER TABLE public.membres ADD COLUMN IF NOT EXISTS motivation text;
ALTER TABLE public.membres ADD COLUMN IF NOT EXISTS numero_membre text;
ALTER TABLE public.membres ADD COLUMN IF NOT EXISTS date_adhesion date;
ALTER TABLE public.membres ADD COLUMN IF NOT EXISTS date_validite date;

-- grade est du texte : un ancien essai du portail écrivait 0, 1, 2…
UPDATE public.membres
SET grade = 'Soldat de l''Honneur'
WHERE grade IS NULL
   OR btrim(grade) = ''
   OR grade ~ '^[0-9]+$';

UPDATE public.membres
SET fonction = 'Membre'
WHERE fonction IS NULL OR btrim(fonction) = '';

-- Statuts historiques → liste fermée. « approuve » devient « actif ».
UPDATE public.membres
SET statut = CASE lower(btrim(coalesce(statut, '')))
  WHEN 'approuve' THEN 'actif'
  WHEN 'approuvé' THEN 'actif'
  WHEN 'approved' THEN 'actif'
  WHEN 'active' THEN 'actif'
  WHEN 'actif' THEN 'actif'
  WHEN 'en_attente' THEN 'en_attente'
  WHEN 'en attente' THEN 'en_attente'
  WHEN 'pending' THEN 'en_attente'
  WHEN 'inactif' THEN 'inactif'
  WHEN 'inactive' THEN 'inactif'
  WHEN 'suspendu' THEN 'suspendu'
  WHEN 'suspended' THEN 'suspendu'
  WHEN 'honoraire' THEN 'honoraire'
  WHEN 'refuse' THEN 'refuse'
  WHEN 'refusé' THEN 'refuse'
  WHEN 'rejected' THEN 'refuse'
  ELSE 'actif'
END;

-- Rôles : uniquement president / bureau / membre.
-- L’admin historique (type_compte = admin) devient président.
UPDATE public.membres
SET role = CASE
  WHEN lower(btrim(coalesce(type_compte, ''))) = 'admin' THEN 'president'
  WHEN lower(btrim(coalesce(role, ''))) IN ('president', 'bureau', 'membre') THEN lower(btrim(role))
  ELSE 'membre'
END;

UPDATE public.membres
SET approuve = (statut IN ('actif', 'honoraire'))
WHERE approuve IS DISTINCT FROM (statut IN ('actif', 'honoraire'));

-- user_id texte → uuid. Les valeurs illisibles deviennent NULL (la fiche reste).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'membres'
      AND column_name = 'user_id'
      AND udt_name <> 'uuid'
  ) THEN
    ALTER TABLE public.membres
      ALTER COLUMN user_id TYPE uuid
      USING (
        CASE
          WHEN btrim(coalesce(user_id::text, '')) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            THEN btrim(user_id::text)::uuid
          ELSE NULL
        END
      );
  END IF;
END $$;

-- Oublier les user_id qui ne pointent vers aucun compte (évite l’échec de la clé étrangère).
UPDATE public.membres m
SET user_id = NULL
WHERE m.user_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = m.user_id);

-- Rattacher les fiches (dont l’admin) par e-mail, sans écraser un lien déjà bon,
-- et sans donner le même user_id à deux fiches.
UPDATE public.membres m
SET user_id = sub.uid
FROM (
  SELECT DISTINCT ON (u.id)
    m2.id AS mid,
    u.id AS uid
  FROM public.membres m2
  JOIN auth.users u
    ON lower(btrim(m2.email)) = lower(btrim(u.email))
  WHERE m2.user_id IS NULL
    AND m2.email IS NOT NULL
    AND btrim(m2.email) <> ''
    AND NOT EXISTS (
      SELECT 1 FROM public.membres deja WHERE deja.user_id = u.id
    )
  ORDER BY u.id, (lower(btrim(coalesce(m2.type_compte, ''))) = 'admin') DESC, m2.created_at NULLS LAST
) sub
WHERE m.id = sub.mid
  AND m.user_id IS NULL;

ALTER TABLE public.membres DROP CONSTRAINT IF EXISTS membres_user_id_fkey;
ALTER TABLE public.membres
  ADD CONSTRAINT membres_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE SET NULL;

DROP INDEX IF EXISTS public.membres_user_id_key;
CREATE UNIQUE INDEX membres_user_id_key ON public.membres (user_id);

DROP INDEX IF EXISTS public.membres_numero_membre_key;
CREATE UNIQUE INDEX membres_numero_membre_key ON public.membres (numero_membre);

ALTER TABLE public.membres DROP CONSTRAINT IF EXISTS membres_statut_check;
ALTER TABLE public.membres
  ADD CONSTRAINT membres_statut_check
  CHECK (statut IN ('en_attente', 'actif', 'inactif', 'suspendu', 'honoraire', 'refuse'));

ALTER TABLE public.membres DROP CONSTRAINT IF EXISTS membres_role_check;
ALTER TABLE public.membres
  ADD CONSTRAINT membres_role_check
  CHECK (role IN ('president', 'bureau', 'membre'));

-- Président historique = ACHUS-001. Les autres fiches déjà présentes ne reçoivent pas de numéro ici
-- (le bureau les attribue avec approuver_membre / changer_statut, à partir de ACHUS-002).
UPDATE public.membres m
SET
  numero_membre = 'ACHUS-001',
  statut = 'actif',
  approuve = true,
  date_adhesion = COALESCE(m.date_adhesion, COALESCE(m.approved_at::date, m.created_at::date, CURRENT_DATE)),
  date_validite = COALESCE(
    m.date_validite,
    GREATEST(
      (COALESCE(m.date_adhesion, COALESCE(m.approved_at::date, m.created_at::date, CURRENT_DATE)) + INTERVAL '1 year')::date,
      (CURRENT_DATE + INTERVAL '1 year')::date
    )
  )
WHERE m.id = (
  SELECT p.id
  FROM public.membres p
  WHERE p.role = 'president'
  ORDER BY (p.user_id IS NOT NULL) DESC, p.created_at NULLS LAST
  LIMIT 1
)
AND (m.numero_membre IS NULL OR m.numero_membre = 'ACHUS-001')
AND NOT EXISTS (
  SELECT 1 FROM public.membres autre
  WHERE autre.numero_membre = 'ACHUS-001' AND autre.id <> m.id
);

-- Comptes déjà créés dont la fiche avait été refusée en silence : on crée la demande
-- « en attente » sans toucher aux fiches existantes (même e-mail ou même user_id).
INSERT INTO public.membres (
  user_id, email, prenom, nom, telephone, quartier, programme_interet, motivation,
  statut, role, type_compte, grade, fonction, localite
)
SELECT
  u.id,
  u.email,
  COALESCE(NULLIF(btrim(u.raw_user_meta_data->>'prenom'), ''), '—'),
  COALESCE(NULLIF(btrim(u.raw_user_meta_data->>'nom'), ''), '—'),
  NULLIF(btrim(u.raw_user_meta_data->>'telephone'), ''),
  NULLIF(btrim(u.raw_user_meta_data->>'quartier'), ''),
  NULLIF(btrim(u.raw_user_meta_data->>'programme_interet'), ''),
  NULLIF(btrim(u.raw_user_meta_data->>'motivation'), ''),
  'en_attente',
  'membre',
  CASE WHEN u.raw_user_meta_data->>'type_compte' = 'parent' THEN 'parent' ELSE 'membre' END,
  'Soldat de l''Honneur',
  'Membre',
  COALESCE(NULLIF(btrim(u.raw_user_meta_data->>'quartier'), ''), 'Santo 13')
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.membres m WHERE m.user_id = u.id)
  AND NOT EXISTS (
    SELECT 1 FROM public.membres m
    WHERE m.email IS NOT NULL
      AND lower(btrim(m.email)) = lower(btrim(u.email))
  );

CREATE SEQUENCE IF NOT EXISTS public.numero_membre_seq AS integer;

SELECT setval(
  'public.numero_membre_seq',
  GREATEST(
    COALESCE((
      SELECT MAX((substring(numero_membre FROM 7))::integer)
      FROM public.membres
      WHERE numero_membre ~ '^ACHUS-[0-9]+$'
    ), 1),
    1
  ),
  true
);

-- ---------------------------------------------------------------------------
-- Agenda
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.evenements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  titre text NOT NULL,
  description text,
  date_debut timestamptz,
  lieu text,
  recurrence text,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.evenements (titre, description, date_debut, lieu, recurrence)
SELECT
  'Fête du Drapeau',
  'Célébration annuelle de la Fête du Drapeau.',
  (
    (
      CASE
        WHEN make_date(EXTRACT(YEAR FROM CURRENT_DATE)::int, 5, 18) >= CURRENT_DATE
          THEN make_date(EXTRACT(YEAR FROM CURRENT_DATE)::int, 5, 18)
        ELSE make_date(EXTRACT(YEAR FROM CURRENT_DATE)::int + 1, 5, 18)
      END
    )::timestamp + TIME '09:00'
  ) AT TIME ZONE 'America/Port-au-Prince',
  'Santo 13, Croix-des-Bouquets, Haïti',
  'annuelle:05-18'
WHERE NOT EXISTS (SELECT 1 FROM public.evenements WHERE titre = 'Fête du Drapeau');

INSERT INTO public.evenements (titre, description, date_debut, lieu, recurrence)
SELECT
  'Réunion hebdomadaire',
  'Réunion des membres, chaque samedi à 9 h.',
  (
    (
      CURRENT_DATE
      + ((6 - EXTRACT(DOW FROM CURRENT_DATE)::int + 7) % 7)
    )::timestamp + TIME '09:00'
  ) AT TIME ZONE 'America/Port-au-Prince',
  'Santo 13, Croix-des-Bouquets, Haïti',
  'hebdomadaire:samedi:09:00'
WHERE NOT EXISTS (SELECT 1 FROM public.evenements WHERE titre = 'Réunion hebdomadaire');

-- ---------------------------------------------------------------------------
-- Fonctions (search_path figé)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_bureau()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.membres m
    WHERE m.user_id = auth.uid()
      AND m.role IN ('president', 'bureau')
      AND m.statut = 'actif'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_membre_actif()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.membres m
    WHERE m.user_id = auth.uid()
      AND m.statut IN ('actif', 'honoraire')
  );
$$;

CREATE OR REPLACE FUNCTION public.current_membre_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT m.id
  FROM public.membres m
  WHERE m.user_id = auth.uid()
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION app_private.prochain_numero()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_n bigint;
  v_num text;
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(8413001);
  LOOP
    v_n := pg_catalog.nextval('public.numero_membre_seq');
    v_num := 'ACHUS-' || pg_catalog.lpad(v_n::text, 3, '0');
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.membres WHERE numero_membre = v_num
    );
  END LOOP;
  RETURN v_num;
END;
$$;

CREATE OR REPLACE FUNCTION public.approuver_membre(p_id uuid)
RETURNS public.membres
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_row public.membres;
  v_num text;
  v_adhesion date;
BEGIN
  IF NOT public.is_bureau() THEN
    RAISE EXCEPTION 'Seul le bureau peut approuver un membre.'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_row FROM public.membres WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Membre introuvable.';
  END IF;

  IF v_row.numero_membre IS NULL OR v_row.numero_membre !~ '^ACHUS-[0-9]+$' THEN
    v_num := app_private.prochain_numero();
  ELSE
    v_num := v_row.numero_membre;
  END IF;

  v_adhesion := COALESCE(v_row.date_adhesion, CURRENT_DATE);

  UPDATE public.membres
  SET
    statut = 'actif',
    approuve = true,
    approved_at = COALESCE(approved_at, pg_catalog.now()),
    date_adhesion = v_adhesion,
    date_validite = (v_adhesion + INTERVAL '1 year')::date,
    numero_membre = v_num,
    matricule = v_num
  WHERE id = p_id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.refuser_membre(p_id uuid)
RETURNS public.membres
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_row public.membres;
BEGIN
  IF NOT public.is_bureau() THEN
    RAISE EXCEPTION 'Seul le bureau peut refuser un membre.'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.membres
  SET statut = 'refuse', approuve = false
  WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Membre introuvable.';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.changer_statut(p_id uuid, p_statut text)
RETURNS public.membres
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_row public.membres;
  v_num text;
  v_adhesion date;
BEGIN
  IF NOT public.is_bureau() THEN
    RAISE EXCEPTION 'Seul le bureau peut changer un statut.'
      USING ERRCODE = '42501';
  END IF;

  IF p_statut NOT IN ('en_attente', 'actif', 'inactif', 'suspendu', 'honoraire', 'refuse') THEN
    RAISE EXCEPTION 'Statut invalide.';
  END IF;

  SELECT * INTO v_row FROM public.membres WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Membre introuvable.';
  END IF;

  v_num := v_row.numero_membre;
  v_adhesion := v_row.date_adhesion;

  IF p_statut IN ('actif', 'honoraire') AND (v_num IS NULL OR v_num !~ '^ACHUS-[0-9]+$') THEN
    v_num := app_private.prochain_numero();
    v_adhesion := COALESCE(v_adhesion, CURRENT_DATE);
  END IF;

  UPDATE public.membres
  SET
    statut = p_statut,
    approuve = (p_statut IN ('actif', 'honoraire')),
    approved_at = CASE
      WHEN p_statut IN ('actif', 'honoraire') THEN COALESCE(approved_at, pg_catalog.now())
      ELSE approved_at
    END,
    date_adhesion = v_adhesion,
    date_validite = CASE
      WHEN p_statut IN ('actif', 'honoraire') AND v_adhesion IS NOT NULL
        THEN (v_adhesion + INTERVAL '1 year')::date
      ELSE date_validite
    END,
    numero_membre = v_num,
    matricule = COALESCE(v_num, matricule)
  WHERE id = p_id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

-- Garde-fou : un membre ne peut pas changer son rôle, son statut, son numéro,
-- son grade, sa fonction ni les dates. Le bureau (et les fonctions ci-dessus,
-- qui s’exécutent en tant que propriétaire) le peut.
CREATE OR REPLACE FUNCTION public.proteger_champs_membre()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF current_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin', 'service_role')
     OR public.is_bureau() THEN
    RETURN NEW;
  END IF;

  IF NEW.role IS DISTINCT FROM OLD.role
     OR NEW.statut IS DISTINCT FROM OLD.statut
     OR NEW.numero_membre IS DISTINCT FROM OLD.numero_membre
     OR NEW.grade IS DISTINCT FROM OLD.grade
     OR NEW.fonction IS DISTINCT FROM OLD.fonction
     OR NEW.date_adhesion IS DISTINCT FROM OLD.date_adhesion
     OR NEW.date_validite IS DISTINCT FROM OLD.date_validite
     OR NEW.approved_at IS DISTINCT FROM OLD.approved_at
     OR NEW.matricule IS DISTINCT FROM OLD.matricule
     OR NEW.approuve IS DISTINCT FROM OLD.approuve
     OR NEW.type_compte IS DISTINCT FROM OLD.type_compte
     OR NEW.user_id IS DISTINCT FROM OLD.user_id
     OR NEW.points IS DISTINCT FROM OLD.points
     OR NEW.presences_count IS DISTINCT FROM OLD.presences_count
     OR NEW.id IS DISTINCT FROM OLD.id
  THEN
    RAISE EXCEPTION 'Vous ne pouvez pas modifier le rôle, le statut, le numéro, le grade ou la fonction.'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS proteger_champs_membre ON public.membres;
CREATE TRIGGER proteger_champs_membre
  BEFORE UPDATE ON public.membres
  FOR EACH ROW
  EXECUTE FUNCTION public.proteger_champs_membre();

-- Fiche « en attente » dès la création du compte, même sans session
-- (confirmation d’e-mail). Les données viennent de signUp options.data.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  meta jsonb;
  v_type text;
BEGIN
  meta := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
  IF meta->>'type_compte' = 'parent' THEN
    v_type := 'parent';
  ELSE
    v_type := 'membre';
  END IF;

  INSERT INTO public.membres (
    user_id, email, prenom, nom, telephone, quartier,
    programme_interet, motivation, statut, role, type_compte,
    grade, fonction, localite
  ) VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NULLIF(btrim(meta->>'prenom'), ''), '—'),
    COALESCE(NULLIF(btrim(meta->>'nom'), ''), '—'),
    NULLIF(btrim(meta->>'telephone'), ''),
    NULLIF(btrim(meta->>'quartier'), ''),
    NULLIF(btrim(meta->>'programme_interet'), ''),
    NULLIF(btrim(meta->>'motivation'), ''),
    'en_attente',
    'membre',
    v_type,
    'Soldat de l''Honneur',
    'Membre',
    COALESCE(NULLIF(btrim(meta->>'quartier'), ''), 'Santo 13')
  )
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Keep-alive : lecture sans table, autorisée pour la clé anon.
CREATE OR REPLACE FUNCTION public.ping()
RETURNS timestamptz
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT pg_catalog.now();
$$;

-- ---------------------------------------------------------------------------
-- RLS stricte — suppression de toutes les politiques permissives
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT policyname, tablename
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = ANY (ARRAY[
        'membres', 'presence', 'presences', 'photos',
        'quiz_questions', 'quiz_resultats', 'votes', 'vote_reponses',
        'annonces', 'live_sessions', 'evenements'
      ])
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

ALTER TABLE public.membres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.presence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.presences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_resultats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vote_reponses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.annonces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evenements ENABLE ROW LEVEL SECURITY;

CREATE POLICY membres_select ON public.membres
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_bureau());

CREATE POLICY membres_update ON public.membres
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() OR public.is_bureau())
  WITH CHECK (user_id = auth.uid() OR public.is_bureau());

CREATE POLICY annonces_select ON public.annonces
  FOR SELECT TO authenticated
  USING (public.is_membre_actif() OR public.is_bureau());
CREATE POLICY annonces_write ON public.annonces
  FOR INSERT TO authenticated
  WITH CHECK (public.is_bureau());
CREATE POLICY annonces_update ON public.annonces
  FOR UPDATE TO authenticated
  USING (public.is_bureau())
  WITH CHECK (public.is_bureau());
CREATE POLICY annonces_delete ON public.annonces
  FOR DELETE TO authenticated
  USING (public.is_bureau());

CREATE POLICY evenements_select ON public.evenements
  FOR SELECT TO authenticated
  USING (public.is_membre_actif() OR public.is_bureau());
CREATE POLICY evenements_insert ON public.evenements
  FOR INSERT TO authenticated
  WITH CHECK (public.is_bureau());
CREATE POLICY evenements_update ON public.evenements
  FOR UPDATE TO authenticated
  USING (public.is_bureau())
  WITH CHECK (public.is_bureau());
CREATE POLICY evenements_delete ON public.evenements
  FOR DELETE TO authenticated
  USING (public.is_bureau());

CREATE POLICY presence_select ON public.presence
  FOR SELECT TO authenticated
  USING (membre_id = public.current_membre_id() OR public.is_bureau());
CREATE POLICY presence_insert ON public.presence
  FOR INSERT TO authenticated
  WITH CHECK (membre_id = public.current_membre_id() OR public.is_bureau());
CREATE POLICY presence_update ON public.presence
  FOR UPDATE TO authenticated
  USING (public.is_bureau())
  WITH CHECK (public.is_bureau());
CREATE POLICY presence_delete ON public.presence
  FOR DELETE TO authenticated
  USING (public.is_bureau());

CREATE POLICY presences_select ON public.presences
  FOR SELECT TO authenticated
  USING (membre_id = public.current_membre_id() OR public.is_bureau());
CREATE POLICY presences_insert ON public.presences
  FOR INSERT TO authenticated
  WITH CHECK (membre_id = public.current_membre_id() OR public.is_bureau());
CREATE POLICY presences_update ON public.presences
  FOR UPDATE TO authenticated
  USING (public.is_bureau())
  WITH CHECK (public.is_bureau());
CREATE POLICY presences_delete ON public.presences
  FOR DELETE TO authenticated
  USING (public.is_bureau());

CREATE POLICY photos_select ON public.photos
  FOR SELECT TO authenticated
  USING (
    public.is_membre_actif()
    OR public.is_bureau()
    OR uploade_par::text = auth.uid()::text
  );
CREATE POLICY photos_insert ON public.photos
  FOR INSERT TO authenticated
  WITH CHECK (public.is_bureau() OR uploade_par::text = auth.uid()::text);
CREATE POLICY photos_update ON public.photos
  FOR UPDATE TO authenticated
  USING (public.is_bureau())
  WITH CHECK (public.is_bureau());
CREATE POLICY photos_delete ON public.photos
  FOR DELETE TO authenticated
  USING (public.is_bureau());

CREATE POLICY quiz_questions_select ON public.quiz_questions
  FOR SELECT TO authenticated
  USING (public.is_membre_actif() OR public.is_bureau());
CREATE POLICY quiz_questions_write ON public.quiz_questions
  FOR ALL TO authenticated
  USING (public.is_bureau())
  WITH CHECK (public.is_bureau());

CREATE POLICY quiz_resultats_select ON public.quiz_resultats
  FOR SELECT TO authenticated
  USING (
    public.is_bureau()
    OR membre_id = auth.uid()
    OR membre_id = public.current_membre_id()
  );
CREATE POLICY quiz_resultats_insert ON public.quiz_resultats
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_bureau()
    OR membre_id = auth.uid()
    OR membre_id = public.current_membre_id()
  );
CREATE POLICY quiz_resultats_update ON public.quiz_resultats
  FOR UPDATE TO authenticated
  USING (public.is_bureau())
  WITH CHECK (public.is_bureau());

CREATE POLICY votes_select ON public.votes
  FOR SELECT TO authenticated
  USING (public.is_membre_actif() OR public.is_bureau());
CREATE POLICY votes_write ON public.votes
  FOR ALL TO authenticated
  USING (public.is_bureau())
  WITH CHECK (public.is_bureau());

CREATE POLICY vote_reponses_select ON public.vote_reponses
  FOR SELECT TO authenticated
  USING (
    public.is_bureau()
    OR membre_id = auth.uid()
    OR membre_id = public.current_membre_id()
  );
CREATE POLICY vote_reponses_insert ON public.vote_reponses
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_bureau()
    OR membre_id = auth.uid()
    OR membre_id = public.current_membre_id()
  );

CREATE POLICY live_select ON public.live_sessions
  FOR SELECT TO authenticated
  USING (public.is_membre_actif() OR public.is_bureau());
CREATE POLICY live_write ON public.live_sessions
  FOR ALL TO authenticated
  USING (public.is_bureau())
  WITH CHECK (public.is_bureau());

-- ---------------------------------------------------------------------------
-- Droits : anon n’a plus aucun accès aux tables.
-- ---------------------------------------------------------------------------
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, anon;
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon, authenticated;

GRANT SELECT, UPDATE ON public.membres TO authenticated;
REVOKE INSERT, DELETE ON public.membres FROM authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.annonces TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.evenements TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.presence TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.presences TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.photos TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.quiz_questions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.quiz_resultats TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.votes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vote_reponses TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.live_sessions TO authenticated;

REVOKE ALL ON FUNCTION public.is_bureau() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_membre_actif() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_membre_id() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.approuver_membre(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.refuser_membre(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.changer_statut(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.proteger_champs_membre() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.ping() FROM PUBLIC;
REVOKE ALL ON FUNCTION app_private.prochain_numero() FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.is_bureau() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_membre_actif() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_membre_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.approuver_membre(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refuser_membre(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.changer_statut(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ping() TO anon, authenticated;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin';
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Stockage privé des photos (bucket + politiques). Ignoré si Storage est absent.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF to_regclass('storage.buckets') IS NULL OR to_regclass('storage.objects') IS NULL THEN
    RAISE NOTICE 'Schéma storage absent : bucket photos-membres non créé (normal hors Supabase).';
    RETURN;
  END IF;

  INSERT INTO storage.buckets (id, name, public)
  VALUES ('photos-membres', 'photos-membres', false)
  ON CONFLICT (id) DO UPDATE SET public = false, name = EXCLUDED.name;

  EXECUTE 'DROP POLICY IF EXISTS photos_membres_select ON storage.objects';
  EXECUTE 'DROP POLICY IF EXISTS photos_membres_insert ON storage.objects';
  EXECUTE 'DROP POLICY IF EXISTS photos_membres_update ON storage.objects';
  EXECUTE 'DROP POLICY IF EXISTS photos_membres_delete ON storage.objects';

  EXECUTE $pol$
    CREATE POLICY photos_membres_select ON storage.objects
      FOR SELECT TO authenticated
      USING (
        bucket_id = 'photos-membres'
        AND (
          public.is_bureau()
          OR (storage.foldername(name))[1] = auth.uid()::text
        )
      )
  $pol$;

  EXECUTE $pol$
    CREATE POLICY photos_membres_insert ON storage.objects
      FOR INSERT TO authenticated
      WITH CHECK (
        bucket_id = 'photos-membres'
        AND (storage.foldername(name))[1] = auth.uid()::text
      )
  $pol$;

  EXECUTE $pol$
    CREATE POLICY photos_membres_update ON storage.objects
      FOR UPDATE TO authenticated
      USING (
        bucket_id = 'photos-membres'
        AND (storage.foldername(name))[1] = auth.uid()::text
      )
      WITH CHECK (
        bucket_id = 'photos-membres'
        AND (storage.foldername(name))[1] = auth.uid()::text
      )
  $pol$;

  EXECUTE $pol$
    CREATE POLICY photos_membres_delete ON storage.objects
      FOR DELETE TO authenticated
      USING (
        bucket_id = 'photos-membres'
        AND (storage.foldername(name))[1] = auth.uid()::text
      )
  $pol$;
END $$;

COMMIT;
