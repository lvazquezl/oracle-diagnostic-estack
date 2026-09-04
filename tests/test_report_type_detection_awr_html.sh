#!/usr/bin/env bash
# Valida que el type detector reconozca un reporte AWR HTML por firma de contenido,
# no por extensión (# 15 REPORT TYPE DETECTION).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.type_detector import detect_report_type
with open('tests/fixtures/reports/awr-sample.html', encoding='utf-8') as f:
    t, c = detect_report_type(f.read())
print(t.value, c)
")
if echo "$OUT" | grep -q "^AWR_HTML "; then
  echo "[PASS] awr-sample.html detectado como AWR_HTML ($OUT)"
else
  echo "[FAIL] awr-sample.html no detectado como AWR_HTML (obtuvo: $OUT)"
  FAIL=1
fi

exit $FAIL
