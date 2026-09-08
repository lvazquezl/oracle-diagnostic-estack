#!/usr/bin/env bash
# Ningún artefacto ejecuta ALTER DATABASE FLASHBACK ON/OFF (# 37 — sólo awareness).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/dataguard" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq 'FLASHBACK (ON|OFF)'; then
    echo "[FAIL] $f contiene FLASHBACK ON/OFF ejecutable"
    FAIL=1
  fi
done

grep -q 'ALTER DATABASE FLASHBACK ON/OFF' "$ROOT/agents/oracle-dataguard-analyst/manifest.yaml" \
  && echo "[PASS] manifest.yaml prohíbe explícitamente FLASHBACK ON/OFF" \
  || { echo "[FAIL] falta prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query ejecuta FLASHBACK ON/OFF"
exit $FAIL
