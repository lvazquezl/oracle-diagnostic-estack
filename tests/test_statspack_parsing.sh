#!/usr/bin/env bash
# Valida que el parser Statspack derive parsing (Parses/Hard parses/Soft Parse %) de Load
# Profile + Instance Efficiency Percentages.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
with open('tests/fixtures/reports/statspack-high-parse.txt', encoding='utf-8') as f:
    r = parse_statspack_text(f.read())
p = r.sections['parsing']
assert 'Hard parses' in p, p
assert 'Soft Parse %' in p, p
assert float(p['Soft Parse %']) < 30, p
assert r.completeness['parsing'] == 'SUPPORTED'
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Parser Statspack deriva parsing (Hard parses/Soft Parse %) correctamente"
else
  echo "[FAIL] Derivación de parsing falló: $OUT"
  FAIL=1
fi

exit $FAIL
