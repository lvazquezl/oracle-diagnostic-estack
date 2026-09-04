#!/usr/bin/env bash
# Valida que la sanitización local (# 24 REPORT SANITIZATION) tokenice hostnames/nombres de
# base de datos/objetos antes de que la evidencia se considere lista, y que la misma tokenización
# sea consistente dentro de un mismo parse.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
from parsers.performance.execution_plan_parser import parse_execution_plan_text
from parsers.performance.common import Sanitizer

with open('tests/fixtures/reports/statspack-11g.txt', encoding='utf-8') as f:
    text = f.read()
r = parse_statspack_text(text, sanitize=True)
d = r.to_dict()['report']
assert d['sanitization_status'] == 'APPLIED'
assert d['metadata']['db_name'] == 'DB_TOKEN_001'
assert d['metadata']['instance_name'] == 'HOST_TOKEN_001'
assert 'ORCL11G' not in str(d['metadata'])

# Consistency: same raw value -> same token within one Sanitizer instance
s = Sanitizer()
a = s.hostname('samehost')
b = s.hostname('samehost')
assert a == b

# Execution plan: object names tokenized, literal predicate values masked
with open('tests/fixtures/reports/execution-plan-sample.txt', encoding='utf-8') as f:
    ptext = f.read()
pr = parse_execution_plan_text(ptext, sanitize=True)
pd = pr.to_dict()['report']
names = [op['object_token'] for op in pd['sections']['operations'] if op['object_token']]
assert all(n.startswith('OBJECT_TOKEN_') for n in names), names
assert 'ORDERS' not in str(pd['sections'])
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Sanitización tokeniza hostnames/db names/object names de forma consistente"
else
  echo "[FAIL] Sanitización falló: $OUT"
  FAIL=1
fi

exit $FAIL
