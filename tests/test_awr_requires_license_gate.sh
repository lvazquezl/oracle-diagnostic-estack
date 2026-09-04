#!/usr/bin/env bash
# Valida que el agente/workflow de performance apliquen el Licensing Gate antes de usar AWR —
# nunca asumido disponible porque las vistas DBA_HIST_* existan.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

if ! grep -q 'license_confirmed' "$ROOT/agents/oracle-performance-analyst/AGENT.md"; then
  echo "[FAIL] agents/oracle-performance-analyst/AGENT.md no exige constraints.license_confirmed"
  FAIL=1
else
  echo "[PASS] agents/oracle-performance-analyst/AGENT.md exige constraints.license_confirmed antes de usar AWR"
fi

if ! grep -q 'License Gate' "$ROOT/agents/oracle-performance-analyst/AGENT.md" && ! grep -q 'Licensing Gate' "$ROOT/agents/oracle-performance-analyst/AGENT.md"; then
  echo "[FAIL] agents/oracle-performance-analyst/AGENT.md no documenta el Licensing Gate"
  FAIL=1
fi

exit $FAIL
