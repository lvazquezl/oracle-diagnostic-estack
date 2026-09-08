#!/usr/bin/env bash
# PHASE 5 — DATA GUARD COMPATIBILITY & QUERY CERTIFICATION HARDENING, sección 6.
# Regresión específica: Q-DG-ROLE-001 sólo puede seleccionar columnas realmente registradas
# como columns_exhaustive: true para V$DATABASE en compatibility/oracle-dictionary/views.yaml.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/dataguard/Q-DG-ROLE-001.md"
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"

[ -f "$Q" ] || { echo "[FAIL] falta Q-DG-ROLE-001.md"; exit 1; }

block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$Q" | sed -E 's/--.*$//')
selected=$(echo "$block" | tr '\n' ' ' | sed -E 's/.*SELECT //I; s/ FROM .*//I' | tr ',' '\n' | sed -E 's/^ *//; s/ *$//' | tr 'A-Z' 'a-z')

valid_cols=$(awk '
  BEGIN{inview=0; incols=0; exhaustive=0}
  /^  V\$DATABASE:[ \t]*$/ { inview=1; next }
  /^  [A-Za-z$#0-9_]+:[ \t]*$/ { if (!/^  V\$DATABASE:/) inview=0 }
  inview && /^    columns_exhaustive:[ \t]*true[ \t]*$/ { exhaustive=1; next }
  inview && /^    columns:[ \t]*$/ { incols=1; next }
  inview && incols {
    if ($0 ~ /^      [A-Za-z_#][A-Za-z0-9_#]*:/) { line=$0; sub(/^      /,"",line); sub(/:.*/,"",line); print tolower(line); next }
    if ($0 ~ /^[ \t]*#/) { next }
    if ($0 ~ /^[ \t]*$/) { incols=0; next }
    incols=0
  }
' "$DICT")

echo "$valid_cols" | grep -qx "db_unique_name" && echo "[PASS] compatibility/oracle-dictionary/views.yaml registra V\$DATABASE como columns_exhaustive con db_unique_name" || { echo "[FAIL] V\$DATABASE no está registrada como columns_exhaustive:true con db_unique_name"; FAIL=1; }

while IFS= read -r col; do
  [ -z "$col" ] && continue
  if ! echo "$valid_cols" | grep -qx "$col"; then
    echo "[FAIL] Q-DG-ROLE-001 selecciona '$col' — no está registrada como columna real de V\$DATABASE"
    FAIL=1
  fi
done <<< "$selected"

[ $FAIL -eq 0 ] && echo "[PASS] Q-DG-ROLE-001 sólo referencia columnas reales de V\$DATABASE"

exit $FAIL
