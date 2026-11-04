import { PGlite } from '@electric-sql/pglite';
import { readFile, readdir } from 'node:fs/promises';
const db = new PGlite();
const run = async (path) => {
  console.log('→ ' + path);
  await db.exec(await readFile(path, 'utf8'));
};
try {
  await run('supabase/tests/00_schema_snapshot.sql');
  await run('supabase/tests/01_seed.sql');
  const base = 'supabase/migrations/20261104120000_portail_refonte.sql';
  await run(base);
  await run(base);
  await run('supabase/tests/02_assertions.sql');
  const migrations = (await readdir('supabase/migrations')).filter(f => f.endsWith('_messagerie_presences_registre.sql'));
  if (migrations.length !== 1) throw new Error('Migration collaboration introuvable ou ambiguë.');
  const nouvelle = 'supabase/migrations/' + migrations[0];
  await run(nouvelle);
  await run(nouvelle);
  const correction = 'supabase/migrations/20261104135930_correction_suppression_dependances.sql';
  await run(correction);
  await run(correction);
  await run('supabase/tests/03_collaboration.sql');
  await run(nouvelle);
  await run(correction);
  await run('supabase/tests/04_conservation.sql');
  const social = 'supabase/migrations/20261104143144_reseau_social_gratuit.sql';
  await run(social);
  await run(social);
  await run('supabase/tests/05_reseau_social.sql');
  await run(social);
  await db.exec("DO $$ BEGIN ASSERT (SELECT count(*)=1 FROM public.publications); ASSERT (SELECT count(*)=1 FROM public.commentaires); ASSERT (SELECT count(*)=1 FROM public.appels); END $$;");
  console.log('MIGRATION_OK (Postgres embarqué, RLS et conservation vérifiées)');
} catch (error) {
  console.error('ÉCHEC SQL :', error.code, error.message, error.where || '');
  process.exitCode = 1;
} finally {
  await db.close();
}
