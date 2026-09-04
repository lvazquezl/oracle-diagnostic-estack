#!/usr/bin/env bash
# Valida que Q-PERF-DBTIME-CURRENT-001 (V$SYS_TIME_MODEL) exista y no requiera licencia.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/queries/performance/db-time/Q-PERF-DBTIME-CURRENT-001.md"

[ -f "$F" ] || { echo "[FAIL] falta Q-PERF-DBTIME-CURRENT-001.md"; exit 1; }
grep -q 'v\$sys_time_model' "$F" && echo "[PASS] usa V\$SYS_TIME_MODEL" || { echo "[FAIL] no usa V\$SYS_TIME_MODEL"; FAIL=1; }
grep -q 'license_requirements: none' "$F" && echo "[PASS] sin licencia" || { echo "[FAIL] declara licencia"; FAIL=1; }

exit $FAIL
