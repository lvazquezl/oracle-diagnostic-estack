#!/usr/bin/env bash
# Ningún artefacto ejecuta CANCEL sobre MRP (detención de apply).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/dataguard" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq 'RECOVER MANAGED STANDBY DATABASE CANCEL'; then
    echo "[FAIL] $f contiene CANCEL de MRP ejecutable"
    FAIL=1
  fi
done

grep -qi 'no inicia/detiene MRP/RFS' "$ROOT/agents/oracle-dataguard-analyst/AGENT.md" \
  && echo "[PASS] AGENT.md prohíbe explícitamente detener MRP/RFS" \
  || { echo "[FAIL] falta prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query ejecuta CANCEL de MRP"
exit $FAIL
