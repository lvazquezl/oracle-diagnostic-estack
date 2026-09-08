#!/usr/bin/env bash
# Data Guard core nunca usa AWR sin delegar a oracle-performance-analyst y su propio Licensing Gate (# 39, # 42).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
A="$ROOT/agents/oracle-dataguard-analyst/AGENT.md"

grep -qi 'AWR/ASH sólo vía delegación a .oracle-performance-analyst. con su propio gate' "$A" && echo "[PASS] AGENT.md declara que AWR sólo vía delegación con gate propio" || { echo "[FAIL] falta la regla"; FAIL=1; }

for f in $(find "$ROOT/queries/dataguard" -name 'Q-*.md' 2>/dev/null); do
  if grep -qi 'DBA_HIST_' "$f"; then
    echo "[FAIL] $f referencia vistas AWR (DBA_HIST_*) directamente — Data Guard core debe ser independiente"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query Data Guard depende de AWR directamente"
exit $FAIL
