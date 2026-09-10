#!/usr/bin/env bash
# Valida que toda query certificada declare container_scope con un valor del enum permitido.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
VALID='^container_scope: (NON_CDB_ONLY|CDB_ROOT_ONLY|PDB_ONLY|ANY_CONTAINER|NOT_APPLICABLE)$'

for f in $(find "$ROOT/queries" -name 'Q-*.md'); do
  [ -f "$f" ] || continue
  line=$(grep '^container_scope:' "$f" || true)
  if [ -z "$line" ]; then
    echo "[FAIL] $f no declara container_scope"
    FAIL=1
  elif ! echo "$line" | grep -Eq "$VALID"; then
    echo "[FAIL] $f declara container_scope con valor fuera del enum: $line"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Toda query certificada declara container_scope válido"

exit $FAIL
