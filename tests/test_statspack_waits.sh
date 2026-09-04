#!/usr/bin/env bash
# Valida que Q-PERF-WAIT-STATSPACK-001 use STATS$SYSTEM_EVENT/STATS$SNAPSHOT y produzca
# wait_class_derived (aproximación documentada, no la taxonomía oficial de AWR).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/queries/performance/waits/Q-PERF-WAIT-STATSPACK-001.md"

grep -q 'stats\$system_event' "$F" && echo "[PASS] usa STATS\$SYSTEM_EVENT" || { echo "[FAIL] no usa STATS\$SYSTEM_EVENT"; FAIL=1; }
grep -q 'wait_class_derived' "$F" && echo "[PASS] declara wait_class_derived (aproximación)" || { echo "[FAIL] falta wait_class_derived"; FAIL=1; }
grep -qi 'no intentar equivalencia 1:1\|no es la taxonomía oficial\|aproximación' "$F" && echo "[PASS] documenta explícitamente que es una aproximación" || { echo "[FAIL] no documenta la limitación de wait_class_derived"; FAIL=1; }

# Ruta de reporte de archivo (parser) también extrae waits, independientemente de la query en vivo.
OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
with open('tests/fixtures/reports/statspack-11g.txt', encoding='utf-8') as f:
    r = parse_statspack_text(f.read())
assert r.completeness['waits'] == 'SUPPORTED'
assert len(r.sections['waits']) > 0
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Ruta de reporte de archivo (parser) también extrae waits"
else
  echo "[FAIL] Ruta de reporte de archivo no extrae waits: $OUT"
  FAIL=1
fi

exit $FAIL
