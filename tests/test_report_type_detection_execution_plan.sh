#!/usr/bin/env bash
# Valida que el type detector reconozca un plan de ejecución textual por firma de contenido.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.type_detector import detect_report_type
with open('tests/fixtures/reports/execution-plan-sample.txt', encoding='utf-8') as f:
    t, c = detect_report_type(f.read())
print(t.value, c)
")
if echo "$OUT" | grep -q "^EXECUTION_PLAN_TEXT "; then
  echo "[PASS] execution-plan-sample.txt detectado como EXECUTION_PLAN_TEXT ($OUT)"
else
  echo "[FAIL] execution-plan-sample.txt no detectado como EXECUTION_PLAN_TEXT (obtuvo: $OUT)"
  FAIL=1
fi

exit $FAIL
