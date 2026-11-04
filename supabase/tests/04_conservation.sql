-- Après un troisième passage de la nouvelle migration sur des données réelles de test.
DO $$
BEGIN
  ASSERT (SELECT count(*) = 1 FROM public.messages), 'Messages perdus à la réexécution';
  ASSERT (SELECT count(*) = 2 FROM public.presences_evenements), 'Présences perdues à la réexécution';
  ASSERT (SELECT count(*) = 1 FROM public.historique_statuts WHERE numero_membre = 'ACHUS-002'), 'Motif perdu';
  ASSERT (SELECT count(*) = 1 FROM app_private.numeros_reserves WHERE numero = 'ACHUS-002'), 'Réservation perdue';
  ASSERT EXISTS (SELECT 1 FROM public.journal_admin WHERE action = 'decision_presence'), 'Journal perdu';
  ASSERT NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE ((n.nspname = 'public' AND c.relname IN ('messages','presences_evenements','historique_statuts','journal_admin'))
      OR (n.nspname = 'app_private' AND c.relname = 'numeros_reserves')) AND NOT c.relrowsecurity), 'RLS manquante';
  ASSERT NOT has_table_privilege('authenticated','public.journal_admin','INSERT'), 'Journal falsifiable';
  ASSERT NOT has_function_privilege('anon','public.supprimer_membre(uuid,text,text)','EXECUTE'), 'RPC exposée à anon';
END $$;
