#!/usr/bin/env bash
# Valida que el type detector devuelva UNKNOWN (nunca un tipo adivinado) para contenido que
# no coincide con ninguna firma conocida — # 15: "no intentar parsing arbitrario".
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.type_detector import detect_report_type
with open('tests/fixtures/reports/unknown-report.txt', encoding='utf-8') as f:
    t, c = detect_report_type(f.read())
print(t.value, c)
")
if echo "$OUT" | grep -q "^UNKNOWN "; then
  echo "[PASS] unknown-report.txt detectado como UNKNOWN, sin adivinar un tipo ($OUT)"
else
  echo "[FAIL] unknown-report.txt no detectado como UNKNOWN (obtuvo: $OUT)"
  FAIL=1
fi

exit $FAIL
