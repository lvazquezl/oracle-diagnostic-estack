#!/usr/bin/env bash
# Valida que las queries certificadas sólo referencien diccionario/V$/GV$/histórico, no esquema de aplicación.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
ALLOWED='^(V\$|GV\$|DBA_|CDB_|PDB_|ALL_|STATS\$|/proc/|listener\.ora|sqlnet\.ora|tnsnames\.ora|listener\.log|alert\.log|vm\.nr_hugepages|ROLE_ROLE_PRIVS|ROLE_SYS_PRIVS|ROLE_TAB_PRIVS|PROXY_USERS|UNIFIED_AUDIT_TRAIL|AUDIT_UNIFIED_ENABLED_POLICIES|AUDIT_UNIFIED_POLICIES|REDACTION_POLICIES|REDACTION_COLUMNS)'

for f in $(find "$ROOT/queries" -name 'Q-*.md'); do
  [ -f "$f" ] || continue
  objs=$(awk -F': ' '/^objects_accessed:/{print; exit}' "$f")
  # Extraer los items entre corchetes
  items=$(echo "$objs" | sed -E 's/objects_accessed: *\[(.*)\]/\1/' | tr ',' '\n' | sed -E 's/^ *//; s/ *$//')
  bad=0
  while IFS= read -r item; do
    [ -z "$item" ] && continue
    if ! echo "$item" | grep -Eq "$ALLOWED"; then
      echo "[FAIL] $f referencia un objeto fuera de diccionario/V\$/OS certificado: $item"
      bad=1
    fi
  done <<< "$items"
  if [ $bad -eq 0 ]; then
    echo "[PASS] $f — objetos consultados dentro de alcance permitido"
  else
    FAIL=1
  fi
done

exit $FAIL
