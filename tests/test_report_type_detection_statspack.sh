#!/usr/bin/env bash
# Valida que el type detector reconozca un reporte Statspack TEXT por firma de contenido.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.type_detector import detect_report_type
with open('tests/fixtures/reports/statspack-11g.txt', encoding='utf-8') as f:
    t, c = detect_report_type(f.read())
print(t.value, c)
")
if echo "$OUT" | grep -q "^STATSPACK_TEXT "; then
  echo "[PASS] statspack-11g.txt detectado como STATSPACK_TEXT ($OUT)"
else
  echo "[FAIL] statspack-11g.txt no detectado como STATSPACK_TEXT (obtuvo: $OUT)"
  FAIL=1
fi

exit $FAIL
