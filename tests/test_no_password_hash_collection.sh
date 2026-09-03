#!/usr/bin/env bash
# Valida que ninguna query Oracle Core seleccione password_hash/spare4 (USER$/DBA_USERS hash) ni
# columnas equivalentes de credenciales.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='password_hash|password\b|spare4|\bhash\b.*credential|wallet.*content'

for f in $(find "$ROOT/queries/oracle" -name 'Q-*.md'); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq "$PATTERN"; then
    echo "[FAIL] $f parece seleccionar material de credencial"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query Oracle Core selecciona password hashes ni material de credencial"

exit $FAIL
