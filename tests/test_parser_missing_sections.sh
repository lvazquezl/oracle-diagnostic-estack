#!/usr/bin/env bash
# Valida que un reporte con secciones ausentes produzca PARTIAL con completeness explícita
# por sección, nunca datos fabricados (# 8 STATSPACK PARSER ROBUSTNESS).
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
assert d['completeness']['library_cache'] == 'UNSUPPORTED'
assert d['completeness']['latch'] == 'UNSUPPORTED'
assert d['completeness']['load_profile'] == 'SUPPORTED'
assert 'library_cache' in d['sections_missing']
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Reporte con secciones ausentes produce PARTIAL con completeness explícita, sin fabricar datos"
else
  echo "[FAIL] Manejo de secciones ausentes falló: $OUT"
  FAIL=1
fi

exit $FAIL
