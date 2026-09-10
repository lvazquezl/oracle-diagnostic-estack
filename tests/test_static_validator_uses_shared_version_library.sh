#!/usr/bin/env bash
# PHASE 6 — FINAL PDB IDENTITY & PATCH-LEVEL RESOLVER HARDENING, # 22, # 39, # 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
VALIDATOR="$ROOT/tests/test_sql_static_validator.sh"

grep -q 'source .*scripts/lib/version\.sh' "$VALIDATOR" && echo "[PASS] test_sql_static_validator.sh sourcea scripts/lib/version.sh" || { echo "[FAIL] test_sql_static_validator.sh no sourcea scripts/lib/version.sh"; FAIL=1; }

if grep -qE '^\s*vernum3?\s*\(\)' "$VALIDATOR"; then
  echo "[FAIL] test_sql_static_validator.sh todavía declara un vernum()/vernum3() local"
  FAIL=1
else
  echo "[PASS] test_sql_static_validator.sh no declara ningún vernum()/vernum3() local"
fi

# El validador sólo necesita comparaciones ">=" (range_min contra min_version de vista/columna) —
# no requiere las 5 funciones de la librería, sólo la que efectivamente usa.
grep -q 'version_gte' "$VALIDATOR" && echo "[PASS] test_sql_static_validator.sh invoca version_gte de la librería compartida" || { echo "[FAIL] test_sql_static_validator.sh no invoca version_gte"; FAIL=1; }

[ -f "$ROOT/scripts/lib/version.sh" ] && echo "[PASS] scripts/lib/version.sh existe" || { echo "[FAIL] scripts/lib/version.sh no existe"; FAIL=1; }

exit $FAIL
