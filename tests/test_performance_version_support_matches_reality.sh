#!/usr/bin/env bash
# Valida que ninguna query certificada bajo queries/performance/ declare soporte de versión sin
# que su SQL haya sido validado contra compatibility/oracle-dictionary/ (# 63 del prompt de
# Fase 3: no fingir soporte universal, usar SUPPORTED|PARTIAL|UNSUPPORTED|LICENSE_RESTRICTED).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/performance" -name 'Q-*.md'); do
  qid=$(grep -m1 '^query_id:' "$f" | awk '{print $2}')
  if ! grep -q "^  $qid:" "$ROOT/config/query-compatibility-matrix.yaml"; then
    echo "[FAIL] $qid no está registrada en config/query-compatibility-matrix.yaml"
    FAIL=1
  else
    echo "[PASS] $qid registrada en query-compatibility-matrix.yaml"
  fi
done

exit $FAIL
