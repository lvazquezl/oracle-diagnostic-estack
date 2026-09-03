#!/usr/bin/env bash
# Valida que ninguna query Oracle Core seleccione bind values de sesión (V$SQL_BIND_CAPTURE, etc.).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='V\$SQL_BIND_CAPTURE|V\$SQL_BIND_DATA|bind_value|VALUE_STRING.*BIND'

for f in $(find "$ROOT/queries/oracle" -name 'Q-*.md'); do
  content=$(cat "$f")
  if echo "$content" | grep -Eiq "$PATTERN"; then
    echo "[FAIL] $f referencia bind values"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query Oracle Core referencia bind values"

exit $FAIL
