#!/usr/bin/env bash
# Valida que Q-PERF-SGA-001/Q-PERF-PGA-001 existan y no requieran licencia (memoria es
# estructural, no depende de Diagnostics Pack a diferencia del resto de AWR).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for q in Q-PERF-SGA-001 Q-PERF-PGA-001; do
  F=$(find "$ROOT/queries/performance/memory" -name "$q.md")
  if [ -z "$F" ]; then
    echo "[FAIL] falta $q.md"
    FAIL=1
    continue
  fi
  if grep -q 'license_requirements: none' "$F"; then
    echo "[PASS] $q no requiere licencia"
  else
    echo "[FAIL] $q debería declarar license_requirements: none"
    FAIL=1
  fi
done

exit $FAIL
