#!/usr/bin/env bash
# Valida que el parser Statspack extraiga Instance Activity Stats.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
with open('tests/fixtures/reports/statspack-11g.txt', encoding='utf-8') as f:
    r = parse_statspack_text(f.read())
names = [row['name'] for row in r.sections['instance_activity']]
assert 'user commits' in names, names
assert 'redo entries' in names, names
assert r.completeness['instance_activity'] == 'SUPPORTED'
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Parser Statspack extrae Instance Activity Stats"
else
  echo "[FAIL] Extracción de Instance Activity falló: $OUT"
  FAIL=1
fi

exit $FAIL
