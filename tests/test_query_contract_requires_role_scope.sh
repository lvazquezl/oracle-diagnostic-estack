#!/usr/bin/env bash
# Valida que toda query certificada declare database_role_scope con un valor del enum permitido.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
VALID='^database_role_scope: (PRIMARY|STANDBY|ANY|NOT_APPLICABLE)$'

for f in $(find "$ROOT/queries" -name 'Q-*.md'); do
  [ -f "$f" ] || continue
  line=$(grep '^database_role_scope:' "$f" || true)
  if [ -z "$line" ]; then
    echo "[FAIL] $f no declara database_role_scope"
    FAIL=1
  elif ! echo "$line" | grep -Eq "$VALID"; then
    echo "[FAIL] $f declara database_role_scope con valor fuera del enum: $line"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Toda query certificada declara database_role_scope válido"

exit $FAIL
