#!/usr/bin/env bash
# Valida degradación elegante: un reporte parcial (statspack-partial.txt) no crashea, marca
# PARTIAL, y declara UNSUPPORTED explícito por cada sección ausente — nunca fabrica datos.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
with open('tests/fixtures/reports/statspack-partial.txt', encoding='utf-8') as f:
    r = parse_statspack_text(f.read())
d = r.to_dict()['report']
assert d['status'] == 'PARTIAL'
assert d['completeness']['sql_by_cpu'] == 'UNSUPPORTED'
assert d['completeness']['instance_activity'] == 'UNSUPPORTED'
assert d['completeness']['memory'] == 'UNSUPPORTED'
assert d['sections']['sql_by_cpu'] == []
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Reporte Statspack parcial degrada elegantemente (PARTIAL, UNSUPPORTED explícito, sin fabricar)"
else
  echo "[FAIL] Degradación elegante falló: $OUT"
  FAIL=1
fi

exit $FAIL
