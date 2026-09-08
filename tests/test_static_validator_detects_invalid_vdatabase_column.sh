#!/usr/bin/env bash
# PHASE 5 — DATA GUARD COMPATIBILITY & QUERY CERTIFICATION HARDENING, sección 29.
# Fixture negativo controlado (NUNCA agregado a queries/, sólo en memoria/temp aquí) para probar
# que el chequeo de existencia de columna del SQL Static Validator (tests/test_sql_static_validator.sh)
# efectivamente rechaza una columna inexistente — reproduce, de forma aislada, el mismo mecanismo
# que detecta hoy que V$DATABASE.LOG_ARCHIVE_CONFIG no existe (bug real corregido en Q-DG-ROLE-001).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"
FAIL=0

get_view_columns() {
  local target="$1"
  awk -v target="$target" '
    BEGIN { IGNORECASE=1; inview=0; incols=0; exhaustive=0 }
    /^  [A-Za-z$#0-9_]+:[ \t]*$/ {
      line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line)
      inview = (tolower(line) == tolower(target)) ? 1 : 0
      incols=0; exhaustive=0
      next
    }
    inview && /^    columns_exhaustive:[ \t]*true[ \t]*$/ { exhaustive=1; next }
    inview && /^    columns:[ \t]*$/ { incols=1; next }
    inview && incols {
      if (!exhaustive) { next }
      if ($0 ~ /^      [A-Za-z_#][A-Za-z0-9_#]*:/) { line=$0; sub(/^      /,"",line); sub(/:.*/,"",line); print tolower(line); next }
      if ($0 ~ /^[ \t]*#/) { next }
      if ($0 ~ /^[ \t]*$/) { incols=0; next }
      incols=0
    }
  ' "$DICT"
}

valid_cols=$(get_view_columns "V\$DATABASE")

# Fixture negativo — deliberadamente inválido, NUNCA parte del catálogo productivo (# 29).
FAKE_SQL="SELECT fake_column FROM v\$database;"
fake_col=$(echo "$FAKE_SQL" | sed -E 's/.*SELECT //I; s/ FROM .*//I' | tr 'A-Z' 'a-z' | sed -E 's/^ *//; s/ *$//')

if echo "$valid_cols" | grep -qx "$fake_col"; then
  echo "[FAIL] el fixture negativo 'fake_column' aparece como válido — el mecanismo de existencia de columna no está funcionando"
  FAIL=1
else
  echo "[PASS] NOT_CERTIFIED: 'fake_column' correctamente rechazada — no existe en V\$DATABASE (mismo mecanismo que rechazaría LOG_ARCHIVE_CONFIG si se reintrodujera)"
fi

# Control positivo: una columna real de V$DATABASE sí debe pasar con el mismo mecanismo.
real_col="database_role"
if echo "$valid_cols" | grep -qx "$real_col"; then
  echo "[PASS] Control positivo: '$real_col' (columna real) correctamente aceptada"
else
  echo "[FAIL] Control positivo falló — '$real_col' debería existir en V\$DATABASE"
  FAIL=1
fi

# El fixture negativo no debe existir en el catálogo productivo.
if grep -rq 'fake_column' "$ROOT/queries" --include='Q-*.md' 2>/dev/null; then
  echo "[FAIL] el fixture negativo 'fake_column' se filtró al catálogo de queries productivas"
  FAIL=1
else
  echo "[PASS] El fixture negativo permanece fuera del catálogo de queries productivas"
fi

exit $FAIL
