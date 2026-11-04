-- Instantané minimal du schéma LIVE décrit par l’audit (4 nov. 2026).
-- Sert uniquement aux tests locaux. Ne pas appliquer sur Supabase.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN NOINHERIT;
  END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS auth;
-- Droit standard Supabase : les déclencheurs invoker peuvent appeler auth.uid().
GRANT USAGE ON SCHEMA auth TO anon, authenticated;

CREATE TABLE IF NOT EXISTS auth.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text,
  raw_user_meta_data jsonb,
  created_at timestamptz DEFAULT now()
);

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

CREATE SCHEMA IF NOT EXISTS storage;

CREATE TABLE IF NOT EXISTS storage.buckets (
  id text PRIMARY KEY,
  name text NOT NULL,
  public boolean DEFAULT false,
  file_size_limit bigint,
  allowed_mime_types text[],
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS storage.objects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_id text,
  name text,
  owner uuid,
  created_at timestamptz DEFAULT now(),
  UNIQUE(bucket_id,name)
);

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA storage TO anon, authenticated;
GRANT SELECT ON storage.objects TO anon;
GRANT SELECT,INSERT,UPDATE,DELETE ON storage.objects TO authenticated;

CREATE OR REPLACE FUNCTION storage.foldername(name text)
RETURNS text[]
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT string_to_array(name, '/');
$$;

CREATE TABLE public.membres (
  id uuid PRIMARY KEY,
  matricule text,
  prenom text NOT NULL,
  nom text NOT NULL,
  grade text DEFAULT 'Soldat de l''Honneur',
  fonction text DEFAULT 'Membre',
  telephone text,
  localite text DEFAULT 'Santo 13',
  statut text DEFAULT 'actif',
  photo_url text,
  points integer DEFAULT 0,
  role text DEFAULT 'membre',
  approuve boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  email text,
  user_id text,
  type_compte text DEFAULT 'membre',
  presences_count integer DEFAULT 0,
  approved_at timestamptz,
  whatsapp text,
  adresse text,
  enfant_id uuid
);

CREATE TABLE public.annonces (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  titre text NOT NULL,
  contenu text NOT NULL,
  auteur_id uuid,
  priorite text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.live_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  titre text,
  url text,
  actif boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.presence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membre_id uuid,
  activite text NOT NULL,
  date_presence date,
  valide_par uuid,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.presences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membre_id uuid,
  type_activite text,
  date_session date,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  url text NOT NULL,
  caption text,
  categorie text,
  uploade_par uuid,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.quiz_questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.quiz_resultats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membre_id uuid,
  score integer,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  titre text,
  actif boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.vote_reponses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vote_id uuid,
  membre_id uuid,
  choix text,
  created_at timestamptz DEFAULT now()
);

-- État dangereux décrit par l’audit : RLS coupée sur membres, politiques ouvertes.
ALTER TABLE public.membres DISABLE ROW LEVEL SECURITY;
CREATE POLICY public_all ON public.membres FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY read_all ON public.membres FOR SELECT USING (true);
CREATE POLICY insert_own ON public.membres FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY update_own ON public.membres FOR UPDATE USING (auth.uid() = id);

ALTER TABLE public.annonces ENABLE ROW LEVEL SECURITY;
CREATE POLICY public_all ON public.annonces FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY read ON public.annonces FOR SELECT USING (true);
CREATE POLICY insert ON public.annonces FOR INSERT WITH CHECK (true);

ALTER TABLE public.presences ENABLE ROW LEVEL SECURITY;
CREATE POLICY public_all ON public.presences FOR ALL USING (true) WITH CHECK (true);
ALTER TABLE public.live_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY public_all ON public.live_sessions FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.presence ENABLE ROW LEVEL SECURITY;
CREATE POLICY insert ON public.presence FOR INSERT WITH CHECK (true);
CREATE POLICY read ON public.presence FOR SELECT USING (true);
ALTER TABLE public.photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY insert ON public.photos FOR INSERT WITH CHECK (true);
CREATE POLICY read ON public.photos FOR SELECT USING (true);
ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;
CREATE POLICY insert ON public.quiz_questions FOR INSERT WITH CHECK (true);
CREATE POLICY read ON public.quiz_questions FOR SELECT USING (true);
ALTER TABLE public.votes ENABLE ROW LEVEL SECURITY;
CREATE POLICY insert ON public.votes FOR INSERT WITH CHECK (true);
CREATE POLICY read ON public.votes FOR SELECT USING (true);

ALTER TABLE public.quiz_resultats ENABLE ROW LEVEL SECURITY;
CREATE POLICY insert ON public.quiz_resultats FOR INSERT WITH CHECK (auth.uid() = membre_id);
CREATE POLICY read ON public.quiz_resultats FOR SELECT USING (true);
ALTER TABLE public.vote_reponses ENABLE ROW LEVEL SECURITY;
CREATE POLICY insert ON public.vote_reponses FOR INSERT WITH CHECK (auth.uid() = membre_id);
CREATE POLICY read ON public.vote_reponses FOR SELECT USING (true);

-- Comme sur le projet live : anon pouvait tout faire sur membres.
GRANT ALL ON TABLE public.membres TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;

-- Clés étrangères constatées lors de la vérification du projet hébergé.
ALTER TABLE public.votes ADD COLUMN cree_par uuid REFERENCES public.membres(id);
ALTER TABLE public.annonces ADD FOREIGN KEY (auteur_id) REFERENCES public.membres(id);
ALTER TABLE public.photos ADD FOREIGN KEY (uploade_par) REFERENCES public.membres(id);
ALTER TABLE public.presence ADD FOREIGN KEY (membre_id) REFERENCES public.membres(id);
ALTER TABLE public.presence ADD FOREIGN KEY (valide_par) REFERENCES public.membres(id);
ALTER TABLE public.presences ADD FOREIGN KEY (membre_id) REFERENCES public.membres(id);
ALTER TABLE public.quiz_resultats ADD FOREIGN KEY (membre_id) REFERENCES public.membres(id);
ALTER TABLE public.vote_reponses ADD FOREIGN KEY (membre_id) REFERENCES public.membres(id);
