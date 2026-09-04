#!/usr/bin/env bash
# Valida que el parser Statspack extraiga File/Tablespace IO Stats, incluyendo nombres de
# archivo estilo ASM ('+DATA/...').
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
with open('tests/fixtures/reports/statspack-high-io.txt', encoding='utf-8') as f:
    r = parse_statspack_text(f.read())
names = [row['name'] for row in r.sections['io']]
assert any(n.startswith('+DATA') for n in names), names
assert r.completeness['io'] == 'SUPPORTED'
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Parser Statspack extrae File/Tablespace IO Stats, incluyendo rutas ASM"
else
  echo "[FAIL] Extracción de I/O falló: $OUT"
  FAIL=1
fi

exit $FAIL
