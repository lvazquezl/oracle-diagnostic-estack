#!/usr/bin/env bash
# Valida que ninguna query Oracle Core invoque PL/SQL con side effects (EXEC/CALL/DBMS_* de escritura).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='\bEXEC\b|\bCALL\b|DBMS_SCHEDULER\.(ENABLE|DISABLE|CREATE|DROP|RUN)|DBMS_JOB\.(SUBMIT|REMOVE|RUN|BROKEN)|DBMS_SYSTEM\.|DBMS_SERVICE\.(CREATE|DELETE|START|STOP)'

for f in $(find "$ROOT/queries/oracle" -name 'Q-*.md'); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq "$PATTERN"; then
    echo "[FAIL] $f invoca PL/SQL con posible side effect en su statement certificado"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query Oracle Core invoca PL/SQL con side effects en su statement"

exit $FAIL
