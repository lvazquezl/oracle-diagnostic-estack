#!/usr/bin/env bash
# Valida que el parser Statspack procese un reporte 11g real con cobertura completa
# (# 4 STATSPACK — OBJETIVO: útil para 11g).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
with open('tests/fixtures/reports/statspack-11g.txt', encoding='utf-8') as f:
    r = parse_statspack_text(f.read())
d = r.to_dict()['report']
assert d['metadata']['oracle_version'] == '11.2.0.4.0', d['metadata']
assert d['status'] == 'SUCCESS', d['status']
supported = [k for k, v in d['completeness'].items() if v == 'SUPPORTED']
assert len(supported) >= 12, supported
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Parser Statspack procesa reporte 11g real con cobertura completa (>=12 secciones SUPPORTED)"
else
  echo "[FAIL] Parser Statspack 11g falló: $OUT"
  FAIL=1
fi

exit $FAIL
