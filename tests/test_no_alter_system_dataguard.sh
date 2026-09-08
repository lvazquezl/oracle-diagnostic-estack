#!/usr/bin/env bash
# Ningún artefacto Data Guard ejecuta ALTER SYSTEM SET LOG_ARCHIVE_DEST_n/_STATE_n.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/dataguard" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq 'ALTER SYSTEM'; then
    echo "[FAIL] $f contiene ALTER SYSTEM ejecutable"
    FAIL=1
  fi
done

grep -q 'ALTER SYSTEM SET LOG_ARCHIVE_DEST_n' "$ROOT/agents/oracle-dataguard-analyst/manifest.yaml" \
  && echo "[PASS] manifest.yaml prohíbe explícitamente ALTER SYSTEM sobre destinos" \
  || { echo "[FAIL] falta prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query Data Guard ejecuta ALTER SYSTEM"
exit $FAIL
