#!/usr/bin/env bash
# Valida que un archivo vacío produzca EMPTY_REPORT en todos los parsers y en el ingest, nunca
# una excepción.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
from parsers.performance.awr_parser import parse_awr
from parsers.performance.addm_parser import parse_addm_text
from parsers.performance.execution_plan_parser import parse_execution_plan_text
from parsers.performance.ingest import ingest_report

for fn in (
    lambda: parse_statspack_text(''),
    lambda: parse_awr('', is_html=False),
    lambda: parse_addm_text(''),
    lambda: parse_execution_plan_text(''),
    lambda: ingest_report(''),
):
    r = fn()
    assert r.status == 'EMPTY_REPORT', r.status
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Archivo vacío produce EMPTY_REPORT en todos los parsers y en el ingest"
else
  echo "[FAIL] Manejo de reporte vacío falló: $OUT"
  FAIL=1
fi

exit $FAIL
