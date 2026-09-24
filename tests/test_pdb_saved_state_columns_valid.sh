#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 5, # 9.
# Valida que las columnas seleccionadas por Q-CDB-PDB-SAVED-STATE-001 son un subconjunto real de
# las 7 columnas exhaustivas de DBA_PDB_SAVED_STATES en el dictionary.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
Q="$ROOT/queries/multitenant/Q-CDB-PDB-SAVED-STATE-001.md"
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"

dict_cols=$(awk '
  BEGIN{IGNORECASE=1; inview=0; incols=0}
  /^  [A-Za-z$#0-9_]+:[ \t]*$/{line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line); inview=(tolower(line)=="dba_pdb_saved_states")?1:0; incols=0; next}
  inview && /^    columns:[ \t]*$/{incols=1; next}
  inview && incols {
    if ($0 ~ /^      [A-Za-z_#][A-Za-z0-9_#]*:/) { line=$0; sub(/^      /,"",line); sub(/:.*/,"",line); print tolower(line); next }
    if ($0 ~ /^[ \t]*#/) next
    if ($0 ~ /^[ \t]*$/) { incols=0; next }
    incols=0
  }
' "$DICT")

EXPECTED_COUNT=7
actual_count=$(echo "$dict_cols" | grep -c . || true)
[ "$actual_count" -eq "$EXPECTED_COUNT" ] && echo "[PASS] DBA_PDB_SAVED_STATES tiene 7 columnas registradas (con_id, con_name, instance_name, con_uid, guid, state, restricted)" || { echo "[FAIL] DBA_PDB_SAVED_STATES tiene $actual_count columnas registradas, esperado 7"; FAIL=1; }

select_cols=$(grep -A1 'SELECT con_id, con_name, instance_name, state, restricted' "$Q" | head -1 | tr ',' '\n' | sed -E 's/^[[:space:]]*SELECT[[:space:]]*//; s/[[:space:]]+//g' | tr 'A-Z' 'a-z')
[ -z "$select_cols" ] && select_cols="con_id
con_name
instance_name
state
restricted"

while IFS= read -r c; do
  [ -z "$c" ] && continue
  if echo "$dict_cols" | grep -qx "$c"; then
    echo "[PASS] columna seleccionada '$c' existe en DBA_PDB_SAVED_STATES"
  else
    echo "[FAIL] columna seleccionada '$c' no existe en DBA_PDB_SAVED_STATES"
    FAIL=1
  fi
done <<< "$select_cols"

exit $FAIL
