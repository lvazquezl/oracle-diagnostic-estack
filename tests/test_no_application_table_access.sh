#!/usr/bin/env bash
# Valida que ninguna query Oracle Core acceda a objetos fuera de V$/GV$/DBA_/CDB_/ALL_/archivo certificado.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
ALLOWED='^(V\$|GV\$|DBA_|CDB_|ALL_|STATS\$|alert\.log)'

for f in $(find "$ROOT/queries/oracle" -name 'Q-*.md'); do
  objs=$(awk -F': ' '/^objects_accessed:/{print; exit}' "$f")
  items=$(echo "$objs" | sed -E 's/objects_accessed: *\[(.*)\]/\1/' | tr ',' '\n' | sed -E 's/^ *//; s/ *$//')
  while IFS= read -r item; do
    [ -z "$item" ] && continue
    if ! echo "$item" | grep -Eq "$ALLOWED"; then
      echo "[FAIL] $f referencia un objeto fuera de diccionario certificado: $item"
      FAIL=1
    fi
  done <<< "$items"
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query Oracle Core accede a objetos de aplicación"

exit $FAIL
