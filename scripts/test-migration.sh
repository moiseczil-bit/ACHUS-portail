#!/usr/bin/env bash
# Teste la migration sur un Postgres local jetable (jamais la base Supabase).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB="achus_portail_test"
cd "$ROOT"
# Sans serveur Postgres, même SQL dans un Postgres embarqué jetable en mémoire.
# Aucun DATABASE_URL, aucun lien Supabase, aucun accès réseau à une base.
if ! command -v psql >/dev/null || [[ "${ACHUS_TEST_EMBARQUE:-0}" == "1" ]]; then
  exec node scripts/test-migration.mjs
fi
PSQL=(sudo -u postgres psql -v ON_ERROR_STOP=1)

echo "→ base jetable ${DB}"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres -c "DROP DATABASE IF EXISTS ${DB};"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres -c "CREATE DATABASE ${DB};"

echo "→ schéma live (audit) + 2 membres + 5 comptes"
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/tests/00_schema_snapshot.sql"
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/tests/01_seed.sql"

echo "→ migration (1er passage)"
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/migrations/20261104120000_portail_refonte.sql"

echo "→ migration (2e passage, idempotence)"
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/migrations/20261104120000_portail_refonte.sql"

echo "→ assertions"
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/tests/02_assertions.sql"

for migration in "$ROOT"/supabase/migrations/*_messagerie_presences_registre.sql; do
  echo "→ nouvelle migration (deux passages)"
  "${PSQL[@]}" -d "$DB" -f "$migration"
  "${PSQL[@]}" -d "$DB" -f "$migration"
done
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/migrations/20261104135930_correction_suppression_dependances.sql"
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/migrations/20261104135930_correction_suppression_dependances.sql"
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/tests/03_collaboration.sql"
# Réexécuter après utilisation, puis vérifier la conservation des données.
for migration in "$ROOT"/supabase/migrations/*_messagerie_presences_registre.sql; do
  "${PSQL[@]}" -d "$DB" -f "$migration"
done
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/migrations/20261104135930_correction_suppression_dependances.sql"
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/tests/04_conservation.sql"

SOCIAL="$ROOT/supabase/migrations/20261104143144_reseau_social_gratuit.sql"
"${PSQL[@]}" -d "$DB" -f "$SOCIAL"
"${PSQL[@]}" -d "$DB" -f "$SOCIAL"
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/tests/05_reseau_social.sql"
"${PSQL[@]}" -d "$DB" -f "$SOCIAL"
"${PSQL[@]}" -d "$DB" -c 'DO $$ BEGIN ASSERT (SELECT count(*)=1 FROM public.publications); ASSERT (SELECT count(*)=1 FROM public.commentaires); ASSERT (SELECT count(*)=1 FROM public.appels); END $$;'
GRADE="$ROOT/supabase/migrations/20261104183055_grade_personnel.sql"
"${PSQL[@]}" -d "$DB" -f "$GRADE"
"${PSQL[@]}" -d "$DB" -f "$GRADE"
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/tests/06_grade_personnel.sql"
"${PSQL[@]}" -d "$DB" -f "$GRADE"
PHOTOS="$ROOT/supabase/migrations/20261104184248_photos_profil_communaute.sql"
"${PSQL[@]}" -d "$DB" -f "$PHOTOS"
"${PSQL[@]}" -d "$DB" -f "$PHOTOS"
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/tests/07_photos_profils.sql"
"${PSQL[@]}" -d "$DB" -f "$PHOTOS"
echo "MIGRATION_OK"
