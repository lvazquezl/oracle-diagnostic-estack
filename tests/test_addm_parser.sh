#!/usr/bin/env bash
# Valida que el parser ADDM extraiga findings/recommendations y los clasifique EVIDENCE_SOURCE.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

OUT=$(cd "$ROOT" && python3 -c "
import sys; sys.path.insert(0, '.')
from parsers.performance.addm_parser import parse_addm_text
with open('tests/fixtures/reports/addm-sample.txt', encoding='utf-8') as f:
    r = parse_addm_text(f.read())
d = r.to_dict()['report']
assert d['status'] == 'SUCCESS'
assert len(d['sections']['findings']) == 2
assert all(f['classification'] == 'EVIDENCE_SOURCE' for f in d['sections']['findings'])
assert len(d['sections']['recommendations']) == 2
assert all(r_['manual_execution_required'] is True for r_ in d['sections']['recommendations'])
print('OK')
")
if echo "$OUT" | grep -q "^OK$"; then
  echo "[PASS] Parser ADDM extrae findings/recommendations, siempre EVIDENCE_SOURCE"
else
  echo "[FAIL] Parser ADDM falló: $OUT"
  FAIL=1
fi

exit $FAIL
