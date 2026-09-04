#!/usr/bin/env bash
# Valida que el parser Statspack extraiga Library Cache Activity por namespace.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
with open('tests/fixtures/reports/statspack-11g.txt', encoding='utf-8') as f:
    r = parse_statspack_text(f.read())
names = [row['name'] for row in r.sections['library_cache']]
assert 'SQL AREA' in names, names
assert r.completeness['library_cache'] == 'SUPPORTED'
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Parser Statspack extrae Library Cache Activity por namespace"
else
  echo "[FAIL] Extracción de Library Cache falló: $OUT"
  FAIL=1
fi

exit $FAIL
