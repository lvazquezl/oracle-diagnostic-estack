#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 13.
# Valida que las 17 columnas seleccionadas por Q-CDB-RESOURCE-USAGE-001 son exactamente las
# registradas (columns_exhaustive) para V$RSRCPDBMETRIC en el dictionary.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"
Q="$ROOT/queries/multitenant/Q-CDB-RESOURCE-USAGE-001.md"

dict_cols=$(awk '
  BEGIN{IGNORECASE=1; inview=0; incols=0}
  /^  [A-Za-z$#0-9_]+:[ \t]*$/{line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line); inview=(tolower(line)=="v$rsrcpdbmetric")?1:0; incols=0; next}
  inview && /^    columns:[ \t]*$/{incols=1; next}
  inview && incols {
    if ($0 ~ /^      [A-Za-z_#][A-Za-z0-9_#]*:/) { line=$0; sub(/^      /,"",line); sub(/:.*/,"",line); print tolower(line); next }
    if ($0 ~ /^[ \t]*#/) next
    if ($0 ~ /^[ \t]*$/) { incols=0; next }
    incols=0
  }
' "$DICT")

sql_block=$(awk '/```sql/{f=1;next} /```/{f=0} f' "$Q" | tr '\n' ' ')
select_line=$(echo "$sql_block" | sed -E 's/.*SELECT //I; s/ FROM.*//I')
select_cols=$(echo "$select_line" | tr ',' '\n' | sed -E 's/^\s+|\s+$//g' | tr 'A-Z' 'a-z')

n=0
while IFS= read -r c; do
  [ -z "$c" ] && continue
  n=$((n+1))
  if echo "$dict_cols" | grep -qx "$c"; then
    echo "[PASS] columna '$c' existe en V\$RSRCPDBMETRIC"
  else
    echo "[FAIL] columna '$c' no existe en V\$RSRCPDBMETRIC"
    FAIL=1
  fi
done <<< "$select_cols"

[ "$n" -eq 17 ] && echo "[PASS] 17 columnas seleccionadas, coincide con el conteo esperado" || { echo "[FAIL] $n columnas seleccionadas, esperado 17"; FAIL=1; }

exit $FAIL
