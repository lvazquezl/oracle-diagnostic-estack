#!/usr/bin/env bash
# Valida que el parser Statspack procese un reporte 10g real, extrayendo metadata de versión
# y al menos Load Profile/waits (# 4 STATSPACK — OBJETIVO: útil para 10g).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
with open('tests/fixtures/reports/statspack-10g.txt', encoding='utf-8') as f:
    r = parse_statspack_text(f.read())
d = r.to_dict()['report']
assert d['metadata']['oracle_version'] == '10.2.0.5.0', d['metadata']
assert d['completeness']['load_profile'] == 'SUPPORTED'
assert d['completeness']['waits'] == 'SUPPORTED'
assert d['status'] in ('SUCCESS', 'PARTIAL')
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Parser Statspack procesa reporte 10g real con metadata de versión correcta"
else
  echo "[FAIL] Parser Statspack 10g falló: $OUT"
  FAIL=1
fi

exit $FAIL
