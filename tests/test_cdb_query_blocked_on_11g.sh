#!/usr/bin/env bash
# Valida que ninguna query con container_scope: CDB_ROOT declare soporte para 11g (Multitenant
# no existe antes de 12c) -- el Resolver no debe poder seleccionar una variante CDB_ROOT sobre 11g.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries" -name 'Q-*.md'); do
  scope=$(grep -m1 '^container_scope:' "$f" | awk '{print $2}')
  [ "$scope" != "CDB_ROOT" ] && continue
  versions=$(grep -m1 '^supported_oracle_versions:' "$f" || true)
  if echo "$versions" | grep -qE '\b(10g|11g)\b'; then
    echo "[FAIL] $f — container_scope: CDB_ROOT pero declara soporte para 10g/11g (Multitenant no existe)"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query CDB_ROOT declara soporte para 10g/11g"

exit $FAIL
