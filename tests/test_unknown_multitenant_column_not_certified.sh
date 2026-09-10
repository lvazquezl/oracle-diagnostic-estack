#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 26.
# Fixture conceptual del prompt: "SELECT fake_column FROM v$pdbs" -> NOT_CERTIFIED. Valida que
# fake_column no está registrada en V$PDBS (columns_exhaustive:true), el predicado exacto del que
# depende tests/test_sql_static_validator.sh (chequeo 2) para producir ese resultado.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"

get_columns() {
  awk -v target="$1" '
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
      if ($0 ~ /^      [A-Za-z_#][A-Za-z0-9_#]*:/) {
        line=$0; sub(/^      /,"",line); sub(/:.*/,"",line); print tolower(line); next
      }
      if ($0 ~ /^[ \t]*#/) { next }
      if ($0 ~ /^[ \t]*$/) { incols=0; next }
      incols=0
    }
  ' "$DICT"
}

cols=$(get_columns "V\$PDBS")
[ -n "$cols" ] && echo "[PASS] V\$PDBS es columns_exhaustive:true — el chequeo de existencia de columna aplica" || { echo "[FAIL] V\$PDBS no resolvió columnas exhaustivas"; FAIL=1; }

if echo "$cols" | grep -qx "fake_column"; then
  echo "[FAIL] fake_column aparece registrada en V\$PDBS — el dictionary certificaría una columna inexistente"
  FAIL=1
else
  echo "[PASS] fake_column no está en V\$PDBS — 'SELECT fake_column FROM v\$pdbs' sería NOT_CERTIFIED"
fi

exit $FAIL
