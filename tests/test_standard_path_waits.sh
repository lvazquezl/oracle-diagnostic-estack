#!/usr/bin/env bash
# Valida que Q-PERF-IO-001 (V$SYSTEM_EVENT) exista como ruta de waits sin licencia.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/queries/performance/io/Q-PERF-IO-001.md"

[ -f "$F" ] || { echo "[FAIL] falta Q-PERF-IO-001.md"; exit 1; }
grep -q 'v\$system_event' "$F" && echo "[PASS] usa V\$SYSTEM_EVENT" || { echo "[FAIL] no usa V\$SYSTEM_EVENT"; FAIL=1; }
grep -q 'license_requirements: none' "$F" && echo "[PASS] sin licencia" || { echo "[FAIL] declara licencia"; FAIL=1; }

exit $FAIL
