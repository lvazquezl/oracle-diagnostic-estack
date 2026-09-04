#!/usr/bin/env bash
# Valida que Q-PERF-DBTIME-001 (AWR) exista, certificada, con license_requirements: [Diagnostics Pack].
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/queries/performance/db-time/Q-PERF-DBTIME-001.md"

if [ ! -f "$F" ]; then
  echo "[FAIL] falta Q-PERF-DBTIME-001.md"
  exit 1
fi
grep -q '^status: active$' "$F" && echo "[PASS] Q-PERF-DBTIME-001 status: active" || { echo "[FAIL] Q-PERF-DBTIME-001 no está active"; FAIL=1; }
grep -q 'license_requirements: \[Diagnostics Pack\]' "$F" && echo "[PASS] Q-PERF-DBTIME-001 requiere Diagnostics Pack" || { echo "[FAIL] Q-PERF-DBTIME-001 no declara Diagnostics Pack"; FAIL=1; }
grep -q 'DBA_HIST_SYS_TIME_MODEL' "$F" && echo "[PASS] Q-PERF-DBTIME-001 usa DBA_HIST_SYS_TIME_MODEL" || { echo "[FAIL] Q-PERF-DBTIME-001 no usa DBA_HIST_SYS_TIME_MODEL"; FAIL=1; }

exit $FAIL
