#!/usr/bin/env bash
# Teste la migration sur un Postgres local jetable (jamais la base Supabase).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB="achus_portail_test"
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

echo "MIGRATION_OK"
