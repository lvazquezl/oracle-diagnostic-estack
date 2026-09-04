#!/usr/bin/env bash
# Valida que el type detector reconozca un reporte AWR TEXT por firma de contenido.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.type_detector import detect_report_type
with open('tests/fixtures/reports/awr-sample.txt', encoding='utf-8') as f:
    t, c = detect_report_type(f.read())
print(t.value, c)
")
if echo "$OUT" | grep -q "^AWR_TEXT "; then
  echo "[PASS] awr-sample.txt detectado como AWR_TEXT ($OUT)"
else
  echo "[FAIL] awr-sample.txt no detectado como AWR_TEXT (obtuvo: $OUT)"
  FAIL=1
fi

exit $FAIL
