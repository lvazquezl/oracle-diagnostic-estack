#!/usr/bin/env bash
# Valida que el parser Statspack derive redo/commit de Load Profile + Instance Activity Stats
# (Statspack no tiene una sección dedicada "Redo/Commit" — # Statspack Parser conceptual model).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.statspack_parser import parse_statspack_text
with open('tests/fixtures/reports/statspack-high-commit.txt', encoding='utf-8') as f:
    r = parse_statspack_text(f.read())
rc = r.sections['redo_commit']
assert 'Redo size' in rc, rc
assert r.completeness['redo_commit'] == 'SUPPORTED'
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Parser Statspack deriva redo/commit de Load Profile + Instance Activity"
else
  echo "[FAIL] Derivación de redo/commit falló: $OUT"
  FAIL=1
fi

exit $FAIL
