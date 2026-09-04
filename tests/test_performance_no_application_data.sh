#!/usr/bin/env bash
# Valida que ninguna query de queries/performance/ acceda a tablas de aplicación — sólo
# V$*/GV$*/DBA_*/STATS$* de diccionario/dinámicas/Statspack.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/performance" -name 'Q-*.md'); do
  objects=$(grep -m1 '^objects_accessed:' "$f" | sed -E 's/^objects_accessed: *\[//; s/\]$//')
  IFS=',' read -ra items <<< "$objects"
  for item in "${items[@]}"; do
    item=$(echo "$item" | sed -E 's/^ *//; s/ *$//')
    [ -z "$item" ] && continue
    if ! echo "$item" | grep -Eq '^(V\$|GV\$|DBA_|STATS\$)'; then
      echo "[FAIL] $f declara objects_accessed '$item' fuera de V\$/GV\$/DBA_/STATS\$"
      FAIL=1
    fi
  done
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query de performance accede a tablas de aplicación"

exit $FAIL
