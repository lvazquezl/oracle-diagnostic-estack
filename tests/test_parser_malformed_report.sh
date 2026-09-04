#!/usr/bin/env bash
# Valida que un reporte sin ninguna cabecera de sección reconocible produzca MALFORMED_REPORT
# (parser interno) o UNKNOWN_REPORT_TYPE (detector), nunca una excepción ni datos inventados.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
from parsers.performance.ingest import ingest_report

# Marca STATSPACK presente pero sin secciones parseables -> MALFORMED_REPORT interno
garbled = 'STATSPACK REPORT\nsome garbled content with no recognized headers at all\n'
r = parse_statspack_text(garbled)
assert r.status == 'MALFORMED_REPORT', r.status

# Vía ingest con un archivo real sin marcadores conocidos -> UNKNOWN_REPORT_TYPE, sin excepción
with open('tests/fixtures/reports/statspack-malformed.txt', encoding='utf-8') as f:
    r2 = ingest_report(f.read())
assert r2.status == 'UNKNOWN_REPORT_TYPE', r2.status
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Reporte malformado produce MALFORMED_REPORT/UNKNOWN_REPORT_TYPE, sin excepción ni datos inventados"
else
  echo "[FAIL] Manejo de reporte malformado falló: $OUT"
  FAIL=1
fi

exit $FAIL
