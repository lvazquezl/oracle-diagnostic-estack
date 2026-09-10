#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 8.
# Valida que CDB_PDB_SAVED_STATES (nombre incorrecto usado en la construcción base de Fase 6) ya
# no está registrada como vista certificada en el dictionary — WebFetch a docs.oracle.com confirma
# HTTP 404 para esa vista, no es real.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"

if awk 'BEGIN{IGNORECASE=1} /^  CDB_PDB_SAVED_STATES:[ \t]*$/{found=1} END{exit !found}' "$DICT"; then
  echo "[FAIL] CDB_PDB_SAVED_STATES sigue registrada como vista en el dictionary — no es una vista Oracle real (404 en docs.oracle.com)"
  FAIL=1
else
  echo "[PASS] CDB_PDB_SAVED_STATES ya no está registrada como vista en el dictionary"
fi

if awk 'BEGIN{IGNORECASE=1} /^  DBA_PDB_SAVED_STATES:[ \t]*$/{found=1} END{exit !found}' "$DICT"; then
  echo "[PASS] DBA_PDB_SAVED_STATES (vista real) está registrada en el dictionary"
else
  echo "[FAIL] DBA_PDB_SAVED_STATES no está registrada en el dictionary"
  FAIL=1
fi

# Sólo se valida el bloque SQL ejecutable (```sql fences) — el resto del archivo documenta
# deliberadamente la corrección con el nombre incorrecto como referencia histórica/explicativa.
sql_hits=0
for f in "$ROOT"/queries/multitenant/*.md; do
  block=$(awk '/```sql/{f=1;next} /```/{f=0} f' "$f")
  if echo "$block" | grep -qi 'cdb_pdb_saved_states'; then
    echo "[FAIL] $(basename "$f") — el bloque SQL ejecutable referencia cdb_pdb_saved_states"
    sql_hits=1
  fi
done
[ "$sql_hits" -eq 0 ] && echo "[PASS] ningún bloque SQL ejecutable referencia cdb_pdb_saved_states" || FAIL=1

exit $FAIL
