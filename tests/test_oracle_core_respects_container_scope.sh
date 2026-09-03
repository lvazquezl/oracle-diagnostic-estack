#!/usr/bin/env bash
# Valida que toda query Oracle Core declare container_scope válido (reusa la regla general del
# Query Contract v2, acotada al subárbol oracle/).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
VALID='^container_scope: (NON_CDB|CDB_ROOT|PDB|ANY_CONTAINER|NOT_APPLICABLE)$'

for f in $(find "$ROOT/queries/oracle" -name 'Q-*.md'); do
  line=$(grep '^container_scope:' "$f" || true)
  if [ -z "$line" ] || ! echo "$line" | grep -Eq "$VALID"; then
    echo "[FAIL] $f no declara container_scope válido"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Toda query Oracle Core declara container_scope válido"

exit $FAIL
