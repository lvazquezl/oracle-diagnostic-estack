#!/usr/bin/env bash
# Valida que Q-PERF-SGA-001/Q-PERF-PGA-001/Q-PERF-HARDPARSE-001/Q-PERF-LIBCACHE-001/
# Q-PERF-SHAREDPOOL-001 (memoria) no requieran licencia — siempre disponibles sin Diagnostics Pack.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for q in Q-PERF-SGA-001 Q-PERF-PGA-001 Q-PERF-HARDPARSE-001 Q-PERF-LIBCACHE-001 Q-PERF-SHAREDPOOL-001; do
  F=$(find "$ROOT/queries/performance/memory" -name "$q.md")
  if [ -z "$F" ]; then
    echo "[FAIL] falta $q.md"
    FAIL=1
    continue
  fi
  grep -q 'license_requirements: none' "$F" && echo "[PASS] $q sin licencia" || { echo "[FAIL] $q declara licencia"; FAIL=1; }
done

exit $FAIL
