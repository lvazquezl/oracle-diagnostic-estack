#!/usr/bin/env bash
# Valida que el parser de planes de ejecución extraiga plan_hash_value, operaciones y predicados.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.execution_plan_parser import parse_execution_plan_text
with open('tests/fixtures/reports/execution-plan-sample.txt', encoding='utf-8') as f:
    r = parse_execution_plan_text(f.read())
d = r.to_dict()['report']
assert d['status'] == 'SUCCESS'
assert d['sections']['plan_hash_value'] == '1234567890'
assert len(d['sections']['operations']) == 3
assert d['sections']['operations'][0]['operation'] == 'SELECT STATEMENT'
assert '2' in d['sections']['predicates']
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Parser de plan de ejecución extrae plan_hash_value/operaciones/predicados"
else
  echo "[FAIL] Parser de plan de ejecución falló: $OUT"
  FAIL=1
fi

exit $FAIL
