#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 17, # 27.
# Valida que las columnas de la variante moderna (con con_id) existen en las
# registradas (columns_exhaustive) para PDB_PLUG_IN_VIOLATIONS en el dictionary, y que con_id
# tiene min_version 12.2 (no 12.1).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"
Q="$ROOT/queries/multitenant/Q-CDB-PLUGIN-VIOLATIONS-001.md"

con_id_min=$(awk '
  BEGIN{IGNORECASE=1; inview=0; incols=0}
  /^  [A-Za-z$#0-9_]+:[ \t]*$/{line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line); inview=(tolower(line)=="pdb_plug_in_violations")?1:0; incols=0; next}
  inview && /^    columns:[ \t]*$/{incols=1; next}
  inview && incols && /con_id:/{line=$0; sub(/.*min_version:[ \t]*"/,"",line); sub(/".*/,"",line); print line; exit}
' "$DICT")

[ "$con_id_min" = "12.2" ] && echo "[PASS] PDB_PLUG_IN_VIOLATIONS.con_id.min_version = 12.2 en el dictionary" || { echo "[FAIL] con_id.min_version = '$con_id_min', esperado 12.2"; FAIL=1; }

sql_v2=$(awk '/```sql/{n++;next} n==2 && /```/{exit} n==2{print}' "$Q" | tr '\n' ' ')
# CHG-ESTACK-PDB-COVERAGE-001 (4.0.0): la variante moderna es un resumen. Usa sólo columnas registradas (columns_exhaustive)
# y NO selecciona texto libre: message/action/line/error_number pueden llevar nombres o rutas.
EXPECTED="con_id name cause type status time"
n=0
for col in $EXPECTED; do
  if grep -qiw "$col" <<<"$sql_v2"; then
    n=$((n+1))
  else
    echo "[FAIL] la variante moderna no usa '$col'"
    FAIL=1
  fi
done
[ "$n" -eq 6 ] && echo "[PASS] las 6 columnas del resumen están presentes en la variante moderna"
for col in message action line error_number; do
  if grep -qiw "$col" <<<"$sql_v2"; then
    echo "[FAIL] la variante moderna selecciona texto libre '$col'"
    FAIL=1
  fi
done
[ "$FAIL" -eq 0 ] && echo "[PASS] la variante moderna no selecciona message/action/line/error_number"

exit $FAIL
