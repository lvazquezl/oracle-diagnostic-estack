#!/usr/bin/env bash
# Ningún artefacto ejecuta ALTER DATABASE FORCE LOGGING (# 36 — sólo visibility/assessment).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/dataguard" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq 'FORCE LOGGING'; then
    echo "[FAIL] $f contiene FORCE LOGGING ejecutable"
    FAIL=1
  fi
done

grep -q 'ALTER DATABASE FORCE LOGGING' "$ROOT/agents/oracle-dataguard-analyst/manifest.yaml" \
  && echo "[PASS] manifest.yaml prohíbe explícitamente FORCE LOGGING" \
  || { echo "[FAIL] falta prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query ejecuta FORCE LOGGING"
exit $FAIL
