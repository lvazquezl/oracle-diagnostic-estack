#!/usr/bin/env bash
# Data Guard core nunca usa ASH sin delegar a oracle-performance-analyst y su propio Licensing Gate.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/dataguard" -name 'Q-*.md' 2>/dev/null); do
  if grep -qi 'V\$ACTIVE_SESSION_HISTORY\|DBA_HIST_ACTIVE_SESS' "$f"; then
    echo "[FAIL] $f referencia vistas ASH directamente — Data Guard core debe ser independiente"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query Data Guard depende de ASH directamente"
exit $FAIL
