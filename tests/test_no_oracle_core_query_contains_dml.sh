#!/usr/bin/env bash
# Valida que ningún statement SQL bajo queries/oracle/ contenga INSERT/UPDATE/DELETE/MERGE.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='(^|[^A-Za-z_])(INSERT|UPDATE|DELETE|MERGE)([^A-Za-z_]|$)'

for f in $(find "$ROOT/queries/oracle" -name 'Q-*.md'); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq "$PATTERN"; then
    echo "[FAIL] $f contiene DML"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query Oracle Core contiene DML"

exit $FAIL
