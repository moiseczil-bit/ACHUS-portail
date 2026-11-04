-- 5 comptes auth + 2 fiches, comme la base live (aucun user_id relié, 1 e-mail en commun).

INSERT INTO auth.users (id, email) VALUES
  ('11111111-1111-4111-8111-111111111111', 'president@achussantohaiti.com'),
  ('22222222-2222-4222-8222-222222222222', 'autre2@example.com'),
  ('33333333-3333-4333-8333-333333333333', 'autre3@example.com'),
  ('44444444-4444-4444-8444-444444444444', 'autre4@example.com'),
  ('55555555-5555-4555-8555-555555555555', 'autre5@example.com');

INSERT INTO public.membres (
  id, prenom, nom, email, statut, type_compte, role, grade, fonction, user_id, created_at
) VALUES
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'Moïse-Son',
    'Cezil',
    'President@AchusSantoHaiti.com',
    'approuve',
    'admin',
    'membre',
    'Général',
    'Président',
    NULL,
    '2005-01-15'
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'Jean',
    'Baptiste',
    'jean.baptiste@example.com',
    'actif',
    'membre',
    'membre',
    'Soldat de l''Honneur',
    'Membre',
    'pas-un-uuid',
    '2024-06-01'
  );
