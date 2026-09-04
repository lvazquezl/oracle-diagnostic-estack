#!/usr/bin/env bash
# Valida que Q-PERF-IO-001/Q-PERF-IO-FILESTAT-001 existan y no requieran licencia — I/O snapshot
# actual es una ruta estándar, distinta de DBA_HIST_SYSTEM_EVENT (histórico, licenciado).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for q in Q-PERF-IO-001 Q-PERF-IO-FILESTAT-001; do
  F=$(find "$ROOT/queries/performance/io" -name "$q.md")
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
