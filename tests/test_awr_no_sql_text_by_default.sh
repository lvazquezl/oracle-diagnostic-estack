#!/usr/bin/env bash
# Valida que ninguna query AWR (DBA_HIST_*) certificada seleccione SQL_TEXT/SQL_FULLTEXT.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(grep -rl '^objects_accessed:.*DBA_HIST_' "$ROOT/queries/performance" --include='Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq 'SQL_TEXT|SQL_FULLTEXT'; then
    echo "[FAIL] $f selecciona SQL_TEXT/SQL_FULLTEXT"
    FAIL=1
  fi
done
[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query AWR selecciona SQL text por defecto"

exit $FAIL
