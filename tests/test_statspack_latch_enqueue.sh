#!/usr/bin/env bash
# Valida que el parser Statspack extraiga Latch Activity y Enqueue activity por separado.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
with open('tests/fixtures/reports/statspack-11g.txt', encoding='utf-8') as f:
    r = parse_statspack_text(f.read())
latch_names = [row['name'] for row in r.sections['latch']]
enqueue_names = [row['name'] for row in r.sections['enqueue']]
assert 'cache buffers chains' in latch_names, latch_names
assert 'TX' in enqueue_names, enqueue_names
assert r.completeness['latch'] == 'SUPPORTED'
assert r.completeness['enqueue'] == 'SUPPORTED'
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Parser Statspack extrae Latch Activity y Enqueue activity por separado"
else
  echo "[FAIL] Extracción de Latch/Enqueue falló: $OUT"
  FAIL=1
fi

exit $FAIL
