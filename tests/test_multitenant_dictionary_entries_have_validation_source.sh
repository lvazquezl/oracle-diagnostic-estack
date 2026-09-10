#!/usr/bin/env bash
# PHASE 6 — QUERY COMPATIBILITY & DICTIONARY CERTIFICATION HARDENING, # 23-24.
# Toda vista Multitenant marcada columns_exhaustive:true debe declarar un bloque validation:
# {source_type, status, validated_for} — trazabilidad independiente, el dictionary no puede
# autovalidarse (# 22).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DICT="$ROOT/compatibility/oracle-dictionary/views.yaml"

# Recorta sólo la sección Fase 6 (línea "--- Fase 6 (Multitenant / CDB / PDB) ---" hasta EOF).
section=$(awk '/# --- Fase 6 \(Multitenant \/ CDB \/ PDB\) ---/{f=1} f{print}' "$DICT")

views=$(echo "$section" | awk '/^  [A-Za-z$#0-9_]+:[ \t]*$/{line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line); print line}')

n_exhaustive=0
while IFS= read -r v; do
  [ -z "$v" ] && continue
  block=$(echo "$section" | awk -v target="$v" '
    BEGIN{IGNORECASE=1}
    /^  [A-Za-z$#0-9_]+:[ \t]*$/{line=$0; sub(/^  /,"",line); sub(/:[ \t]*$/,"",line); inview=(tolower(line)==tolower(target))?1:0; if(inview){print; next} else {if(started) exit; next}}
    inview{started=1; print}
  ')
  if echo "$block" | grep -q 'columns_exhaustive:[ \t]*true'; then
    n_exhaustive=$((n_exhaustive+1))
    if echo "$block" | grep -q '^    validation:' && echo "$block" | grep -q 'source_type: ORACLE_DOCUMENTATION' && echo "$block" | grep -q 'status: DOCUMENTATION_VALIDATED' && echo "$block" | grep -q 'validated_for:'; then
      echo "[PASS] $v declara validation: {source_type, status, validated_for}"
    else
      echo "[FAIL] $v es columns_exhaustive:true pero no declara un bloque validation: completo"
      FAIL=1
    fi
  fi
done <<< "$views"

[ "$n_exhaustive" -eq 7 ] && echo "[PASS] 7 vistas Multitenant columns_exhaustive:true verificadas (V\$PDBS, V\$CONTAINERS, DBA_PDB_SAVED_STATES, PDB_PLUG_IN_VIOLATIONS, V\$RSRCPDBMETRIC, DBA_CDB_RSRC_PLAN_DIRECTIVES, CDB_LOCKDOWN_PROFILES)" || { echo "[FAIL] $n_exhaustive vistas columns_exhaustive:true encontradas, esperado 7"; FAIL=1; }

exit $FAIL
