#!/usr/bin/env bash
# Valida que el parser Statspack extraiga Load Profile (per second / per transaction).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
with open('tests/fixtures/reports/statspack-11g.txt', encoding='utf-8') as f:
    r = parse_statspack_text(f.read())
lp = {row['metric']: row for row in r.sections['load_profile']}
assert 'Redo size' in lp
assert lp['Redo size']['per_second'] == '125432.10'
assert lp['Redo size']['per_transaction'] == '578.23'
assert 'Hard parses' in lp
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Parser Statspack extrae Load Profile (per second / per transaction)"
else
  echo "[FAIL] Extracción de Load Profile falló: $OUT"
  FAIL=1
fi

exit $FAIL
