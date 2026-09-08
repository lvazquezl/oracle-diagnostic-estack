#!/usr/bin/env bash
# Ningún artefacto ejecuta ALTER DATABASE ADD STANDBY LOGFILE.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/dataguard" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  if echo "$block" | grep -Eiq 'ADD STANDBY LOGFILE'; then
    echo "[FAIL] $f contiene ADD STANDBY LOGFILE ejecutable"
    FAIL=1
  fi
done

grep -q 'creación/eliminación de standby redo logs' "$ROOT/agents/oracle-dataguard-analyst/manifest.yaml" \
  && echo "[PASS] manifest.yaml prohíbe explícitamente crear SRL" \
  || { echo "[FAIL] falta prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query ejecuta ADD STANDBY LOGFILE"
exit $FAIL
