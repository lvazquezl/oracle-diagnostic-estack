#!/usr/bin/env bash
# Ningún artefacto ejecuta ALTER DATABASE RECOVER MANAGED STANDBY DATABASE (start/stop/cancel).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/dataguard" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq 'RECOVER MANAGED STANDBY'; then
    echo "[FAIL] $f contiene RECOVER MANAGED STANDBY ejecutable"
    FAIL=1
  fi
done

grep -q 'ALTER DATABASE RECOVER MANAGED STANDBY DATABASE' "$ROOT/agents/oracle-dataguard-analyst/manifest.yaml" \
  && echo "[PASS] manifest.yaml prohíbe explícitamente start/stop/cancel de MRP" \
  || { echo "[FAIL] falta prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query ejecuta RECOVER MANAGED STANDBY"
exit $FAIL
