#!/usr/bin/env bash
# Ninguna query rac/asm ejecuta ALTER SYSTEM KILL SESSION (reafirmación específica de Fase 4;
# la prohibición general ya existe desde test_no_kill_session_execution.sh de Fase 3).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/rac" "$ROOT/queries/asm" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq 'KILL SESSION|ALTER SYSTEM'; then
    echo "[FAIL] $f contiene KILL SESSION/ALTER SYSTEM ejecutable"
    FAIL=1
  fi
done

grep -q 'ALTER SYSTEM KILL SESSION' "$ROOT/agents/oracle-rac-analyst/manifest.yaml" \
  && echo "[PASS] manifest.yaml de oracle-rac-analyst prohíbe explícitamente KILL SESSION" \
  || { echo "[FAIL] falta prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query RAC/ASM ejecuta KILL SESSION"
exit $FAIL
