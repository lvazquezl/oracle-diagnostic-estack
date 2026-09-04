#!/usr/bin/env bash
# Valida que Q-PERF-LOCKS-001 use V$LOCK y clasifique por tipo/modo.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/queries/performance/concurrency/Q-PERF-LOCKS-001.md"

[ -f "$F" ] || { echo "[FAIL] falta Q-PERF-LOCKS-001.md"; exit 1; }
grep -qi 'v\$lock' "$F" && echo "[PASS] usa V\$LOCK" || { echo "[FAIL] no usa V\$LOCK"; FAIL=1; }
grep -q 'lock_mode' "$F" && echo "[PASS] clasifica por lock_mode" || { echo "[FAIL] no clasifica por lock_mode"; FAIL=1; }

exit $FAIL
